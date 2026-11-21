"""Shared simulation stack: Gazebo Harmonic (HEADLESS by default) + ros_gz_bridge + static TF.

TF tree (no breaks):   map -> odom -> base_link -> lidar_link
  * map -> odom        : slam_toolbox (mapping) or AMCL (delivery)
  * odom -> base_link  : Gazebo DiffDrive plugin, bridged on /tf
  * base_link -> lidar_link : static_transform_publisher below (must match the 0.11 m sensor pose in the SDF)

Arguments
  headless:=true|false           gz sim -s (server only, default) vs. with the Gazebo GUI
  software_gl:=true|false        force Mesa software rendering (LIBGL_ALWAYS_SOFTWARE=1) - safest in VirtualBox
  headless_rendering:=true|false add --headless-rendering (EGL, no X display needed) if the server crashes
"""
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, ExecuteProcess, OpaqueFunction, SetEnvironmentVariable
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def _gazebo(context):
    pkg = get_package_share_directory('campus_mail_bot')
    world = os.path.join(pkg, 'worlds', 'campus_offices.sdf')
    cmd = ['gz', 'sim', '-r']
    if LaunchConfiguration('headless').perform(context).lower() == 'true':
        cmd.append('-s')
    if LaunchConfiguration('headless_rendering').perform(context).lower() == 'true':
        cmd.append('--headless-rendering')
    cmd.append(world)
    return [ExecuteProcess(cmd=cmd, output='screen')]


def generate_launch_description():
    pkg = get_package_share_directory('campus_mail_bot')

    bridge = Node(package='ros_gz_bridge', executable='parameter_bridge', name='gz_bridge',
                  output='screen',
                  parameters=[{'config_file': os.path.join(pkg, 'config', 'bridge.yaml'),
                               'use_sim_time': True}])

    lidar_tf = Node(package='tf2_ros', executable='static_transform_publisher',
                    name='base_to_lidar_tf', output='screen',
                    arguments=['--x', '0', '--y', '0', '--z', '0.11',
                               '--roll', '0', '--pitch', '0', '--yaw', '0',
                               '--frame-id', 'base_link', '--child-frame-id', 'lidar_link'],
                    parameters=[{'use_sim_time': True}])

    return LaunchDescription([
        DeclareLaunchArgument('headless', default_value='true',
                              description='Run Gazebo server only (no GUI). Default true.'),
        DeclareLaunchArgument('software_gl', default_value='true',
                              description='Use Mesa software rendering (recommended in VirtualBox).'),
        DeclareLaunchArgument('headless_rendering', default_value='false',
                              description='Pass --headless-rendering (EGL) to gz sim.'),
        SetEnvironmentVariable('LIBGL_ALWAYS_SOFTWARE', '1',
                               condition=IfCondition(LaunchConfiguration('software_gl'))),
        OpaqueFunction(function=_gazebo),
        bridge,
        lidar_tf,
    ])
