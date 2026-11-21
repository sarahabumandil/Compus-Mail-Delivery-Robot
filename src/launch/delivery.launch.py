"""Stage 2 - DELIVERY: headless Gazebo + bridge + static TF + nav2_bringup (map + AMCL + Nav2) + RViz2.

  ros2 launch campus_mail_bot delivery.launch.py params_file:=nav2_baseline.yaml
  ros2 launch campus_mail_bot delivery.launch.py params_file:=nav2_tuned.yaml
  (a bare file name is resolved inside the package's config/ folder; absolute paths also work;
   'baseline' and 'tuned' are accepted as shortcuts)
"""
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, OpaqueFunction, TimerAction
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

SHORTCUTS = {'baseline': 'nav2_baseline.yaml', 'tuned': 'nav2_tuned.yaml'}


def _nav2(context):
    pkg = get_package_share_directory('campus_mail_bot')
    nav2_pkg = get_package_share_directory('nav2_bringup')

    params = LaunchConfiguration('params_file').perform(context)
    params = SHORTCUTS.get(params, params)
    if not os.path.isabs(params):
        params = os.path.join(pkg, 'config', params)
    map_yaml = LaunchConfiguration('map').perform(context)
    for label, path in (('params_file', params), ('map', map_yaml)):
        if not os.path.isfile(path):
            raise RuntimeError(f'[delivery.launch] {label} not found: {path}')
    print(f'[delivery.launch] params_file = {params}')
    print(f'[delivery.launch] map         = {map_yaml}')

    bringup = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(nav2_pkg, 'launch', 'bringup_launch.py')),
        launch_arguments={'slam': 'False',
                          'map': map_yaml,
                          'use_sim_time': 'True',
                          'params_file': params,
                          'autostart': 'True',
                          'use_composition': LaunchConfiguration('use_composition'),
                          'use_respawn': 'False'}.items())
    return [TimerAction(period=8.0, actions=[bringup])]


def generate_launch_description():
    pkg = get_package_share_directory('campus_mail_bot')

    sim = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(pkg, 'launch', 'sim_common.launch.py')),
        launch_arguments={'headless': LaunchConfiguration('headless'),
                          'software_gl': LaunchConfiguration('software_gl'),
                          'headless_rendering': LaunchConfiguration('headless_rendering')}.items())

    rviz = Node(package='rviz2', executable='rviz2', name='rviz2', output='screen',
                arguments=['-d', os.path.join(pkg, 'rviz', 'nav2.rviz')],
                parameters=[{'use_sim_time': True}],
                condition=IfCondition(LaunchConfiguration('rviz')))

    return LaunchDescription([
        DeclareLaunchArgument('headless', default_value='true'),
        DeclareLaunchArgument('software_gl', default_value='true'),
        DeclareLaunchArgument('headless_rendering', default_value='false'),
        DeclareLaunchArgument('rviz', default_value='true'),
        DeclareLaunchArgument('map', default_value=os.path.join(pkg, 'maps', 'campus_map.yaml'),
                              description='Full path to the map .yaml (default: package maps/campus_map.yaml)'),
        DeclareLaunchArgument('params_file', default_value='nav2_baseline.yaml',
                              description='nav2_baseline.yaml | nav2_tuned.yaml | absolute path'),
        DeclareLaunchArgument('use_composition', default_value='True',
                              description='Run Nav2 servers in one process (saves CPU)'),
        sim, OpaqueFunction(function=_nav2), rviz,
    ])
