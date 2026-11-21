"""Stage 1 - MAPPING: headless Gazebo + bridge + static TF + SLAM Toolbox (online_async) + RViz2.

Drive with:  ros2 run teleop_twist_keyboard teleop_twist_keyboard
Save with:   ros2 run nav2_map_server map_saver_cli -f <path>/campus_map --free 0.196 --occ 0.65
"""
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, TimerAction
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    pkg = get_package_share_directory('campus_mail_bot')
    slam_pkg = get_package_share_directory('slam_toolbox')

    sim = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(pkg, 'launch', 'sim_common.launch.py')),
        launch_arguments={'headless': LaunchConfiguration('headless'),
                          'software_gl': LaunchConfiguration('software_gl'),
                          'headless_rendering': LaunchConfiguration('headless_rendering')}.items())

    slam = TimerAction(period=6.0, actions=[IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(slam_pkg, 'launch', 'online_async_launch.py')),
        launch_arguments={'use_sim_time': 'true',
                          'slam_params_file': os.path.join(pkg, 'config', 'slam_params.yaml')}.items())])

    rviz = Node(package='rviz2', executable='rviz2', name='rviz2', output='screen',
                arguments=['-d', os.path.join(pkg, 'rviz', 'mapping.rviz')],
                parameters=[{'use_sim_time': True}],
                condition=IfCondition(LaunchConfiguration('rviz')))

    return LaunchDescription([
        DeclareLaunchArgument('headless', default_value='true'),
        DeclareLaunchArgument('software_gl', default_value='true'),
        DeclareLaunchArgument('headless_rendering', default_value='false'),
        DeclareLaunchArgument('rviz', default_value='true'),
        sim, slam, rviz,
    ])
