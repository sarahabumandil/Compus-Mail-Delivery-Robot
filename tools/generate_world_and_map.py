#!/usr/bin/env python3
"""Generate worlds/campus_offices.sdf and maps/campus_map.{pgm,yaml}.

World: 10 m x 8 m office floor, interior x in [-5, 5], y in [-4, 4] (world frame).
  * Reception / start zone at (-3.5, -2.5)
  * Reception partition at x = -2.0 leaves a ~1.25 m passage (tests inflation tuning)
  * Office wall at y = 1.2 with 1.2 m doors at x = -3.0, 0.0, 3.0
  * Office A (-3.0, 2.5), Office B (0.0, 2.5), Office C (3.0, 2.5)

MAP FRAME: SLAM Toolbox puts the map origin at the robot start pose, so
    map = world - START.   The generated starter map uses the same convention,
so it is interchangeable with a map you record yourself.
"""
import argparse
import os

START = (-3.5, -2.5)
RES = 0.05
WORLD_MIN = (-5.5, -4.5)   # world-frame lower-left corner of the map
SIZE = (11.0, 9.0)         # metres
INNER = (-5.0, 5.0, -4.0, 4.0)
H = 1.0

# name, cx, cy, sx, sy   (world frame)
WALLS = [
    ("wall_north", 0.0, 4.1, 10.4, 0.2),
    ("wall_south", 0.0, -4.1, 10.4, 0.2),
    ("wall_west", -5.1, 0.0, 0.2, 8.4),
    ("wall_east", 5.1, 0.0, 0.2, 8.4),
    # office front wall (y = 1.2) with 1.2 m doors centred at x = -3, 0, 3
    ("front_1", -4.3, 1.2, 1.4, 0.1),
    ("front_2", -1.5, 1.2, 1.8, 0.1),
    ("front_3", 1.5, 1.2, 1.8, 0.1),
    ("front_4", 4.3, 1.2, 1.4, 0.1),
    # office dividers
    ("divider_ab", -1.5, 2.6, 0.1, 2.8),
    ("divider_bc", 1.5, 2.6, 0.1, 2.8),
    # reception partition: leaves a 1.25 m passage up to the front wall
    ("reception_partition", -2.0, -2.05, 0.1, 3.9),
]
OBSTACLES = [
    ("reception_desk", -4.3, -3.3, 1.0, 0.5),
    ("pillar", 1.0, -0.8, 0.5, 0.5),
    ("cabinet", 3.8, -2.0, 0.6, 1.2),
    ("desk_a", -4.2, 3.5, 1.0, 0.5),
    ("desk_b", 0.0, 3.6, 1.0, 0.5),
    ("desk_c", 4.2, 3.5, 1.0, 0.5),
]


def box(name, cx, cy, sx, sy, rgba):
    return f"""      <collision name="{name}_col">
        <pose>{cx} {cy} {H/2} 0 0 0</pose>
        <geometry><box><size>{sx} {sy} {H}</size></box></geometry>
      </collision>
      <visual name="{name}_vis">
        <pose>{cx} {cy} {H/2} 0 0 0</pose>
        <geometry><box><size>{sx} {sy} {H}</size></box></geometry>
        <material><ambient>{rgba}</ambient><diffuse>{rgba}</diffuse></material>
      </visual>
"""


ROBOT = f"""    <!-- ===================== mail_bot (differential drive) =====================
         Frames: odom -> base_link (Gazebo DiffDrive via /tf), base_link -> lidar_link (static TF).
         Wheel radius 0.05 m, wheel separation 0.34 m, chassis 0.36 x 0.30 m. -->
    <model name="mail_bot">
      <pose>{START[0]} {START[1]} 0.01 0 0 0</pose>

      <link name="base_link">
        <pose>0 0 0.05 0 0 0</pose>
        <inertial>
          <pose>0 0 0.03 0 0 0</pose>
          <mass>5.0</mass>
          <inertia><ixx>0.0417</ixx><iyy>0.0582</iyy><izz>0.0915</izz><ixy>0</ixy><ixz>0</ixz><iyz>0</iyz></inertia>
        </inertial>
        <collision name="chassis_col">
          <pose>0 0 0.03 0 0 0</pose>
          <geometry><box><size>0.36 0.30 0.10</size></box></geometry>
        </collision>
        <visual name="chassis_vis">
          <pose>0 0 0.03 0 0 0</pose>
          <geometry><box><size>0.36 0.30 0.10</size></box></geometry>
          <material><ambient>0.1 0.3 0.7 1</ambient><diffuse>0.1 0.3 0.7 1</diffuse></material>
        </visual>
        <collision name="front_caster_col">
          <pose>0.13 0 -0.025 0 0 0</pose>
          <geometry><sphere><radius>0.025</radius></sphere></geometry>
          <surface><friction><ode><mu>0.0</mu><mu2>0.0</mu2></ode></friction></surface>
        </collision>
        <visual name="front_caster_vis">
          <pose>0.13 0 -0.025 0 0 0</pose>
          <geometry><sphere><radius>0.025</radius></sphere></geometry>
        </visual>
        <collision name="rear_caster_col">
          <pose>-0.13 0 -0.025 0 0 0</pose>
          <geometry><sphere><radius>0.025</radius></sphere></geometry>
          <surface><friction><ode><mu>0.0</mu><mu2>0.0</mu2></ode></friction></surface>
        </collision>
        <visual name="rear_caster_vis">
          <pose>-0.13 0 -0.025 0 0 0</pose>
          <geometry><sphere><radius>0.025</radius></sphere></geometry>
        </visual>
        <visual name="lidar_vis">
          <pose>0 0 0.11 0 0 0</pose>
          <geometry><cylinder><radius>0.04</radius><length>0.05</length></cylinder></geometry>
          <material><ambient>0.8 0.1 0.1 1</ambient><diffuse>0.8 0.1 0.1 1</diffuse></material>
        </visual>

        <!-- 360 deg 2D LiDAR; +0.11 m above base_link, beam plane clears the chassis -->
        <sensor name="lidar" type="gpu_lidar">
          <pose>0 0 0.11 0 0 0</pose>
          <topic>scan</topic>
          <gz_frame_id>lidar_link</gz_frame_id>
          <update_rate>10</update_rate>
          <always_on>true</always_on>
          <visualize>false</visualize>
          <lidar>
            <scan>
              <horizontal>
                <samples>360</samples>
                <resolution>1</resolution>
                <min_angle>-3.14159</min_angle>
                <max_angle>3.14159</max_angle>
              </horizontal>
            </scan>
            <range><min>0.12</min><max>10.0</max><resolution>0.01</resolution></range>
            <noise><type>gaussian</type><mean>0.0</mean><stddev>0.01</stddev></noise>
          </lidar>
        </sensor>
      </link>

      <link name="left_wheel">
        <pose>0 0.17 0.05 -1.5708 0 0</pose>
        <inertial>
          <mass>0.5</mass>
          <inertia><ixx>0.00038</ixx><iyy>0.00038</iyy><izz>0.000625</izz><ixy>0</ixy><ixz>0</ixz><iyz>0</iyz></inertia>
        </inertial>
        <collision name="col">
          <geometry><cylinder><radius>0.05</radius><length>0.04</length></cylinder></geometry>
          <surface><friction><ode><mu>1.0</mu><mu2>1.0</mu2></ode></friction></surface>
        </collision>
        <visual name="vis">
          <geometry><cylinder><radius>0.05</radius><length>0.04</length></cylinder></geometry>
          <material><ambient>0.1 0.1 0.1 1</ambient><diffuse>0.1 0.1 0.1 1</diffuse></material>
        </visual>
      </link>
      <link name="right_wheel">
        <pose>0 -0.17 0.05 -1.5708 0 0</pose>
        <inertial>
          <mass>0.5</mass>
          <inertia><ixx>0.00038</ixx><iyy>0.00038</iyy><izz>0.000625</izz><ixy>0</ixy><ixz>0</ixz><iyz>0</iyz></inertia>
        </inertial>
        <collision name="col">
          <geometry><cylinder><radius>0.05</radius><length>0.04</length></cylinder></geometry>
          <surface><friction><ode><mu>1.0</mu><mu2>1.0</mu2></ode></friction></surface>
        </collision>
        <visual name="vis">
          <geometry><cylinder><radius>0.05</radius><length>0.04</length></cylinder></geometry>
          <material><ambient>0.1 0.1 0.1 1</ambient><diffuse>0.1 0.1 0.1 1</diffuse></material>
        </visual>
      </link>

      <joint name="left_wheel_joint" type="revolute">
        <parent>base_link</parent><child>left_wheel</child>
        <axis><xyz>0 0 1</xyz><limit><lower>-1e16</lower><upper>1e16</upper></limit></axis>
      </joint>
      <joint name="right_wheel_joint" type="revolute">
        <parent>base_link</parent><child>right_wheel</child>
        <axis><xyz>0 0 1</xyz><limit><lower>-1e16</lower><upper>1e16</upper></limit></axis>
      </joint>

      <plugin filename="gz-sim-diff-drive-system" name="gz::sim::systems::DiffDrive">
        <left_joint>left_wheel_joint</left_joint>
        <right_joint>right_wheel_joint</right_joint>
        <wheel_separation>0.34</wheel_separation>
        <wheel_radius>0.05</wheel_radius>
        <max_linear_velocity>0.6</max_linear_velocity>
        <max_angular_velocity>2.0</max_angular_velocity>
        <max_linear_acceleration>2.0</max_linear_acceleration>
        <max_angular_acceleration>4.0</max_angular_acceleration>
        <topic>cmd_vel</topic>
        <odom_topic>odom</odom_topic>
        <tf_topic>tf</tf_topic>
        <frame_id>odom</frame_id>
        <child_frame_id>base_link</child_frame_id>
        <odom_publish_frequency>30</odom_publish_frequency>
      </plugin>
    </model>
"""


def make_sdf(render_engine):
    walls = "".join(box(*w, "0.85 0.85 0.8 1") for w in WALLS)
    obst = "".join(box(*o, "0.75 0.45 0.2 1") for o in OBSTACLES)
    return f"""<?xml version="1.0" ?>
<!-- campus_offices.sdf  (generated by tools/generate_world_and_map.py - edit the generator, not this file) -->
<sdf version="1.9">
  <world name="campus_offices">
    <!-- CPU-friendly settings for a 2-core VirtualBox VM -->
    <physics name="vm_physics" type="ignored">
      <max_step_size>0.004</max_step_size>
      <real_time_factor>1.0</real_time_factor>
    </physics>
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
    <plugin filename="gz-sim-sensors-system" name="gz::sim::systems::Sensors">
      <render_engine>{render_engine}</render_engine>
    </plugin>
    <gravity>0 0 -9.8</gravity>
    <scene>
      <ambient>0.5 0.5 0.5 1</ambient>
      <background>0.7 0.8 0.9 1</background>
      <shadows>false</shadows>
    </scene>

    <light type="directional" name="sun">
      <cast_shadows>false</cast_shadows>
      <pose>0 0 10 0 0 0</pose>
      <diffuse>0.9 0.9 0.9 1</diffuse>
      <specular>0.2 0.2 0.2 1</specular>
      <direction>-0.5 0.1 -0.9</direction>
    </light>

    <model name="ground_plane">
      <static>true</static>
      <link name="link">
        <collision name="collision">
          <geometry><plane><normal>0 0 1</normal><size>40 40</size></plane></geometry>
        </collision>
        <visual name="visual">
          <geometry><plane><normal>0 0 1</normal><size>40 40</size></plane></geometry>
          <material><ambient>0.55 0.55 0.55 1</ambient><diffuse>0.6 0.6 0.6 1</diffuse></material>
        </visual>
      </link>
    </model>

    <model name="office_walls">
      <static>true</static>
      <link name="link">
{walls}      </link>
    </model>

    <model name="office_furniture">
      <static>true</static>
      <link name="link">
{obst}      </link>
    </model>

{ROBOT}  </world>
</sdf>
"""


def in_rect(x, y, r):
    _, cx, cy, sx, sy = r
    return abs(x - cx) <= sx / 2 and abs(y - cy) <= sy / 2


def make_map(stem):
    w, h = int(round(SIZE[0] / RES)), int(round(SIZE[1] / RES))
    origin = (WORLD_MIN[0] - START[0], WORLD_MIN[1] - START[1])  # map-frame lower-left
    rects = WALLS + OBSTACLES
    data = bytearray()
    for r in range(h):
        wy = WORLD_MIN[1] + (h - 1 - r + 0.5) * RES
        for c in range(w):
            wx = WORLD_MIN[0] + (c + 0.5) * RES
            if any(in_rect(wx, wy, q) for q in rects):
                data.append(0)
            elif INNER[0] <= wx <= INNER[1] and INNER[2] <= wy <= INNER[3]:
                data.append(254)
            else:
                data.append(205)
    with open(stem + ".pgm", "wb") as f:
        f.write(f"P5\n{w} {h}\n255\n".encode())
        f.write(bytes(data))
    with open(stem + ".yaml", "w") as f:
        f.write(f"""image: {os.path.basename(stem)}.pgm
mode: trinary
resolution: {RES}
origin: [{origin[0]:.2f}, {origin[1]:.2f}, 0.0]
negate: 0
occupied_thresh: 0.65
free_thresh: 0.196
""")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pkg", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                  "..", "src", "campus_mail_bot"))
    ap.add_argument("--render-engine", default="ogre2", help="ogre2 (default) or ogre")
    ap.add_argument("--skip-map", action="store_true", help="do not overwrite maps/campus_map.*")
    a = ap.parse_args()
    with open(os.path.join(a.pkg, "worlds", "campus_offices.sdf"), "w") as f:
        f.write(make_sdf(a.render_engine))
    if not a.skip_map:
        make_map(os.path.join(a.pkg, "maps", "campus_map"))
    print("Generated worlds/campus_offices.sdf" + ("" if a.skip_map else " and maps/campus_map.{pgm,yaml}"))
