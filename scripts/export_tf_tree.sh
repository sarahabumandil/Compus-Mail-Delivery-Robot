#!/usr/bin/env bash
# Export the TF tree (frames.pdf) + topic evidence into docs/evidence/ while the simulation runs.
cd "$(dirname "$(readlink -f "$0")")/.."
source /opt/ros/jazzy/setup.bash && source install/setup.bash
mkdir -p docs/evidence && cd docs/evidence
{
  echo "== topics =="; ros2 topic list | grep -E "scan|odom|tf|cmd_vel|clock|map|amcl"
  echo "== /scan rate =="; timeout 6 ros2 topic hz /scan
  echo "== /odom rate =="; timeout 6 ros2 topic hz /odom
  echo "== /scan header =="; ros2 topic echo /scan --once --field header
  echo "== TF map->base_link =="; timeout 6 ros2 run tf2_ros tf2_echo map base_link
} 2>&1 | tee evidence.txt
ros2 run tf2_tools view_frames      # writes frames_<date>.pdf / .gv in this folder
echo "Evidence saved in docs/evidence/"
