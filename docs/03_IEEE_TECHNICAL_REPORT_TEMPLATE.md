# 03 — IEEE-Inspired Technical Report Template (single column, 5–6 pages excl. references)

> Copy this into a Word document (single column; IEEE-style numbered citations `[1]`). Replace every `<...>`.
> Keep figures large; label and reference every figure/table in the text; no code screenshots.

---

# Campus Mail Bot: Autonomous Indoor Office Delivery Robot in Simulation

**Sarah Abu Mandil, Asala AbuGharara, Nada Abu Alkhair, Aseel Abu Rabee**
DSAI 4304 Robotics Programming — Instructor: Dr. Shadia Yahya Baroud — First Semester 2026–2027

### Abstract (150–200 words)
*(Draft — adjust numbers to your results; ≈170 words.)*
Indoor mail delivery is repetitive work that mobile robots can automate. This project presents Campus Mail Bot, a
simulated differential-drive robot that autonomously delivers items from a reception area to three offices in a 10 m × 8 m
floor plan. The system uses ROS 2 Jazzy, Gazebo Harmonic, SLAM Toolbox, AMCL and Nav2. A 2D LiDAR and wheel odometry
feed an online pose-graph SLAM pipeline to build and save an occupancy grid; after restarting, the robot localizes on the
saved map and executes ordered goals through a mission node built on the Nav2 simple commander. We compare a baseline
Nav2 configuration (costmap inflation radius 0.55 m) with a tuned configuration (0.30 m) over `<N>` trials on two routes,
measuring goal completion, mission time, path length and near-collision events logged automatically to CSV. The robot
reached `<X>` of `<Y>` goals in the baseline and `<X2>` of `<Y2>` in the tuned configuration; mean mission time changed
from `<T1>` s to `<T2>` s. The results `<support / do not support>` the hypothesis that a smaller inflation radius improves
narrow-passage navigation. All code, maps, parameters and instructions are provided for one-command reproduction.

**Keywords:** mobile robot navigation, SLAM, AMCL, Nav2, ROS 2

---

## I. Introduction
*Problem:* manual indoor delivery is slow/repetitive. *Scenario:* reception + offices A, B, C joined by corridor and doors; a
partition creates a ≈1.25 m passage. *Requirements:* (R1) build/save a 2D map; (R2) relocalize after restart; (R3) reach
3 ordered goals autonomously; (R4) log time, distance, goals, near-collisions (< 0.22 m); (R5) reproducible
from the package. *Contributions:* `<list 3 bullets>`. *Paper outline:* Section II … VI.

## II. System Design
**A. Architecture** — Fig. 1 (paste the Mermaid diagram as an image): Gazebo → ros_gz_bridge → SLAM/AMCL → Nav2 → mission node.
**B. Robot model and kinematics** — wheel radius 0.05 m, separation 0.34 m, footprint radius 0.24 m;
$v=r(\omega_R+\omega_L)/2$, $\omega=r(\omega_R-\omega_L)/L$ [1].
**C. Coordinate frames** — `map → odom → base_link → lidar_link` (Fig. 2: your `view_frames` image). `odom→base_link` from Gazebo
DiffDrive; `base_link→lidar_link` static (z = 0.11 m); `map→odom` from SLAM/AMCL; map origin = start pose.
**D. Sensing** — 360° LiDAR, 0.12–10 m, 10 Hz, σ = 0.01 m; odometry from wheel encoders; assumptions: flat floor, static scene, no slip.
**E. Mapping and localization** — SLAM Toolbox online async, Ceres back-end, 0.05 m resolution [2]; map saved with
`map_saver_cli`; AMCL with likelihood field, 300–1000 particles [3], [4].
**F. Planning and control** — NavFn global planner (Dijkstra/A\*), DWB local controller, costmap inflation, behavior-tree
recoveries [5], [6].

## III. Implementation
ROS 2 package `campus_mail_bot` (ament_python). *Launch:* `mapping.launch.py`, `delivery.launch.py` (+ shared `sim_common`).
*Nodes:* `gz sim` (headless), `parameter_bridge`, `static_transform_publisher`, `slam_toolbox`, `map_server`, `amcl`, Nav2 servers,
`mission_runner`. *Interfaces:* `NavigateToPose` action, `/scan`, `/odom`, `/cmd_vel`, `/tf`. *Nav2 configuration:* derived from the
official Jazzy file; Table I lists the changed parameters. *VM optimizations:* headless Gazebo, shadows off, 4 ms physics step, software GL.

**Table I — Nav2 parameters** (`<verify against your YAML>`)

| Parameter | Baseline | Tuned |
|---|---|---|
| inflation_radius (global & local) | 0.55 m | **0.30 m** |
| cost_scaling_factor | 3.0 | 3.0 |
| robot_radius | 0.24 m | 0.24 m |
| max speed / controller rate | 0.26 m/s / 15 Hz | same |

## IV. Experimental Method
*Conditions:* same VM (2 cores), same SLAM map, start pose Reception (−3.5, −2.5). *Routes:* default (R→A→B→C), alt (R→C→A→B).
*Configurations:* baseline vs tuned_inflation. *Procedure:* each trial executed by `mission_runner --route R --trial N --tag T`;
robot auto-reset to Reception; `<N>` trials total (≥ 5). *Measures:* goals reached/total; mission time (sim s); path length
$\sum\sqrt{\Delta x^2+\Delta y^2}$ from `/odom`; minimum LiDAR range; near-collision events (range < 0.22 m). *Threats to validity:* single
simulator seed/noise, small `N`, LiDAR range as collision proxy.

## V. Results and Discussion
**Table II — Per-trial results** (paste output of `python3 tools/summarize_results.py`)

| Trial | Route | Tag | Goals | Time (s) | Distance (m) | Min obstacle (m) | Status |
|---|---|---|---|---|---|---|---|
| 1 | default | baseline | `<3/3>` | `<>` | `<>` | `<>` | `<>` |
| 2 | alt | baseline | | | | | |
| 3 | default | tuned_inflation | | | | | |
| 4 | alt | tuned_inflation | | | | | |
| 5 | `<>` | `<>` | | | | | |

**Table III — Summary by configuration**

| Tag | Runs | Goal success | Mean time (s) | Mean distance (m) | Near-collision events | Min obstacle (m) |
|---|---|---|---|---|---|---|
| baseline | `<>` | `<>` | `<>` | `<>` | `<>` | `<>` |
| tuned_inflation | `<>` | `<>` | `<>` | `<>` | `<>` | `<>` |

**Fig. 3** — RViz screenshot: map, global path (red), local path (blue), particles. **Fig. 4** — bar chart of mean time/distance per tag.

**Discussion (parameter trade-offs).** *Smaller inflation (0.30 m)* lowers cell costs near walls, so the global planner chooses
shorter paths through doors and the 1.25 m passage and the controller needs fewer slow-downs/recoveries — but clearance shrinks,
raising the chance of near-collisions, wall-hugging and DWB oscillation. *Larger inflation (0.55 m)* is safer but can make
passages look expensive or blocked, causing detours, recoveries or failures. Explain *your* data: `<which route/goal was
hardest, recoveries from trials_details.csv, did min obstacle distance drop below 0.22 m?>`. Compare default vs alt route
(order effects: alt starts with the farthest office). **Limitations:** simulation only, small `N`, no statistical test, one
parameter changed, proxy collision metric, static environment. State clearly what the evidence does **not** show.

## VI. Conclusion
Main findings (2–3 sentences with numbers). **Next improvement (evidence-based):** e.g. `<tune DWB PathAlign/GoalAlign critics>` or
`<add a moving obstacle and test replanning>` because `<observed failure mode>`.

## Individual Contribution Statements
*(Drafts — each student must edit to reflect what they personally did and be ready to explain it.)*
- **Sarah Abu Mandil:** designed `campus_offices.sdf` and the `mail_bot` model (kinematic parameters, LiDAR), configured the ROS–Gazebo bridge,
  verified TF/sensor topics (`view_frames`, `topic hz`), and contributed to Sections II.B–D.
- **Asala AbuGharara:** tuned and ran SLAM Toolbox, performed the slow-scan mapping and map QA, validated AMCL relocalization,
  and wrote Section II.E and the mapping part of the demo.
- **Nada Abu Alkhair:** prepared the Nav2 baseline/tuned parameter files, executed the benchmark trials, analyzed CSV results and wrote
  Sections IV–V.
- **Aseel Abu Rabee:** implemented `mission_runner.py` (routes, metrics logger), the repository/README/setup script, assembled the report and demo video, and
  maintained references.
*(Add individual 3–5 sentence reflections on a separate page as required by the brief.)*

## References
Use `docs/04_SOURCES_AND_REFERENCES.md`; number in order of first citation. **Cite any external code and permitted AI assistance used.**
