# Contributing to Campus Mail Bot

We welcome contributions, experimental extensions, and bug reports from the robotics research community!

## How to Contribute
1. **Fork** the repository and create a new feature branch (`git checkout -b feat/your-feature-name`).
2. **Follow ROS 2 Conventions:** Ensure all Python scripts adhere to PEP 8 and pass `ament_flake8` checks.
3. **Test in Simulation:** Verify your changes in Gazebo Harmonic before submitting a Pull Request.
4. **Submit a Pull Request:** Provide a clear summary of your changes and attach benchmark logs (`results/`) if your PR modifies navigation parameters.

## Research Extensions Ideas
* Adding dynamic obstacles (e.g., walking pedestrians) to `campus_offices.sdf`.
* Benchmarking alternative Nav2 controllers (e.g., MPPI or Regulated Pure Pursuit) against DWB.
* Integrating multi-floor elevator simulation.
