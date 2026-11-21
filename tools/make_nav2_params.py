#!/usr/bin/env python3
"""Build nav2_baseline.yaml / nav2_tuned.yaml from the official Nav2 *jazzy* nav2_params.yaml.

Usage: make_nav2_params.py <jazzy_nav2_params.yaml> <out_dir>
Only the inflation radius differs between the two outputs.
(The repo ships the generated files; this script documents exactly what was changed.)
"""
import re
import sys

DWB = '''    FollowPath:
      plugin: "dwb_core::DWBLocalPlanner"
      debug_trajectory_details: true
      min_vel_x: 0.0
      min_vel_y: 0.0
      max_vel_x: 0.26
      max_vel_y: 0.0
      max_vel_theta: 1.0
      min_speed_xy: 0.0
      max_speed_xy: 0.26
      min_speed_theta: 0.0
      acc_lim_x: 2.5
      acc_lim_y: 0.0
      acc_lim_theta: 3.2
      decel_lim_x: -2.5
      decel_lim_y: 0.0
      decel_lim_theta: -3.2
      vx_samples: 20
      vy_samples: 5
      vtheta_samples: 20
      sim_time: 1.7
      linear_granularity: 0.05
      angular_granularity: 0.025
      transform_tolerance: 0.2
      xy_goal_tolerance: 0.25
      trans_stopped_velocity: 0.25
      short_circuit_trajectory_evaluation: true
      stateful: true
      critics: ["RotateToGoal", "Oscillation", "BaseObstacle", "GoalAlign", "PathAlign", "PathDist", "GoalDist"]
      BaseObstacle.scale: 0.02
      PathAlign.scale: 32.0
      PathAlign.forward_point_distance: 0.1
      GoalAlign.scale: 24.0
      GoalAlign.forward_point_distance: 0.1
      PathDist.scale: 32.0
      GoalDist.scale: 24.0
      RotateToGoal.scale: 32.0
      RotateToGoal.slowing_factor: 5.0
      RotateToGoal.lookahead_time: -1.0

'''


def build(src, inflation, header):
    t = src
    # 1) use_sim_time everywhere
    t = re.sub(r'^(\s*)ros__parameters:\n', lambda m: f'{m.group(0)}{m.group(1)}  use_sim_time: true\n', t, flags=re.M)
    # 2) DWB instead of MPPI
    t = re.sub(r'    FollowPath:\n      plugin: "nav2_mppi_controller::MPPIController".*?(?=\nlocal_costmap:)',
               DWB.rstrip('\n') + '\n', t, flags=re.S)
    # 3) drop loopback simulator (not used)
    t = t.split('\nloopback_simulator:')[0].rstrip('\n') + '\n'
    # 4) robot specifics
    t = t.replace('robot_radius: 0.22', 'robot_radius: 0.24')
    t = t.replace('inflation_radius: 0.70', f'inflation_radius: {inflation}')
    t = t.replace('inflation_radius: 0.7\n', f'inflation_radius: {inflation}\n')
    t = t.replace('laser_max_range: 100.0', 'laser_max_range: 10.0')
    t = t.replace('max_particles: 2000', 'max_particles: 1000').replace('min_particles: 500', 'min_particles: 300')
    t = t.replace('    scan_topic: scan\n',
                  '    scan_topic: scan\n    set_initial_pose: true\n    always_reset_initial_pose: false\n'
                  '    initial_pose:\n      x: 0.0\n      y: 0.0\n      z: 0.0\n      yaw: 0.0\n', 1)
    t = t.replace('controller_frequency: 20.0', 'controller_frequency: 15.0', 1)
    t = t.replace('max_velocity: [0.5, 0.0, 2.0]', 'max_velocity: [0.26, 0.0, 1.0]')
    t = t.replace('min_velocity: [-0.5, 0.0, -2.0]', 'min_velocity: [-0.26, 0.0, -1.0]')
    t = t.replace('base_frame_id: "base_footprint"', 'base_frame_id: "base_link"')
    return header + t


if __name__ == '__main__':
    src = open(sys.argv[1]).read()
    out = sys.argv[2]
    common = ('# Derived from the official Nav2 Jazzy nav2_params.yaml by tools/make_nav2_params.py\n'
              '# Changes: use_sim_time everywhere, DWB local controller, robot_radius 0.24, base_link frames,\n'
              '# AMCL initial pose (0,0,0)=start pose, 1000 particles (2-core VM), 15 Hz controller, 0.26 m/s limits.\n')
    open(f'{out}/nav2_baseline.yaml', 'w').write(build(
        src, '0.55', '# BASELINE: inflation_radius 0.55 m (global + local costmap)\n' + common))
    open(f'{out}/nav2_tuned.yaml', 'w').write(build(
        src, '0.30', '# TUNED: inflation_radius 0.30 m (global + local costmap) - the ONLY difference from baseline\n' + common))
    print('wrote nav2_baseline.yaml and nav2_tuned.yaml')
