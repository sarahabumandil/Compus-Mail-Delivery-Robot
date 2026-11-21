#!/usr/bin/env python3
"""Campus Mail Bot - automated multi-goal delivery mission + quantitative benchmark logger.

  ros2 run campus_mail_bot mission_runner --route default --trial 1 --tag baseline
  ros2 run campus_mail_bot mission_runner --route alt     --trial 2 --tag tuned_inflation

The robot (if not already at Reception) first drives back to Reception (unscored reset), then visits
every office of the chosen route through Nav2's NavigateToPose action - no manual driving.

Metrics (recorded only while the scored mission runs):
  * Distance_m          sum of sqrt(dx^2 + dy^2) over consecutive /odom samples
  * Time_sec            elapsed *simulation* time (works with use_sim_time)
  * Goals_Reached       goals whose Nav2 result was SUCCEEDED
  * Near-collisions     rising edges of "min /scan range < 0.22 m" (with 0.03 m hysteresis)
  * Min_Obstacle_Dist   smallest valid /scan range seen during the mission

Appends one row per run to results/trials_results.csv:
  Timestamp,Trial,Route,Tag,Goals_Reached,Total_Goals,Time_sec,Distance_m,Min_Obstacle_Dist,Status
and per-goal details (incl. near-collision events and recoveries) to results/trials_details.csv.
"""
import argparse
import csv
import math
import os
import sys
from datetime import datetime

import rclpy
import tf2_ros
import yaml
from ament_index_python.packages import get_package_share_directory
from geometry_msgs.msg import PoseStamped
from nav2_simple_commander.robot_navigator import BasicNavigator, TaskResult
from nav_msgs.msg import Odometry
from rclpy.utilities import remove_ros_args
from sensor_msgs.msg import LaserScan

RESULT_FIELDS = ['Timestamp', 'Trial', 'Route', 'Tag', 'Goals_Reached', 'Total_Goals',
                 'Time_sec', 'Distance_m', 'Min_Obstacle_Dist', 'Status']
DETAIL_FIELDS = ['Timestamp', 'Trial', 'Route', 'Tag', 'Goal_Index', 'Goal', 'Result',
                 'Time_sec', 'Recoveries', 'Near_Collision_Events']


def parse_args(argv):
    pkg = get_package_share_directory('campus_mail_bot')
    ap = argparse.ArgumentParser(description='Run one automated delivery trial and log metrics.')
    ap.add_argument('--route', choices=['default', 'alt'], default='default',
                    help='default: Reception->A->B->C | alt: Reception->C->A->B')
    ap.add_argument('--trial', type=int, default=1, help='trial number (for the CSV)')
    ap.add_argument('--tag', default='baseline', help='configuration tag: baseline | tuned_inflation')
    ap.add_argument('--routes-file', default=os.path.join(pkg, 'config', 'routes.yaml'))
    ap.add_argument('--results', default=os.path.join('results', 'trials_results.csv'),
                    help='CSV to append to (default ./results/trials_results.csv)')
    ap.add_argument('--goal-timeout', type=float, default=300.0, help='seconds (sim time) per goal')
    ap.add_argument('--near-threshold', type=float, default=0.22, help='near-collision range (m)')
    ap.add_argument('--no-reset', action='store_true', help='do not drive to Reception before the trial')
    ap.add_argument('--no-return', action='store_true', help='stay at the last office afterwards')
    return ap.parse_args(remove_ros_args(argv)[1:])


class MissionRunner:
    def __init__(self, args):
        self.a = args
        self.nav = BasicNavigator()
        with open(args.routes_file) as f:
            cfg = yaml.safe_load(f)
        self.start = cfg['start_world']
        self.loc = cfg['locations']
        self.route = cfg['routes'][args.route]

        self.recording = False
        self.prev_xy = None
        self.distance = 0.0
        self.min_range = float('inf')
        self.near_events = 0
        self.in_near = False

        self.nav.create_subscription(Odometry, '/odom', self._odom_cb, 10)
        self.nav.create_subscription(LaserScan, '/scan', self._scan_cb, 10)
        self.tf_buffer = tf2_ros.Buffer()
        self.tf_listener = tf2_ros.TransformListener(self.tf_buffer, self.nav)

    # ---- sensing callbacks -------------------------------------------------
    def _odom_cb(self, msg):
        if not self.recording:
            return
        xy = (msg.pose.pose.position.x, msg.pose.pose.position.y)
        if self.prev_xy is not None:
            dx, dy = xy[0] - self.prev_xy[0], xy[1] - self.prev_xy[1]
            self.distance += math.sqrt(dx * dx + dy * dy)
        self.prev_xy = xy

    def _scan_cb(self, msg):
        if not self.recording:
            return
        valid = [r for r in msg.ranges if math.isfinite(r) and r >= msg.range_min]
        if not valid:
            return
        m = min(valid)
        self.min_range = min(self.min_range, m)
        if m < self.a.near_threshold and not self.in_near:
            self.near_events += 1
            self.in_near = True
        elif m > self.a.near_threshold + 0.03:
            self.in_near = False

    # ---- helpers -------------------------------------------------------------
    def _map_pose(self, name):
        """World-frame location -> PoseStamped in the map frame (map = world - start)."""
        l = self.loc[name]
        p = PoseStamped()
        p.header.frame_id = 'map'
        p.header.stamp = self.nav.get_clock().now().to_msg()
        p.pose.position.x = float(l['x']) - float(self.start[0])
        p.pose.position.y = float(l['y']) - float(self.start[1])
        yaw = float(l.get('yaw', 0.0))
        p.pose.orientation.z = math.sin(yaw / 2.0)
        p.pose.orientation.w = math.cos(yaw / 2.0)
        return p

    def _robot_map_xy(self):
        try:
            t = self.tf_buffer.lookup_transform('map', 'base_link', rclpy.time.Time())
            return t.transform.translation.x, t.transform.translation.y
        except Exception:  # noqa: BLE001
            return None

    def _sim_seconds(self):
        return self.nav.get_clock().now().nanoseconds / 1e9

    def go(self, name):
        """Navigate to one named location. Returns (result_str, seconds, recoveries)."""
        n = self.nav
        t0 = self._sim_seconds()
        recoveries, cancelled = 0, False
        if not n.goToPose(self._map_pose(name)):
            return 'REJECTED', 0.0, 0
        while not n.isTaskComplete():
            fb = n.getFeedback()
            if fb:
                recoveries = max(recoveries, fb.number_of_recoveries)
            if self._sim_seconds() - t0 > self.a.goal_timeout and not cancelled:
                n.get_logger().warn(f'{name}: timeout ({self.a.goal_timeout:.0f}s) -> cancelling')
                n.cancelTask()
                cancelled = True
        res = n.getResult()
        dt = self._sim_seconds() - t0
        if cancelled:
            return 'TIMEOUT', dt, recoveries
        if res == TaskResult.SUCCEEDED:
            return 'SUCCEEDED', dt, recoveries
        if res == TaskResult.CANCELED:
            return 'CANCELED', dt, recoveries
        return 'FAILED', dt, recoveries

    # ---- main flow -----------------------------------------------------------
    def run(self):
        n, a, log = self.nav, self.a, self.nav.get_logger()
        log.info('Waiting for Nav2 (AMCL + bt_navigator) to become active ...')
        n.waitUntilNav2Active()

        start_name, goals = self.route[0], self.route[1:]
        if not a.no_reset:
            xy = self._robot_map_xy()
            home = self._map_pose(start_name).pose.position
            if xy is None or math.dist(xy, (home.x, home.y)) > 0.6:
                log.info(f'Reset: driving to {start_name} (unscored) ...')
                n.clearAllCostmaps()
                r, _, _ = self.go(start_name)
                log.info(f'Reset result: {r}')

        log.info(f'=== TRIAL {a.trial} | route={a.route} {self.route} | tag={a.tag} ===')
        n.clearAllCostmaps()
        self.distance, self.prev_xy, self.min_range = 0.0, None, float('inf')
        self.near_events, self.in_near = 0, False
        self.recording = True
        t_start = self._sim_seconds()

        details, reached = [], 0
        for i, g in enumerate(goals, start=1):
            near_before = self.near_events
            res, dt, rec = self.go(g)
            reached += int(res == 'SUCCEEDED')
            near = self.near_events - near_before
            log.info(f'[goal {i}/{len(goals)}] {g}: {res} | {dt:.1f}s | recoveries={rec} | near-collisions={near}')
            details.append((i, g, res, dt, rec, near))

        elapsed = self._sim_seconds() - t_start
        self.recording = False
        min_d = self.min_range if math.isfinite(self.min_range) else float('nan')
        status = 'COMPLETED' if reached == len(goals) else ('PARTIAL' if reached else 'FAILED')

        stamp = datetime.now().isoformat(timespec='seconds')
        self._append(a.results, RESULT_FIELDS,
                     [stamp, a.trial, a.route, a.tag, reached, len(goals), round(elapsed, 2),
                      round(self.distance, 3), round(min_d, 3), status])
        detail_path = os.path.join(os.path.dirname(a.results) or '.', 'trials_details.csv')
        for d in details:
            self._append(detail_path, DETAIL_FIELDS,
                         [stamp, a.trial, a.route, a.tag, d[0], d[1], d[2], round(d[3], 2), d[4], d[5]])

        log.info('-------------------------------------------------------------')
        log.info(f'RESULT trial={a.trial} route={a.route} tag={a.tag}: {reached}/{len(goals)} goals, '
                 f'{elapsed:.1f}s, {self.distance:.2f} m, min range {min_d:.2f} m, '
                 f'near-collision events={self.near_events} -> {status}')
        log.info(f'Appended to {a.results}')

        if not a.no_return:
            log.info('Returning to Reception (unscored) ...')
            self.go(start_name)

    @staticmethod
    def _append(path, fields, row):
        os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
        new = not os.path.isfile(path) or os.path.getsize(path) == 0
        with open(path, 'a', newline='') as f:
            w = csv.writer(f)
            if new:
                w.writerow(fields)
            w.writerow(row)


def main():
    args = parse_args(sys.argv)
    # Force simulation time for this node (and the BasicNavigator clock).
    rclpy.init(args=sys.argv + ['--ros-args', '-p', 'use_sim_time:=true'])
    runner = MissionRunner(args)
    try:
        runner.run()
    except KeyboardInterrupt:
        pass
    finally:
        runner.nav.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
