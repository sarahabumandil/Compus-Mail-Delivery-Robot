#!/usr/bin/env bash
# Campus Mail Bot - one-click setup for Ubuntu 24.04 (VirtualBox) + ROS 2 Jazzy.
# Installs ROS 2 Jazzy + Gazebo Harmonic + Nav2 + SLAM Toolbox, builds the workspace,
# initialises git and prints the commands for Phase 1 (mapping).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO_DIR="$PWD"

echo "==> [1/5] Checking OS"
. /etc/os-release
if [ "${VERSION_ID:-}" != "24.04" ]; then
  echo "WARNING: this project targets Ubuntu 24.04 (found ${PRETTY_NAME:-unknown}). Continuing anyway."
fi

echo "==> [2/5] Adding the ROS 2 apt repository (if missing)"
sudo apt-get update
sudo apt-get install -y software-properties-common curl git
sudo add-apt-repository -y universe
if [ ! -f /etc/apt/sources.list.d/ros2.list ] && ! ls /etc/apt/sources.list.d/ 2>/dev/null | grep -qi ros2; then
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
       -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
fi
sudo apt-get update

echo "==> [3/5] Installing ROS 2 Jazzy, Gazebo Harmonic, Nav2, SLAM Toolbox, RViz2, tools"
sudo apt-get install -y \
  ros-jazzy-desktop ros-dev-tools python3-colcon-common-extensions python3-yaml python3-matplotlib \
  ros-jazzy-ros-gz ros-jazzy-ros-gz-sim ros-jazzy-ros-gz-bridge \
  ros-jazzy-navigation2 ros-jazzy-nav2-bringup ros-jazzy-nav2-simple-commander \
  ros-jazzy-nav2-map-server ros-jazzy-slam-toolbox \
  ros-jazzy-tf2-tools ros-jazzy-tf2-ros ros-jazzy-teleop-twist-keyboard ros-jazzy-rviz2

if ! grep -q "source /opt/ros/jazzy/setup.bash" ~/.bashrc; then
  echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
fi
# shellcheck disable=SC1091
set +u; source /opt/ros/jazzy/setup.bash; set -u

echo "==> [4/5] Building the workspace (colcon build --symlink-install)"
colcon build --symlink-install
mkdir -p results docs/evidence

echo "==> [5/5] Git"
if [ ! -d .git ]; then
  git init -q
  git add -A
  git -c user.name="${GIT_AUTHOR_NAME:-CampusMailBot}" -c user.email="${GIT_AUTHOR_EMAIL:-team@example.com}" \
      commit -q -m "Initial commit: Campus Mail Bot (ROS 2 Jazzy)" || true
  echo "Git repository initialised."
else
  echo "Git repository already present."
fi

cat <<MSG

======================================================================
 SETUP COMPLETE  -  Phase 1: MAPPING  (open 3 terminals, one per block)
======================================================================
 Every terminal first:
     cd $REPO_DIR && source /opt/ros/jazzy/setup.bash && source install/setup.bash

 Terminal 1 - Gazebo (headless) + bridge + TF + SLAM Toolbox + RViz2:
     ros2 launch campus_mail_bot mapping.launch.py

 Terminal 2 - drive SLOWLY (press 'k' to stop, 'z' to lower speed):
     ros2 run teleop_twist_keyboard teleop_twist_keyboard

 Terminal 3 - when the map in RViz looks complete, save it:
     ./scripts/save_map.sh

 Phase 2 (delivery) and the 5+ benchmark trials: see docs/02_STEP_BY_STEP_WORKFLOW_GUIDE.md
 Tip: if RViz is black/crashes:  export LIBGL_ALWAYS_SOFTWARE=1   (the launch files already do this)
======================================================================
MSG
