#!/usr/bin/env bash
# Save the SLAM map into the package (overwrites maps/campus_map.{yaml,pgm}).
set -e
cd "$(dirname "$(readlink -f "$0")")/.."
source /opt/ros/jazzy/setup.bash
source install/setup.bash
OUT="$PWD/src/campus_mail_bot/maps/${1:-campus_map}"
ros2 run nav2_map_server map_saver_cli -f "$OUT" --free 0.196 --occ 0.65 \
     --ros-args -p use_sim_time:=true
echo "Saved $OUT.yaml and $OUT.pgm"
echo "(symlink-install: no rebuild needed if the files already existed; otherwise run: colcon build --symlink-install)"
