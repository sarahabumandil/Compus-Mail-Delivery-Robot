import os
from glob import glob
from setuptools import find_packages, setup

package_name = 'campus_mail_bot'

setup(
    name=package_name,
    version='1.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.py')),
        (os.path.join('share', package_name, 'config'), glob('config/*.yaml')),
        (os.path.join('share', package_name, 'worlds'), glob('worlds/*.sdf')),
        (os.path.join('share', package_name, 'maps'), glob('maps/*')),
        (os.path.join('share', package_name, 'rviz'), glob('rviz/*.rviz')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Campus Mail Bot Team',
    maintainer_email='campusmailbot@example.com',
    description='Autonomous indoor office delivery robot (ROS 2 Jazzy)',
    license='Apache-2.0',
    entry_points={
        'console_scripts': [
            'mission_runner = campus_mail_bot.mission_runner:main',
        ],
    },
)
