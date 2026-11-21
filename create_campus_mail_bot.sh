#!/usr/bin/env bash
# Recreates the complete campus_mail_bot repository in ./campus_mail_bot (run once in your Ubuntu terminal).
#   bash create_campus_mail_bot.sh && cd campus_mail_bot && ./setup.sh
set -euo pipefail
ROOT="${1:-campus_mail_bot}"
mkdir -p "$ROOT" && cd "$ROOT"
echo "Creating repository files in $PWD ..."
cat > ".gitignore" <<'__CMB_EOF__'
build/
install/
log/
__pycache__/
*.pyc
docs/evidence/*.pdf
docs/evidence/*.gv
__CMB_EOF__
cat > "README.md" <<'__CMB_EOF__'
# 📬 Campus Mail Bot — Autonomous Indoor Office Delivery Robot

**Course:** DSAI 4304 Robotics Programming · **Instructor:** Dr. Shadia Yahya Baroud · **Semester:** First 2026–2027
**Stack:** Ubuntu 24.04 (VirtualBox, 2 CPU cores, no GPU) · ROS 2 Jazzy · Gazebo Harmonic · SLAM Toolbox · Nav2 · RViz2

A simulated differential-drive robot (`mail_bot`, 2D LiDAR + odometry) maps a compact 10 m × 8 m office floor
with SLAM Toolbox, localizes on the saved map with AMCL, and autonomously delivers mail from **Reception** to
**Office A, B and C** through Nav2. A mission node (`mission_runner`) executes two routes, logs distance,
time, goal completion and near-collision events to CSV, and lets the team compare a **baseline** Nav2
configuration (`inflation_radius 0.55`) against a **tuned** one (`inflation_radius 0.30`).

> **VirtualBox-first design:** Gazebo runs *headless* (`gz sim -s -r`) by default; RViz2 is the only GUI.
> Shadows are disabled, physics step is 0.004 s, Mesa software GL is forced, and every node uses `use_sim_time`.

## Team and roles

| Member | Primary role | Main deliverables |
|---|---|---|
| Sarah Abu Mandil | Simulation & robot lead | World/robot SDF, bridge, TF verification |
| Asala AbuGharara | Mapping & localization lead | SLAM Toolbox tuning, saved map, AMCL checks |
| Nada Abu Alkhair | Nav2 & experiments lead | Baseline/tuned parameters, 5+ trials, analysis |
| Aseel Abu Rabee | Integration, mission & documentation lead | `mission_runner`, report, demo video, README |

*(Roles are a proposed split — edit to match who really did what; every member must be able to explain all parts.)*

## System architecture

```mermaid
flowchart LR
  subgraph GZ["Gazebo Harmonic (headless: gz sim -s -r)"]
    W[campus_offices.sdf<br/>walls, offices, mail_bot]
    D[DiffDrive plugin]
    L[gpu_lidar 360°, 10 Hz]
  end
  BR[ros_gz_bridge<br/>/clock /cmd_vel /odom /scan /tf]
  ST[static_transform_publisher<br/>base_link → lidar_link]
  subgraph STAGE1["Stage 1: mapping.launch.py"]
    SLAM[slam_toolbox<br/>online_async]
  end
  subgraph STAGE2["Stage 2: delivery.launch.py"]
    MS[map_server<br/>campus_map.yaml]
    AMCL[AMCL<br/>map → odom]
    NAV[Nav2: NavFn global planner<br/>DWB local controller<br/>costmaps · BT · behaviors]
  end
  MR[mission_runner.py<br/>BasicNavigator + CSV logger]
  RV[RViz2<br/>mapping.rviz / nav2.rviz]
  CSV[(results/trials_results.csv)]

  W --- D --- BR
  L --> BR
  BR -- /scan /odom /tf /clock --> SLAM
  BR -- /scan /odom /tf /clock --> AMCL
  ST --> SLAM
  ST --> NAV
  MS --> AMCL --> NAV
  NAV -- cmd_vel --> BR
  MR -- NavigateToPose --> NAV
  BR -- /odom /scan --> MR
  MR --> CSV
  SLAM --> RV
  NAV --> RV
```

TF tree: `map → odom → base_link → lidar_link` (`map→odom`: SLAM/AMCL, `odom→base_link`: Gazebo DiffDrive via `/tf`,
`base_link→lidar_link`: static publisher).

## Repository tree

```
campus_mail_bot/
├── setup.sh                         # one-click install + build + git init
├── README.md
├── docs/
│   ├── 01_PROJECT_IDEA_AND_THEORY.md
│   ├── 02_STEP_BY_STEP_WORKFLOW_GUIDE.md
│   ├── 03_IEEE_TECHNICAL_REPORT_TEMPLATE.md
│   ├── 04_SOURCES_AND_REFERENCES.md
│   └── evidence/                    # TF tree, topic rates, screenshots
├── results/                         # trials_results.csv, trials_details.csv
├── scripts/                         # save_map.sh, export_tf_tree.sh
├── tools/                           # generate_world_and_map.py, make_nav2_params.py, summarize_results.py
└── src/campus_mail_bot/             # ROS 2 package (ament_python)
    ├── campus_mail_bot/mission_runner.py
    ├── launch/  sim_common.launch.py · mapping.launch.py · delivery.launch.py
    ├── config/  bridge.yaml · slam_params.yaml · nav2_baseline.yaml · nav2_tuned.yaml · routes.yaml
    ├── worlds/campus_offices.sdf
    ├── maps/    campus_map.yaml/.pgm    (starter map; overwrite with your SLAM map)
    └── rviz/    mapping.rviz · nav2.rviz
```

## Exact clean-start commands (for grading / reproducibility)

```bash
# 0) Fresh Ubuntu 24.04 VM, internet on.
git clone <YOUR_GITHUB_URL>/campus_mail_bot.git ~/campus_mail_bot    # or unzip into ~/campus_mail_bot
cd ~/campus_mail_bot
./setup.sh                                  # installs ROS 2 Jazzy/Gazebo/Nav2/SLAM Toolbox, builds, git init

# Every terminal:
cd ~/campus_mail_bot && source /opt/ros/jazzy/setup.bash && source install/setup.bash
```

**Phase 1 – Mapping (3 terminals)**
```bash
ros2 launch campus_mail_bot mapping.launch.py                 # T1
ros2 run teleop_twist_keyboard teleop_twist_keyboard          # T2 (drive slowly)
./scripts/save_map.sh                                         # T3 when the map is complete
```

**Phase 2 – Delivery + benchmark (2 terminals)**
```bash
# T1: Gazebo (headless) + AMCL + Nav2 + RViz  (baseline config)
ros2 launch campus_mail_bot delivery.launch.py params_file:=nav2_baseline.yaml
# T2: one automated trial
ros2 run campus_mail_bot mission_runner --route default --trial 1 --tag baseline
```
For the tuned configuration restart T1 with `params_file:=nav2_tuned.yaml` and use `--tag tuned_inflation`.
Full trial matrix (≥ 5 trials, both routes, both configs): `docs/02_STEP_BY_STEP_WORKFLOW_GUIDE.md`.
Summarize: `python3 tools/summarize_results.py > results/summary.md`.

No time to map? `maps/campus_map.yaml` is a generated starter map in the same map frame, so Phase 2 works immediately
(get the instructor's approval first, as the course brief requires, and explain the map in the report).

## Key design choices

* **Frames:** map frame = robot start pose (SLAM convention). `config/routes.yaml` stores world coordinates and
  `mission_runner` subtracts the start pose, so goals work with both your SLAM map and the starter map.
* **Nav2:** official Jazzy parameter file patched by `tools/make_nav2_params.py` (DWB controller, `robot_radius 0.24`,
  `use_sim_time` everywhere). Baseline vs tuned differ **only** in `inflation_radius` (0.55 → 0.30).
* **Metrics:** distance = Σ√(Δx²+Δy²) from `/odom`; time = simulation time; near-collision = `/scan` range < 0.22 m.

## Status / honesty note

Static checks done (SDF/YAML/Python syntax, generated map). The package has **not** been executed against a live
Jazzy + Harmonic install by the author of this template — run the workflow guide once and adjust timing/tolerances if needed.
Cite external code and any AI assistance in the report, as the course's academic-integrity rules require.
__CMB_EOF__
mkdir -p "docs"
cat > "docs/01_PROJECT_IDEA_AND_THEORY.md" <<'__CMB_EOF__'
# 01 — Project Idea, Architecture and Theory

## 1. Problem and motivation
Offices still move small items (mail, signed forms, supplies) by hand. A robot that can **build a map, localize on
it and drive to named rooms in order** removes repetitive walking and is a compact showcase of the full mobile-robot
autonomy stack: sensing → state estimation → mapping → planning → control.

**Scenario.** One floor, 10 m × 8 m. Reception/start zone at world (−3.5, −2.5); three offices A (−3.0, 2.5),
B (0.0, 2.5), C (3.0, 2.5) opening onto a corridor through 1.2 m doors. A reception partition leaves a ≈1.25 m
passage, so reaching Offices B/C forces the planner and controller to deal with a **narrow corridor** — the reason
the experiment tunes the costmap inflation radius.

**Measurable requirements** (to refine in the project plan)

| ID | Requirement | Measure |
|---|---|---|
| R1 | Map the floor with SLAM Toolbox and save it | map file exists; walls/doors visible |
| R2 | Localize on the saved map after restart | AMCL pose stable, goals reachable |
| R3 | Reach 3 ordered goals with no manual driving | `Goals_Reached / Total_Goals` |
| R4 | Safe motion | near-collision events (< 0.22 m), `Min_Obstacle_Dist` |
| R5 | Efficient motion | `Time_sec`, `Distance_m` |
| R6 | Reproducible | `setup.sh` + README commands only |

## 2. System architecture
See the Mermaid diagram in `README.md`. Data flow:

1. **Gazebo** simulates physics, the differential-drive base and a 360° LiDAR. It runs headless (`gz sim -s -r`).
2. **ros_gz_bridge** translates `/clock`, `/cmd_vel`, `/odom`, `/scan`, `/tf` between Gazebo Transport and ROS 2.
3. **TF**: `odom→base_link` from the DiffDrive plugin, `base_link→lidar_link` from `static_transform_publisher`,
   `map→odom` from SLAM Toolbox (mapping) or AMCL (delivery).
4. **Stage 1** `slam_toolbox` (online async) builds `/map` while the operator teleoperates slowly.
5. **Stage 2** `nav2_bringup` loads the saved map (`map_server`), AMCL localizes, Nav2 plans and controls.
6. `mission_runner` sends `NavigateToPose` goals through `BasicNavigator`, logs metrics to CSV.

| Topic | Type | Direction (ROS side) |
|---|---|---|
| `/clock` | `rosgraph_msgs/Clock` | Gazebo → ROS |
| `/scan` | `sensor_msgs/LaserScan` (frame `lidar_link`) | Gazebo → ROS |
| `/odom` | `nav_msgs/Odometry` (`odom → base_link`) | Gazebo → ROS |
| `/tf` | `tf2_msgs/TFMessage` | Gazebo → ROS (+SLAM/AMCL/static) |
| `/cmd_vel` | `geometry_msgs/Twist` | Nav2 / teleop → Gazebo |
| `/map` | `nav_msgs/OccupancyGrid` | SLAM Toolbox or map_server |

Simulation time: every node runs with `use_sim_time:=true`, so all timestamps come from `/clock`; results stay
comparable even when the VM runs slower than real time.

## 3. Robot kinematics (differential drive)
Wheel radius $r = 0.05$ m, wheel separation $L = 0.34$ m. With wheel angular speeds $\omega_L,\omega_R$:

$$v = \frac{r(\omega_R+\omega_L)}{2},\qquad \omega = \frac{r(\omega_R-\omega_L)}{L}$$

Pose (odometry) integration with step $\Delta t$ (what the DiffDrive plugin publishes on `/odom`):

$$x_{k+1}=x_k+v\cos\theta_k\,\Delta t,\quad y_{k+1}=y_k+v\sin\theta_k\,\Delta t,\quad \theta_{k+1}=\theta_k+\omega\,\Delta t$$

The robot is **non-holonomic** (no sideways motion), so planners/controllers must respect $v_y=0$. Odometry drifts
without bound, which is why a map-based estimator (SLAM/AMCL) supplies the `map→odom` correction.

## 4. 2D LiDAR model
360 beams, range 0.12–10 m, 10 Hz, Gaussian noise σ = 0.01 m. A beam $i$ returns range $z_i$ at angle $\alpha_i$; in
the sensor frame the hit point is $(z_i\cos\alpha_i,\; z_i\sin\alpha_i)$. The sensor sits 0.11 m above `base_link` so the
beam plane clears the chassis.

## 5. 2D LiDAR SLAM — pose-graph optimization
SLAM Toolbox (Karto-based) is a **graph-based SLAM** system:

* **Nodes** $x_i$ are robot poses at selected keyframes (a new keyframe when the robot moves ≥ 0.2 m or turns ≥ 0.2 rad).
* **Edges** are relative-pose constraints $z_{ij}$ with information matrix $\Omega_{ij}$: odometry edges and
  **scan-matching** edges (correlative scan matching aligns the new scan with recent scans) and **loop-closure** edges
  when the robot revisits a place.

Back-end optimization finds the poses that best satisfy all constraints:

$$X^{*}=\arg\min_{X}\sum_{(i,j)}\; e_{ij}(x_i,x_j)^{\top}\,\Omega_{ij}\,e_{ij}(x_i,x_j),\qquad
e_{ij}=\text{log}\!\left(z_{ij}^{-1}\,(x_i^{-1}x_j)\right)$$

It is solved by sparse nonlinear least squares (Gauss–Newton/Levenberg–Marquardt; here the **Ceres** solver with
sparse Cholesky). The occupancy grid is rendered from the optimized poses: each cell stores
$\log\frac{p(m_c)}{1-p(m_c)}$, updated by ray-casting (free along the beam, occupied at the endpoint).

*Online async mode* processes the latest scan and drops older ones when the CPU is busy — important on 2 cores.
Driving **slowly** gives scan matching more overlap and avoids drift/ghost walls.

## 6. AMCL — Monte Carlo localization
Given a map $m$, AMCL tracks the belief $bel(x_t)=p(x_t\mid z_{1:t},u_{1:t},m)$ with $N$ weighted particles:

1. **Predict:** sample $x_t^{[i]}\sim p(x_t\mid x_{t-1}^{[i]},u_t)$ using the odometry motion model (noise $\alpha_{1..5}$).
2. **Weight:** $w_t^{[i]}\propto p(z_t\mid x_t^{[i]},m)$ — the **likelihood-field** model:
   $p(z)=z_{hit}\,\mathcal N(d;0,\sigma_{hit}^2)+\dfrac{z_{rand}}{z_{max}}$, where $d$ is the distance from the beam endpoint to the nearest map obstacle.
3. **Resample** proportionally to weights. **KLD-sampling** adapts $N$ (here 300–1000) to the uncertainty.

AMCL outputs the transform `map→odom`, so `map→base_link = (map→odom)·(odom→base_link)` is smooth (odometry) yet
drift-free (map). The initial pose is set to the start pose $(0,0,0)$ in the map frame.

## 7. Nav2 planning and control
**Costmaps.** The *global* costmap (static map + obstacle + inflation layers) and the *local* rolling-window costmap
(3 m × 3 m, odom frame) mark lethal cells and **inflate** them. Cost decays exponentially outside the inscribed radius:

$$c(d)=(c_{insc}-1)\,e^{-\alpha\,(d-r_{insc})}\quad (d\le r_{inflation}),\qquad \alpha=3.0$$

With $r_{insc}\approx0.24$ m: the **baseline** $r_{inflation}=0.55$ m pushes the robot toward the middle of free space
but makes a 1.25 m passage look expensive; the **tuned** $0.30$ m leaves more cells cheap, tightening clearance.

**Global planner (NavFn).** Searches the global costmap grid for the least-cost path:
Dijkstra $f(n)=g(n)$ (default `use_astar: false`) or A\* $f(n)=g(n)+h(n)$ with an admissible heuristic $h$ such as Euclidean distance.

**Local controller (DWB).** At 15 Hz it samples velocity pairs $(v,\omega)$ inside the *dynamic window* allowed by
acceleration limits, forward-simulates each for `sim_time = 1.7 s`, and scores trajectories with weighted critics
$J=\sum_k w_k\,C_k(\text{traj})$ (`PathAlign`, `PathDist`, `GoalAlign`, `GoalDist`, `BaseObstacle`, `RotateToGoal`,
`Oscillation`). The lowest-cost admissible trajectory's first command is sent to the robot.

**Behavior tree + recoveries.** `bt_navigator` runs `NavigateToPose`: compute path → follow path, replanning
periodically; on failure it clears costmaps, spins, backs up and waits (recoveries are counted in the logs).
`velocity_smoother` and `collision_monitor` sit between the controller and `/cmd_vel`.

## 8. Hypothesis for the experiment
*Reducing `inflation_radius` from 0.55 m to 0.30 m shortens paths / time through the narrow passage and doors without
a significant rise in near-collision events.* Competing risk: less clearance ⇒ more near-collisions or oscillation.
Report the evidence either way — a null or negative result is a valid, honest finding.

## 9. Limitations to discuss
Simulation-only (no real sensor noise/slip), small trial counts (no statistics), LiDAR range is only a proxy for
contact, static environment, a single robot, one tuned parameter.
__CMB_EOF__
mkdir -p "docs"
cat > "docs/02_STEP_BY_STEP_WORKFLOW_GUIDE.md" <<'__CMB_EOF__'
# 02 — Step-by-Step Workflow Guide (Ubuntu 24.04 in VirtualBox)

Beginner-friendly. Copy the commands exactly. **T1, T2, T3** = terminal windows (`Ctrl+Alt+T`, or new tabs with `Ctrl+Shift+T`).

## 0. VirtualBox settings (VM powered off)
| Setting | Value |
|---|---|
| System → Processor | 2 CPUs (what we target) |
| System → Base memory | 6–8 GB if the host allows (min 4 GB) |
| Display → Video memory | 128 MB, controller **VMSVGA**, *3D acceleration ON* (OFF also works with software GL) |
| Storage | ≥ 40 GB, install **Guest Additions** (Devices → Insert Guest Additions CD) |
| Network | NAT (for apt) |

Close browsers/IDEs while simulating. Gazebo has **no GUI** here (headless) — RViz2 is your window into the world.

## 1. Workspace setup (once)
```bash
sudo apt update && sudo apt install -y git
git clone <YOUR_GITHUB_URL>/campus_mail_bot.git ~/campus_mail_bot    # or copy/unzip the folder to ~/campus_mail_bot
cd ~/campus_mail_bot
chmod +x setup.sh scripts/*.sh tools/*.py
./setup.sh              # 10–30 min; installs ROS 2 Jazzy, Gazebo Harmonic, Nav2, SLAM Toolbox; builds
```
Open a **new** terminal and use this prefix in *every* terminal from now on:
```bash
cd ~/campus_mail_bot && source /opt/ros/jazzy/setup.bash && source install/setup.bash
```
Sanity check: `ros2 pkg list | grep campus_mail_bot` and `gz sim --versions` (should show 8.x).

## 2. Phase 1 — slow-scan manual mapping
**T1** — simulation + SLAM + RViz:
```bash
ros2 launch campus_mail_bot mapping.launch.py
```
Wait 30–60 s. RViz shows `/scan` (red points), TF frames and an (initially tiny) map.
Check in **T2**: `ros2 topic hz /scan` (≈10 Hz) and `ros2 run tf2_ros tf2_echo map base_link` (a transform prints).

**T2** — teleoperation:
```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```
Keys: `i` forward · `,` backward · `j`/`l` rotate left/right · `k` stop · `z` decrease speeds (press 3–4×, aim for
≈0.1–0.15 m/s and ≈0.3–0.5 rad/s). Mapping route: Reception → along the corridor → into **each** office (A, B, C)
and back → pass the passage past the reception partition → drive a full loop so SLAM can close the loop → stop.
Tips: rotate slowly, never spin fast near walls, pause 2 s at doors, cover all walls from ≥ 2 viewpoints.

**T3** — save the map when RViz shows closed walls and door gaps:
```bash
cd ~/campus_mail_bot && ./scripts/save_map.sh
# equivalent to: ros2 run nav2_map_server map_saver_cli -f src/campus_mail_bot/maps/campus_map --free 0.196 --occ 0.65
```
Expected output: `Map saved successfully`. Files: `src/campus_mail_bot/maps/campus_map.yaml` and `.pgm`.
Open the PGM (`eog src/campus_mail_bot/maps/campus_map.pgm`) and confirm: walls black, free space white, no
doubled/ghost walls. If bad → `Ctrl+C` in T1, relaunch and map again more slowly.
Screenshot RViz (map + scan + TF) for the report → `docs/evidence/`.
Stop T1 and T2 with `Ctrl+C`.

> The repo already contains a generated starter `campus_map`. Saving overwrites it with *your* SLAM map.
> Commit it: `git add -A && git commit -m "Add SLAM map"`.

## 3. Phase 2 — localize and deliver (restart = proves "map then relocalize")
**T1** (baseline configuration):
```bash
ros2 launch campus_mail_bot delivery.launch.py params_file:=nav2_baseline.yaml
```
Wait until RViz shows the map, green AMCL particles around the robot and no red errors (~60 s in a 2-core VM).
If particles are not around the robot: RViz tool **2D Pose Estimate**, click the robot and drag along +x.
Optional smoke test: RViz **Nav2 Goal** tool → click inside Office A; the robot must drive there.

**T2** — one automated trial:
```bash
ros2 run campus_mail_bot mission_runner --route default --trial 1 --tag baseline
```
The node waits for Nav2, drives to Reception if needed (unscored), then visits A → B → C and prints
`[goal i/3] office_x: SUCCEEDED ...` and a final `RESULT` line; one row is appended to `results/trials_results.csv`.

## 4. The benchmark: ≥ 5 required trials (we recommend 8)
Routes: `default` = Reception → A → B → C; `alt` = Reception → C → A → B.
Configurations: `nav2_baseline.yaml` (inflation 0.55, tag `baseline`) vs `nav2_tuned.yaml` (inflation 0.30, tag `tuned_inflation`).
Switching configuration = `Ctrl+C` in T1 and relaunch with the other file (≈1 min).

| Trial | T1 (restart only when config changes) | T2 command |
|---|---|---|
| 1 | `delivery.launch.py params_file:=nav2_baseline.yaml` | `... --route default --trial 1 --tag baseline` |
| 2 | (same, still running) | `... --route alt --trial 2 --tag baseline` |
| 3 | (same) | `... --route default --trial 3 --tag baseline` |
| 4 | (same) | `... --route alt --trial 4 --tag baseline` |
| 5 | **restart** with `params_file:=nav2_tuned.yaml` | `... --route default --trial 5 --tag tuned_inflation` |
| 6 | (same) | `... --route alt --trial 6 --tag tuned_inflation` |
| 7 | (same) | `... --route default --trial 7 --tag tuned_inflation` |
| 8 | (same) | `... --route alt --trial 8 --tag tuned_inflation` |

where `...` = `ros2 run campus_mail_bot mission_runner`. Rules for a fair comparison: same map, same VM load (no
other apps), same start pose (the node resets to Reception), don't touch the robot during a trial, record any
anomaly (crash, stuck, restart) in your notes — don't silently discard failed trials.
Then: `python3 tools/summarize_results.py > results/summary.md` and paste into the report.
Per-goal details (recoveries, near-collisions) are in `results/trials_details.csv`.

## 5. Export the TF tree and system evidence (while Phase 2 runs)
```bash
cd ~/campus_mail_bot && ./scripts/export_tf_tree.sh
```
Creates `docs/evidence/frames_*.pdf` (TF tree: `map → odom → base_link → lidar_link`), `evidence.txt` (topic rates,
`/scan` header showing `frame_id: lidar_link`, TF lookup). Add RViz screenshots: LaserScan, TF, costmaps, global
(red) and local (blue) paths, particle cloud.

## 6. Recording the 6–8 minute demo video
1. Enable long recordings (GNOME default stops at 30 s): `gsettings set org.gnome.settings-daemon.plugins.media-keys max-screencast-length 0`
2. Start/stop the built-in recorder with `Ctrl+Alt+Shift+R` (red dot appears). Alternatives: OBS Studio or SimpleScreenRecorder (`sudo apt install simplescreenrecorder`).
3. Script (≈7 min): ① 30 s intro & team ② 60 s clean start: `ros2 launch ... mapping.launch.py` ③ 90 s mapping (speed up
   in editing) and `save_map.sh` ④ 45 s restart with `delivery.launch.py`, show particles/TF ⑤ 120 s full mission,
   narrate A→B→C, show global/local paths ⑥ 60 s results table/plots and the baseline vs tuned conclusion ⑦ 15 s limitations.
4. Video is saved in `~/Videos`. Check the accepted format/size limit in Moodle; compress if needed:
   `ffmpeg -i in.webm -vcodec libx264 -crf 28 demo.mp4` (`sudo apt install ffmpeg`).
5. Rehearse once; every member should speak about their part (individual contribution is graded).

## 7. Troubleshooting (VirtualBox / TF / Nav2)
| Symptom | Likely cause → fix |
|---|---|
| RViz black / crashes | `export LIBGL_ALWAYS_SOFTWARE=1` (launch files already set it); lower RViz displays: untick *Global/Local Costmap* |
| Whole VM freezes, fans spin | CPU saturated: close other apps; wait 60 s; keep Gazebo headless (default); reduce RViz frame rate |
| `gz sim` exits / EGL / "unable to create" | add `headless_rendering:=true` to the launch; else regenerate the world with the `ogre` engine: `python3 tools/generate_world_and_map.py --render-engine ogre --skip-map && colcon build --symlink-install` |
| No `/scan` | `gz topic -l \| grep scan`; if absent the sensors system failed (see above). If present but not in ROS: check `ros2 topic list`, bridge terminal output |
| `Message Filter dropping message: frame 'lidar_link'` | the static TF node is missing: `ros2 node list \| grep base_to_lidar`; run `ros2 run tf2_tools view_frames` |
| `Could not find transform map->odom` / "map frame does not exist" | SLAM/AMCL not active yet (wait), or `/clock` not publishing: `ros2 topic echo /clock --once` |
| TF "extrapolation into the future/past" | some node lacks `use_sim_time` — all provided nodes have it; for your own: `--ros-args -p use_sim_time:=true` |
| Nav2 never becomes active | VM too slow: wait ≥ 90 s; check `ros2 lifecycle get /bt_navigator` = `active`; read T1 for `Timed out waiting for transform` |
| Robot spawns but drifts/does not move | `ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.1}}"` → if it moves, the issue is in Nav2; if not, the bridge |
| AMCL particles far from robot | RViz *2D Pose Estimate* on the robot; make sure the saved map is the one used (`[delivery.launch] map = ...`) |
| Goals fail/abort in the narrow passage | expected for some baseline trials — that's data! Check costmaps in RViz; see `Recoveries` in `trials_details.csv` |
| Stale processes after Ctrl+C | `pkill -f "gz sim"; pkill -f ros2; pkill -f rviz2`; `ros2 daemon stop && ros2 daemon start` |
| Colcon build errors | `rm -rf build install log && colcon build --symlink-install` |

## 8. Final checklist
- [ ] `results/trials_results.csv` has ≥ 5 rows (both routes, both tags) · [ ] `docs/evidence/` has TF tree + screenshots
- [ ] SLAM map committed · [ ] report (5–6 pages, Word, single column) filled from `03_*` · [ ] demo video 6–8 min
- [ ] README commands tested on a clean VM · [ ] contribution statements & reflections · [ ] references + AI-assistance disclosure
__CMB_EOF__
mkdir -p "docs"
cat > "docs/03_IEEE_TECHNICAL_REPORT_TEMPLATE.md" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "docs"
cat > "docs/04_SOURCES_AND_REFERENCES.md" <<'__CMB_EOF__'
# 04 — Sources and References (IEEE style)

> **Before submitting:** open each link/DOI once, confirm volume/pages/years, and number the entries in your report
> **in order of first citation** (the order below is thematic, not citation order). Only list what you actually cited.
> Also cite any external code and permitted AI assistance used (see the last section).

## A. Official documentation and software
1. Open Robotics, "ROS 2 Jazzy Jalisco Documentation," 2024. [Online]. Available: https://docs.ros.org/en/jazzy/
2. Open Robotics, "Gazebo Harmonic Documentation," 2023. [Online]. Available: https://gazebosim.org/docs/harmonic/
3. Open Robotics, "ROS 2 Integration (ros_gz) for Gazebo Harmonic." [Online]. Available: https://gazebosim.org/docs/harmonic/ros2_integration/
4. Open Navigation LLC, "Nav2 Documentation (Jazzy)." [Online]. Available: https://docs.nav2.org/
5. Open Navigation LLC, "Nav2 Configuration Guide." [Online]. Available: https://docs.nav2.org/configuration/index.html
6. Open Navigation LLC, "Nav2 Simple Commander API." [Online]. Available: https://docs.nav2.org/commander_api/index.html
7. S. Macenski, "SLAM Toolbox," GitHub repository. [Online]. Available: https://github.com/SteveMacenski/slam_toolbox
8. ros-navigation, "Navigation2," GitHub repository. [Online]. Available: https://github.com/ros-navigation/navigation2
9. gazebosim, "ros_gz," GitHub repository. [Online]. Available: https://github.com/gazebosim/ros_gz

## B. Nav2, SLAM Toolbox and ROS 2 papers
10. S. Macenski, F. Martín, R. White, and J. Ginés Clavero, "The Marathon 2: A Navigation System," in *Proc. IEEE/RSJ Int. Conf. Intelligent Robots and Systems (IROS)*, 2020.
11. S. Macenski, T. Moore, D. V. Lu, A. Merzlyakov, and M. Ferguson, "From the desks of ROS maintainers: A survey of modern & capable mobile robotics algorithms in the Robot Operating System 2," *Robotics and Autonomous Systems*, vol. 168, 2023.
12. S. Macenski and I. Jambrecic, "SLAM Toolbox: SLAM for the dynamic world," *Journal of Open Source Software*, vol. 6, no. 61, p. 2783, 2021.
13. S. Macenski, T. Foote, B. Gerkey, C. Lalancette, and W. Woodall, "Robot Operating System 2: Design, architecture, and uses in the wild," *Science Robotics*, vol. 7, no. 66, 2022.
14. N. Koenig and A. Howard, "Design and use paradigms for Gazebo, an open-source multi-robot simulator," in *Proc. IEEE/RSJ IROS*, 2004.

## C. Localization (AMCL / Monte Carlo)
15. D. Fox, W. Burgard, F. Dellaert, and S. Thrun, "Monte Carlo localization: Efficient position estimation for mobile robots," in *Proc. AAAI National Conf. Artificial Intelligence*, 1999.
16. D. Fox, "Adapting the sample size in particle filters through KLD-sampling," *Int. J. Robotics Research*, vol. 22, no. 12, 2003.
17. S. Thrun, W. Burgard, and D. Fox, *Probabilistic Robotics*. Cambridge, MA, USA: MIT Press, 2005.

## D. SLAM (pose graph, scan matching)
18. F. Lu and E. Milios, "Globally consistent range scan alignment for environment mapping," *Autonomous Robots*, vol. 4, no. 4, 1997.
19. K. Konolige, G. Grisetti, R. Kümmerle, W. Burgard, B. Limketkai, and R. Vincent, "Efficient sparse pose adjustment for 2D mapping," in *Proc. IEEE/RSJ IROS*, 2010.
20. G. Grisetti, R. Kümmerle, C. Stachniss, and W. Burgard, "A tutorial on graph-based SLAM," *IEEE Intelligent Transportation Systems Magazine*, vol. 2, no. 4, 2010.

## E. Planning and control
21. E. W. Dijkstra, "A note on two problems in connexion with graphs," *Numerische Mathematik*, vol. 1, no. 1, pp. 269–271, 1959.
22. P. E. Hart, N. J. Nilsson, and B. Raphael, "A formal basis for the heuristic determination of minimum cost paths," *IEEE Trans. Systems Science and Cybernetics*, vol. 4, no. 2, 1968.
23. D. Fox, W. Burgard, and S. Thrun, "The dynamic window approach to collision avoidance," *IEEE Robotics & Automation Magazine*, vol. 4, no. 1, 1997.

## F. Open lecture and course resources (check the current year's page)
24. MIT, "6.4200 Robotics: Science and Systems (RSS)," course website and lecture materials. [Online]. Available: https://rss.csail.mit.edu/
25. Stanford University, "CS237A Principles of Robot Autonomy I," course website and lecture materials. [Online]. Available: https://web.stanford.edu/class/cs237a/
26. University of Oxford, Mobile Robotics Group (MRG), publications and teaching resources. [Online]. Available: https://mrg.robots.ox.ac.uk/

## G. Example in-text usage
"...a graph-based SLAM front end with scan matching and loop closure [12], [19], [20]; localization uses adaptive Monte Carlo
localization [15], [16]; the local controller follows the dynamic window approach [23] as implemented in Nav2 [10], [11]."

## H. External code / AI-assistance disclosure (copy into the report's reference list and adapt)
27. ROS 2 / Nav2 / SLAM Toolbox / ros_gz packages used as-is under their open-source licenses (see A).
28. The Nav2 parameter files are derived from the official Nav2 Jazzy `nav2_params.yaml` (Apache-2.0) [8].
29. "AI assistance: an AI language model (Claude, Anthropic) was used to generate the initial repository scaffold, launch files,
    mission runner and documentation drafts, which the team reviewed, tested and modified. Accessed: Nov. 2026."
    *(Edit to describe exactly what you used and changed; follow UCAS academic-integrity rules.)*
__CMB_EOF__
mkdir -p "results"
cat > "results/.gitkeep" <<'__CMB_EOF__'

__CMB_EOF__
mkdir -p "scripts"
cat > "scripts/export_tf_tree.sh" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "scripts"
cat > "scripts/save_map.sh" <<'__CMB_EOF__'
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
__CMB_EOF__
cat > "setup.sh" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "src/campus_mail_bot/campus_mail_bot"
cat > "src/campus_mail_bot/campus_mail_bot/__init__.py" <<'__CMB_EOF__'

__CMB_EOF__
mkdir -p "src/campus_mail_bot/campus_mail_bot"
cat > "src/campus_mail_bot/campus_mail_bot/mission_runner.py" <<'__CMB_EOF__'
#!/usr/bin/env python3
"""Campus Mail Bot - automated multi-goal delivery mission + quantitative benchmark logger.

  ros2 run campus_mail_bot mission_runner --route default --trial 1 --tag baseline
  ros2 run campus_mail_bot mission_runner --route alt     --trial 2 --tag tuned_inflation

The robot (if not already at Reception) first drives back to Reception (unscored reset), then visits
every office of the chosen route through Nav2's NavigateToPose action - no manual driving.

Metrics (recorded only while the scored mission runs):
  * Distance_m          sum of sqrt(dx^2 + dy^2) over consecutive /odom samples
  * Time_sec            elapsed *simulation* time (works with use_sim_time)
  * Goals_Reached       goals whose Nav2 result was SUCCEEDED
  * Near-collisions     rising edges of "min /scan range < 0.22 m" (with 0.03 m hysteresis)
  * Min_Obstacle_Dist   smallest valid /scan range seen during the mission

Appends one row per run to results/trials_results.csv:
  Timestamp,Trial,Route,Tag,Goals_Reached,Total_Goals,Time_sec,Distance_m,Min_Obstacle_Dist,Status
and per-goal details (incl. near-collision events and recoveries) to results/trials_details.csv.
"""
import argparse
import csv
import math
import os
import sys
from datetime import datetime

import rclpy
import tf2_ros
import yaml
from ament_index_python.packages import get_package_share_directory
from geometry_msgs.msg import PoseStamped
from nav2_simple_commander.robot_navigator import BasicNavigator, TaskResult
from nav_msgs.msg import Odometry
from rclpy.utilities import remove_ros_args
from sensor_msgs.msg import LaserScan

RESULT_FIELDS = ['Timestamp', 'Trial', 'Route', 'Tag', 'Goals_Reached', 'Total_Goals',
                 'Time_sec', 'Distance_m', 'Min_Obstacle_Dist', 'Status']
DETAIL_FIELDS = ['Timestamp', 'Trial', 'Route', 'Tag', 'Goal_Index', 'Goal', 'Result',
                 'Time_sec', 'Recoveries', 'Near_Collision_Events']


def parse_args(argv):
    pkg = get_package_share_directory('campus_mail_bot')
    ap = argparse.ArgumentParser(description='Run one automated delivery trial and log metrics.')
    ap.add_argument('--route', choices=['default', 'alt'], default='default',
                    help='default: Reception->A->B->C | alt: Reception->C->A->B')
    ap.add_argument('--trial', type=int, default=1, help='trial number (for the CSV)')
    ap.add_argument('--tag', default='baseline', help='configuration tag: baseline | tuned_inflation')
    ap.add_argument('--routes-file', default=os.path.join(pkg, 'config', 'routes.yaml'))
    ap.add_argument('--results', default=os.path.join('results', 'trials_results.csv'),
                    help='CSV to append to (default ./results/trials_results.csv)')
    ap.add_argument('--goal-timeout', type=float, default=300.0, help='seconds (sim time) per goal')
    ap.add_argument('--near-threshold', type=float, default=0.22, help='near-collision range (m)')
    ap.add_argument('--no-reset', action='store_true', help='do not drive to Reception before the trial')
    ap.add_argument('--no-return', action='store_true', help='stay at the last office afterwards')
    return ap.parse_args(remove_ros_args(argv)[1:])


class MissionRunner:
    def __init__(self, args):
        self.a = args
        self.nav = BasicNavigator()
        with open(args.routes_file) as f:
            cfg = yaml.safe_load(f)
        self.start = cfg['start_world']
        self.loc = cfg['locations']
        self.route = cfg['routes'][args.route]

        self.recording = False
        self.prev_xy = None
        self.distance = 0.0
        self.min_range = float('inf')
        self.near_events = 0
        self.in_near = False

        self.nav.create_subscription(Odometry, '/odom', self._odom_cb, 10)
        self.nav.create_subscription(LaserScan, '/scan', self._scan_cb, 10)
        self.tf_buffer = tf2_ros.Buffer()
        self.tf_listener = tf2_ros.TransformListener(self.tf_buffer, self.nav)

    # ---- sensing callbacks -------------------------------------------------
    def _odom_cb(self, msg):
        if not self.recording:
            return
        xy = (msg.pose.pose.position.x, msg.pose.pose.position.y)
        if self.prev_xy is not None:
            dx, dy = xy[0] - self.prev_xy[0], xy[1] - self.prev_xy[1]
            self.distance += math.sqrt(dx * dx + dy * dy)
        self.prev_xy = xy

    def _scan_cb(self, msg):
        if not self.recording:
            return
        valid = [r for r in msg.ranges if math.isfinite(r) and r >= msg.range_min]
        if not valid:
            return
        m = min(valid)
        self.min_range = min(self.min_range, m)
        if m < self.a.near_threshold and not self.in_near:
            self.near_events += 1
            self.in_near = True
        elif m > self.a.near_threshold + 0.03:
            self.in_near = False

    # ---- helpers -------------------------------------------------------------
    def _map_pose(self, name):
        """World-frame location -> PoseStamped in the map frame (map = world - start)."""
        l = self.loc[name]
        p = PoseStamped()
        p.header.frame_id = 'map'
        p.header.stamp = self.nav.get_clock().now().to_msg()
        p.pose.position.x = float(l['x']) - float(self.start[0])
        p.pose.position.y = float(l['y']) - float(self.start[1])
        yaw = float(l.get('yaw', 0.0))
        p.pose.orientation.z = math.sin(yaw / 2.0)
        p.pose.orientation.w = math.cos(yaw / 2.0)
        return p

    def _robot_map_xy(self):
        try:
            t = self.tf_buffer.lookup_transform('map', 'base_link', rclpy.time.Time())
            return t.transform.translation.x, t.transform.translation.y
        except Exception:  # noqa: BLE001
            return None

    def _sim_seconds(self):
        return self.nav.get_clock().now().nanoseconds / 1e9

    def go(self, name):
        """Navigate to one named location. Returns (result_str, seconds, recoveries)."""
        n = self.nav
        t0 = self._sim_seconds()
        recoveries, cancelled = 0, False
        if not n.goToPose(self._map_pose(name)):
            return 'REJECTED', 0.0, 0
        while not n.isTaskComplete():
            fb = n.getFeedback()
            if fb:
                recoveries = max(recoveries, fb.number_of_recoveries)
            if self._sim_seconds() - t0 > self.a.goal_timeout and not cancelled:
                n.get_logger().warn(f'{name}: timeout ({self.a.goal_timeout:.0f}s) -> cancelling')
                n.cancelTask()
                cancelled = True
        res = n.getResult()
        dt = self._sim_seconds() - t0
        if cancelled:
            return 'TIMEOUT', dt, recoveries
        if res == TaskResult.SUCCEEDED:
            return 'SUCCEEDED', dt, recoveries
        if res == TaskResult.CANCELED:
            return 'CANCELED', dt, recoveries
        return 'FAILED', dt, recoveries

    # ---- main flow -----------------------------------------------------------
    def run(self):
        n, a, log = self.nav, self.a, self.nav.get_logger()
        log.info('Waiting for Nav2 (AMCL + bt_navigator) to become active ...')
        n.waitUntilNav2Active()

        start_name, goals = self.route[0], self.route[1:]
        if not a.no_reset:
            xy = self._robot_map_xy()
            home = self._map_pose(start_name).pose.position
            if xy is None or math.dist(xy, (home.x, home.y)) > 0.6:
                log.info(f'Reset: driving to {start_name} (unscored) ...')
                n.clearAllCostmaps()
                r, _, _ = self.go(start_name)
                log.info(f'Reset result: {r}')

        log.info(f'=== TRIAL {a.trial} | route={a.route} {self.route} | tag={a.tag} ===')
        n.clearAllCostmaps()
        self.distance, self.prev_xy, self.min_range = 0.0, None, float('inf')
        self.near_events, self.in_near = 0, False
        self.recording = True
        t_start = self._sim_seconds()

        details, reached = [], 0
        for i, g in enumerate(goals, start=1):
            near_before = self.near_events
            res, dt, rec = self.go(g)
            reached += int(res == 'SUCCEEDED')
            near = self.near_events - near_before
            log.info(f'[goal {i}/{len(goals)}] {g}: {res} | {dt:.1f}s | recoveries={rec} | near-collisions={near}')
            details.append((i, g, res, dt, rec, near))

        elapsed = self._sim_seconds() - t_start
        self.recording = False
        min_d = self.min_range if math.isfinite(self.min_range) else float('nan')
        status = 'COMPLETED' if reached == len(goals) else ('PARTIAL' if reached else 'FAILED')

        stamp = datetime.now().isoformat(timespec='seconds')
        self._append(a.results, RESULT_FIELDS,
                     [stamp, a.trial, a.route, a.tag, reached, len(goals), round(elapsed, 2),
                      round(self.distance, 3), round(min_d, 3), status])
        detail_path = os.path.join(os.path.dirname(a.results) or '.', 'trials_details.csv')
        for d in details:
            self._append(detail_path, DETAIL_FIELDS,
                         [stamp, a.trial, a.route, a.tag, d[0], d[1], d[2], round(d[3], 2), d[4], d[5]])

        log.info('-------------------------------------------------------------')
        log.info(f'RESULT trial={a.trial} route={a.route} tag={a.tag}: {reached}/{len(goals)} goals, '
                 f'{elapsed:.1f}s, {self.distance:.2f} m, min range {min_d:.2f} m, '
                 f'near-collision events={self.near_events} -> {status}')
        log.info(f'Appended to {a.results}')

        if not a.no_return:
            log.info('Returning to Reception (unscored) ...')
            self.go(start_name)

    @staticmethod
    def _append(path, fields, row):
        os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
        new = not os.path.isfile(path) or os.path.getsize(path) == 0
        with open(path, 'a', newline='') as f:
            w = csv.writer(f)
            if new:
                w.writerow(fields)
            w.writerow(row)


def main():
    args = parse_args(sys.argv)
    # Force simulation time for this node (and the BasicNavigator clock).
    rclpy.init(args=sys.argv + ['--ros-args', '-p', 'use_sim_time:=true'])
    runner = MissionRunner(args)
    try:
        runner.run()
    except KeyboardInterrupt:
        pass
    finally:
        runner.nav.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
__CMB_EOF__
mkdir -p "src/campus_mail_bot/config"
cat > "src/campus_mail_bot/config/bridge.yaml" <<'__CMB_EOF__'
# ros_gz_bridge: Gazebo Harmonic <-> ROS 2 Jazzy
- ros_topic_name: "clock"
  gz_topic_name: "clock"
  ros_type_name: "rosgraph_msgs/msg/Clock"
  gz_type_name: "gz.msgs.Clock"
  direction: GZ_TO_ROS

- ros_topic_name: "cmd_vel"
  gz_topic_name: "cmd_vel"
  ros_type_name: "geometry_msgs/msg/Twist"
  gz_type_name: "gz.msgs.Twist"
  direction: ROS_TO_GZ

- ros_topic_name: "odom"
  gz_topic_name: "odom"
  ros_type_name: "nav_msgs/msg/Odometry"
  gz_type_name: "gz.msgs.Odometry"
  direction: GZ_TO_ROS

- ros_topic_name: "tf"
  gz_topic_name: "tf"
  ros_type_name: "tf2_msgs/msg/TFMessage"
  gz_type_name: "gz.msgs.Pose_V"
  direction: GZ_TO_ROS

- ros_topic_name: "scan"
  gz_topic_name: "scan"
  ros_type_name: "sensor_msgs/msg/LaserScan"
  gz_type_name: "gz.msgs.LaserScan"
  direction: GZ_TO_ROS
__CMB_EOF__
mkdir -p "src/campus_mail_bot/config"
cat > "src/campus_mail_bot/config/nav2_baseline.yaml" <<'__CMB_EOF__'
# BASELINE: inflation_radius 0.55 m (global + local costmap)
# Derived from the official Nav2 Jazzy nav2_params.yaml by tools/make_nav2_params.py
# Changes: use_sim_time everywhere, DWB local controller, robot_radius 0.24, base_link frames,
# AMCL initial pose (0,0,0)=start pose, 1000 particles (2-core VM), 15 Hz controller, 0.26 m/s limits.
amcl:
  ros__parameters:
    use_sim_time: true
    alpha1: 0.2
    alpha2: 0.2
    alpha3: 0.2
    alpha4: 0.2
    alpha5: 0.2
    base_frame_id: "base_link"
    beam_skip_distance: 0.5
    beam_skip_error_threshold: 0.9
    beam_skip_threshold: 0.3
    do_beamskip: false
    global_frame_id: "map"
    lambda_short: 0.1
    laser_likelihood_max_dist: 2.0
    laser_max_range: 10.0
    laser_min_range: -1.0
    laser_model_type: "likelihood_field"
    max_beams: 60
    max_particles: 1000
    min_particles: 300
    odom_frame_id: "odom"
    pf_err: 0.05
    pf_z: 0.99
    recovery_alpha_fast: 0.0
    recovery_alpha_slow: 0.0
    resample_interval: 1
    robot_model_type: "nav2_amcl::DifferentialMotionModel"
    save_pose_rate: 0.5
    sigma_hit: 0.2
    tf_broadcast: true
    transform_tolerance: 1.0
    update_min_a: 0.2
    update_min_d: 0.25
    z_hit: 0.5
    z_max: 0.05
    z_rand: 0.5
    z_short: 0.05
    scan_topic: scan
    set_initial_pose: true
    always_reset_initial_pose: false
    initial_pose:
      x: 0.0
      y: 0.0
      z: 0.0
      yaw: 0.0

bt_navigator:
  ros__parameters:
    use_sim_time: true
    global_frame: map
    robot_base_frame: base_link
    odom_topic: /odom
    bt_loop_duration: 10
    default_server_timeout: 20
    wait_for_service_timeout: 1000
    action_server_result_timeout: 900.0
    navigators: ["navigate_to_pose", "navigate_through_poses"]
    navigate_to_pose:
      plugin: "nav2_bt_navigator::NavigateToPoseNavigator"
    navigate_through_poses:
      plugin: "nav2_bt_navigator::NavigateThroughPosesNavigator"
    # 'default_nav_through_poses_bt_xml' and 'default_nav_to_pose_bt_xml' are use defaults:
    # nav2_bt_navigator/navigate_to_pose_w_replanning_and_recovery.xml
    # nav2_bt_navigator/navigate_through_poses_w_replanning_and_recovery.xml
    # They can be set here or via a RewrittenYaml remap from a parent launch file to Nav2.

    # plugin_lib_names is used to add custom BT plugins to the executor (vector of strings).
    # Built-in plugins are added automatically
    # plugin_lib_names: []

    error_code_names:
      - compute_path_error_code
      - follow_path_error_code

controller_server:
  ros__parameters:
    use_sim_time: true
    controller_frequency: 15.0
    costmap_update_timeout: 0.30
    min_x_velocity_threshold: 0.001
    min_y_velocity_threshold: 0.5
    min_theta_velocity_threshold: 0.001
    failure_tolerance: 0.3
    progress_checker_plugins: ["progress_checker"]
    goal_checker_plugins: ["general_goal_checker"] # "precise_goal_checker"
    controller_plugins: ["FollowPath"]
    use_realtime_priority: false

    # Progress checker parameters
    progress_checker:
      plugin: "nav2_controller::SimpleProgressChecker"
      required_movement_radius: 0.5
      movement_time_allowance: 10.0
    # Goal checker parameters
    #precise_goal_checker:
    #  plugin: "nav2_controller::SimpleGoalChecker"
    #  xy_goal_tolerance: 0.25
    #  yaw_goal_tolerance: 0.25
    #  stateful: True
    general_goal_checker:
      stateful: True
      plugin: "nav2_controller::SimpleGoalChecker"
      xy_goal_tolerance: 0.25
      yaw_goal_tolerance: 0.25
    FollowPath:
      plugin: "dwb_core::DWBLocalPlanner"
      debug_trajectory_details: true
      min_vel_x: 0.0
      min_vel_y: 0.0
      max_vel_x: 0.26
      max_vel_y: 0.0
      max_vel_theta: 1.0
      min_speed_xy: 0.0
      max_speed_xy: 0.26
      min_speed_theta: 0.0
      acc_lim_x: 2.5
      acc_lim_y: 0.0
      acc_lim_theta: 3.2
      decel_lim_x: -2.5
      decel_lim_y: 0.0
      decel_lim_theta: -3.2
      vx_samples: 20
      vy_samples: 5
      vtheta_samples: 20
      sim_time: 1.7
      linear_granularity: 0.05
      angular_granularity: 0.025
      transform_tolerance: 0.2
      xy_goal_tolerance: 0.25
      trans_stopped_velocity: 0.25
      short_circuit_trajectory_evaluation: true
      stateful: true
      critics: ["RotateToGoal", "Oscillation", "BaseObstacle", "GoalAlign", "PathAlign", "PathDist", "GoalDist"]
      BaseObstacle.scale: 0.02
      PathAlign.scale: 32.0
      PathAlign.forward_point_distance: 0.1
      GoalAlign.scale: 24.0
      GoalAlign.forward_point_distance: 0.1
      PathDist.scale: 32.0
      GoalDist.scale: 24.0
      RotateToGoal.scale: 32.0
      RotateToGoal.slowing_factor: 5.0
      RotateToGoal.lookahead_time: -1.0

local_costmap:
  local_costmap:
    ros__parameters:
      use_sim_time: true
      update_frequency: 5.0
      publish_frequency: 2.0
      global_frame: odom
      robot_base_frame: base_link
      rolling_window: true
      width: 3
      height: 3
      resolution: 0.05
      robot_radius: 0.24
      plugins: ["voxel_layer", "inflation_layer"]
      inflation_layer:
        plugin: "nav2_costmap_2d::InflationLayer"
        cost_scaling_factor: 3.0
        inflation_radius: 0.55
      voxel_layer:
        plugin: "nav2_costmap_2d::VoxelLayer"
        enabled: True
        publish_voxel_map: True
        origin_z: 0.0
        z_resolution: 0.05
        z_voxels: 16
        max_obstacle_height: 2.0
        mark_threshold: 0
        observation_sources: scan
        scan:
          topic: /scan
          max_obstacle_height: 2.0
          clearing: True
          marking: True
          data_type: "LaserScan"
          raytrace_max_range: 3.0
          raytrace_min_range: 0.0
          obstacle_max_range: 2.5
          obstacle_min_range: 0.0
      static_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_subscribe_transient_local: True
      always_send_full_costmap: True

global_costmap:
  global_costmap:
    ros__parameters:
      use_sim_time: true
      update_frequency: 1.0
      publish_frequency: 1.0
      global_frame: map
      robot_base_frame: base_link
      robot_radius: 0.24
      resolution: 0.05
      track_unknown_space: true
      plugins: ["static_layer", "obstacle_layer", "inflation_layer"]
      obstacle_layer:
        plugin: "nav2_costmap_2d::ObstacleLayer"
        enabled: True
        observation_sources: scan
        scan:
          topic: /scan
          max_obstacle_height: 2.0
          clearing: True
          marking: True
          data_type: "LaserScan"
          raytrace_max_range: 3.0
          raytrace_min_range: 0.0
          obstacle_max_range: 2.5
          obstacle_min_range: 0.0
      static_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_subscribe_transient_local: True
      inflation_layer:
        plugin: "nav2_costmap_2d::InflationLayer"
        cost_scaling_factor: 3.0
        inflation_radius: 0.55
      always_send_full_costmap: True

# The yaml_filename does not need to be specified since it going to be set by defaults in launch.
# If you'd rather set it in the yaml, remove the default "map" value in the tb3_simulation_launch.py
# file & provide full path to map below. If CLI map configuration or launch default is provided, that will be used.
# map_server:
#   ros__parameters:
#     yaml_filename: ""

map_saver:
  ros__parameters:
    use_sim_time: true
    save_map_timeout: 5.0
    free_thresh_default: 0.25
    occupied_thresh_default: 0.65
    map_subscribe_transient_local: True

planner_server:
  ros__parameters:
    use_sim_time: true
    expected_planner_frequency: 20.0
    planner_plugins: ["GridBased"]
    costmap_update_timeout: 1.0
    GridBased:
      plugin: "nav2_navfn_planner::NavfnPlanner"
      tolerance: 0.5
      use_astar: false
      allow_unknown: true

smoother_server:
  ros__parameters:
    use_sim_time: true
    smoother_plugins: ["simple_smoother"]
    simple_smoother:
      plugin: "nav2_smoother::SimpleSmoother"
      tolerance: 1.0e-10
      max_its: 1000
      do_refinement: True

behavior_server:
  ros__parameters:
    use_sim_time: true
    local_costmap_topic: local_costmap/costmap_raw
    global_costmap_topic: global_costmap/costmap_raw
    local_footprint_topic: local_costmap/published_footprint
    global_footprint_topic: global_costmap/published_footprint
    cycle_frequency: 10.0
    behavior_plugins: ["spin", "backup", "drive_on_heading", "assisted_teleop", "wait"]
    spin:
      plugin: "nav2_behaviors::Spin"
    backup:
      plugin: "nav2_behaviors::BackUp"
    drive_on_heading:
      plugin: "nav2_behaviors::DriveOnHeading"
    wait:
      plugin: "nav2_behaviors::Wait"
    assisted_teleop:
      plugin: "nav2_behaviors::AssistedTeleop"
    local_frame: odom
    global_frame: map
    robot_base_frame: base_link
    transform_tolerance: 0.1
    simulate_ahead_time: 2.0
    max_rotational_vel: 1.0
    min_rotational_vel: 0.4
    rotational_acc_lim: 3.2

waypoint_follower:
  ros__parameters:
    use_sim_time: true
    loop_rate: 20
    stop_on_failure: false
    action_server_result_timeout: 900.0
    waypoint_task_executor_plugin: "wait_at_waypoint"
    wait_at_waypoint:
      plugin: "nav2_waypoint_follower::WaitAtWaypoint"
      enabled: True
      waypoint_pause_duration: 200

route_server:
  ros__parameters:
    use_sim_time: true
    # The graph_filepath does not need to be specified since it going to be set by defaults in launch.
    # If you'd rather set it in the yaml, remove the default "graph" value in the launch file(s).
    # file & provide full path to map below. If graph config or launch default is provided, it is used
    # graph_filepath: $(find-pkg-share nav2_route)/graphs/aws_graph.geojson
    boundary_radius_to_achieve_node: 1.0
    radius_to_achieve_node: 2.0
    smooth_corners: true
    operations: ["AdjustSpeedLimit", "ReroutingService", "CollisionMonitor"]
    ReroutingService:
      plugin: "nav2_route::ReroutingService"
    AdjustSpeedLimit:
      plugin: "nav2_route::AdjustSpeedLimit"
    CollisionMonitor:
      plugin: "nav2_route::CollisionMonitor"
      max_collision_dist: 3.0
    edge_cost_functions: ["DistanceScorer", "CostmapScorer"]
    DistanceScorer:
      plugin: "nav2_route::DistanceScorer"
    CostmapScorer:
      plugin: "nav2_route::CostmapScorer"

velocity_smoother:
  ros__parameters:
    use_sim_time: true
    smoothing_frequency: 20.0
    stamp_smoothed_velocity_with_smoothing_time: False
    scale_velocities: False
    feedback: "OPEN_LOOP"
    max_velocity: [0.26, 0.0, 1.0]
    min_velocity: [-0.26, 0.0, -1.0]
    max_accel: [2.5, 0.0, 3.2]
    max_decel: [-2.5, 0.0, -3.2]
    odom_topic: "odom"
    odom_duration: 0.1
    deadband_velocity: [0.0, 0.0, 0.0]
    velocity_timeout: 1.0

collision_monitor:
  ros__parameters:
    use_sim_time: true
    base_frame_id: "base_link"
    odom_frame_id: "odom"
    cmd_vel_in_topic: "cmd_vel_smoothed"
    cmd_vel_out_topic: "cmd_vel"
    state_topic: "collision_monitor_state"
    transform_tolerance: 0.2
    source_timeout: 1.0
    base_shift_correction: True
    stop_pub_timeout: 2.0
    # Polygons represent zone around the robot for "stop", "slowdown" and "limit" action types,
    # and robot footprint for "approach" action type.
    polygons: ["FootprintApproach"]
    FootprintApproach:
      type: "polygon"
      action_type: "approach"
      footprint_topic: "/local_costmap/published_footprint"
      time_before_collision: 1.2
      simulation_time_step: 0.1
      min_points: 6
      visualize: False
      enabled: True
    observation_sources: ["scan"]
    scan:
      type: "scan"
      topic: "scan"
      min_height: 0.15
      max_height: 2.0
      enabled: True

docking_server:
  ros__parameters:
    use_sim_time: true
    controller_frequency: 50.0
    initial_perception_timeout: 5.0
    wait_charge_timeout: 5.0
    dock_approach_timeout: 30.0
    undock_linear_tolerance: 0.05
    undock_angular_tolerance: 0.1
    max_retries: 3
    base_frame: "base_link"
    fixed_frame: "odom"
    dock_backwards: false
    dock_prestaging_tolerance: 0.5

    # Types of docks
    dock_plugins: ['simple_charging_dock']
    simple_charging_dock:
      plugin: 'opennav_docking::SimpleChargingDock'
      docking_threshold: 0.05
      staging_x_offset: -0.7
      use_external_detection_pose: true
      use_battery_status: false # true
      use_stall_detection: false # true

      external_detection_timeout: 1.0
      external_detection_translation_x: -0.18
      external_detection_translation_y: 0.0
      external_detection_rotation_roll: -1.57
      external_detection_rotation_pitch: -1.57
      external_detection_rotation_yaw: 0.0
      filter_coef: 0.1

    # Dock instances
    # The following example illustrates configuring dock instances.
    # docks: ['home_dock']  # Input your docks here
    # home_dock:
    #   type: 'simple_charging_dock'
    #   frame: map
    #   pose: [0.0, 0.0, 0.0]

    controller:
      k_phi: 3.0
      k_delta: 2.0
      v_linear_min: 0.15
      v_linear_max: 0.15
      use_collision_detection: true
      costmap_topic: "local_costmap/costmap_raw"
      footprint_topic: "local_costmap/published_footprint"
      transform_tolerance: 0.1
      projection_time: 5.0
      simulation_step: 0.1
      dock_collision_threshold: 0.3
__CMB_EOF__
mkdir -p "src/campus_mail_bot/config"
cat > "src/campus_mail_bot/config/nav2_tuned.yaml" <<'__CMB_EOF__'
# TUNED: inflation_radius 0.30 m (global + local costmap) - the ONLY difference from baseline
# Derived from the official Nav2 Jazzy nav2_params.yaml by tools/make_nav2_params.py
# Changes: use_sim_time everywhere, DWB local controller, robot_radius 0.24, base_link frames,
# AMCL initial pose (0,0,0)=start pose, 1000 particles (2-core VM), 15 Hz controller, 0.26 m/s limits.
amcl:
  ros__parameters:
    use_sim_time: true
    alpha1: 0.2
    alpha2: 0.2
    alpha3: 0.2
    alpha4: 0.2
    alpha5: 0.2
    base_frame_id: "base_link"
    beam_skip_distance: 0.5
    beam_skip_error_threshold: 0.9
    beam_skip_threshold: 0.3
    do_beamskip: false
    global_frame_id: "map"
    lambda_short: 0.1
    laser_likelihood_max_dist: 2.0
    laser_max_range: 10.0
    laser_min_range: -1.0
    laser_model_type: "likelihood_field"
    max_beams: 60
    max_particles: 1000
    min_particles: 300
    odom_frame_id: "odom"
    pf_err: 0.05
    pf_z: 0.99
    recovery_alpha_fast: 0.0
    recovery_alpha_slow: 0.0
    resample_interval: 1
    robot_model_type: "nav2_amcl::DifferentialMotionModel"
    save_pose_rate: 0.5
    sigma_hit: 0.2
    tf_broadcast: true
    transform_tolerance: 1.0
    update_min_a: 0.2
    update_min_d: 0.25
    z_hit: 0.5
    z_max: 0.05
    z_rand: 0.5
    z_short: 0.05
    scan_topic: scan
    set_initial_pose: true
    always_reset_initial_pose: false
    initial_pose:
      x: 0.0
      y: 0.0
      z: 0.0
      yaw: 0.0

bt_navigator:
  ros__parameters:
    use_sim_time: true
    global_frame: map
    robot_base_frame: base_link
    odom_topic: /odom
    bt_loop_duration: 10
    default_server_timeout: 20
    wait_for_service_timeout: 1000
    action_server_result_timeout: 900.0
    navigators: ["navigate_to_pose", "navigate_through_poses"]
    navigate_to_pose:
      plugin: "nav2_bt_navigator::NavigateToPoseNavigator"
    navigate_through_poses:
      plugin: "nav2_bt_navigator::NavigateThroughPosesNavigator"
    # 'default_nav_through_poses_bt_xml' and 'default_nav_to_pose_bt_xml' are use defaults:
    # nav2_bt_navigator/navigate_to_pose_w_replanning_and_recovery.xml
    # nav2_bt_navigator/navigate_through_poses_w_replanning_and_recovery.xml
    # They can be set here or via a RewrittenYaml remap from a parent launch file to Nav2.

    # plugin_lib_names is used to add custom BT plugins to the executor (vector of strings).
    # Built-in plugins are added automatically
    # plugin_lib_names: []

    error_code_names:
      - compute_path_error_code
      - follow_path_error_code

controller_server:
  ros__parameters:
    use_sim_time: true
    controller_frequency: 15.0
    costmap_update_timeout: 0.30
    min_x_velocity_threshold: 0.001
    min_y_velocity_threshold: 0.5
    min_theta_velocity_threshold: 0.001
    failure_tolerance: 0.3
    progress_checker_plugins: ["progress_checker"]
    goal_checker_plugins: ["general_goal_checker"] # "precise_goal_checker"
    controller_plugins: ["FollowPath"]
    use_realtime_priority: false

    # Progress checker parameters
    progress_checker:
      plugin: "nav2_controller::SimpleProgressChecker"
      required_movement_radius: 0.5
      movement_time_allowance: 10.0
    # Goal checker parameters
    #precise_goal_checker:
    #  plugin: "nav2_controller::SimpleGoalChecker"
    #  xy_goal_tolerance: 0.25
    #  yaw_goal_tolerance: 0.25
    #  stateful: True
    general_goal_checker:
      stateful: True
      plugin: "nav2_controller::SimpleGoalChecker"
      xy_goal_tolerance: 0.25
      yaw_goal_tolerance: 0.25
    FollowPath:
      plugin: "dwb_core::DWBLocalPlanner"
      debug_trajectory_details: true
      min_vel_x: 0.0
      min_vel_y: 0.0
      max_vel_x: 0.26
      max_vel_y: 0.0
      max_vel_theta: 1.0
      min_speed_xy: 0.0
      max_speed_xy: 0.26
      min_speed_theta: 0.0
      acc_lim_x: 2.5
      acc_lim_y: 0.0
      acc_lim_theta: 3.2
      decel_lim_x: -2.5
      decel_lim_y: 0.0
      decel_lim_theta: -3.2
      vx_samples: 20
      vy_samples: 5
      vtheta_samples: 20
      sim_time: 1.7
      linear_granularity: 0.05
      angular_granularity: 0.025
      transform_tolerance: 0.2
      xy_goal_tolerance: 0.25
      trans_stopped_velocity: 0.25
      short_circuit_trajectory_evaluation: true
      stateful: true
      critics: ["RotateToGoal", "Oscillation", "BaseObstacle", "GoalAlign", "PathAlign", "PathDist", "GoalDist"]
      BaseObstacle.scale: 0.02
      PathAlign.scale: 32.0
      PathAlign.forward_point_distance: 0.1
      GoalAlign.scale: 24.0
      GoalAlign.forward_point_distance: 0.1
      PathDist.scale: 32.0
      GoalDist.scale: 24.0
      RotateToGoal.scale: 32.0
      RotateToGoal.slowing_factor: 5.0
      RotateToGoal.lookahead_time: -1.0

local_costmap:
  local_costmap:
    ros__parameters:
      use_sim_time: true
      update_frequency: 5.0
      publish_frequency: 2.0
      global_frame: odom
      robot_base_frame: base_link
      rolling_window: true
      width: 3
      height: 3
      resolution: 0.05
      robot_radius: 0.24
      plugins: ["voxel_layer", "inflation_layer"]
      inflation_layer:
        plugin: "nav2_costmap_2d::InflationLayer"
        cost_scaling_factor: 3.0
        inflation_radius: 0.30
      voxel_layer:
        plugin: "nav2_costmap_2d::VoxelLayer"
        enabled: True
        publish_voxel_map: True
        origin_z: 0.0
        z_resolution: 0.05
        z_voxels: 16
        max_obstacle_height: 2.0
        mark_threshold: 0
        observation_sources: scan
        scan:
          topic: /scan
          max_obstacle_height: 2.0
          clearing: True
          marking: True
          data_type: "LaserScan"
          raytrace_max_range: 3.0
          raytrace_min_range: 0.0
          obstacle_max_range: 2.5
          obstacle_min_range: 0.0
      static_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_subscribe_transient_local: True
      always_send_full_costmap: True

global_costmap:
  global_costmap:
    ros__parameters:
      use_sim_time: true
      update_frequency: 1.0
      publish_frequency: 1.0
      global_frame: map
      robot_base_frame: base_link
      robot_radius: 0.24
      resolution: 0.05
      track_unknown_space: true
      plugins: ["static_layer", "obstacle_layer", "inflation_layer"]
      obstacle_layer:
        plugin: "nav2_costmap_2d::ObstacleLayer"
        enabled: True
        observation_sources: scan
        scan:
          topic: /scan
          max_obstacle_height: 2.0
          clearing: True
          marking: True
          data_type: "LaserScan"
          raytrace_max_range: 3.0
          raytrace_min_range: 0.0
          obstacle_max_range: 2.5
          obstacle_min_range: 0.0
      static_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_subscribe_transient_local: True
      inflation_layer:
        plugin: "nav2_costmap_2d::InflationLayer"
        cost_scaling_factor: 3.0
        inflation_radius: 0.30
      always_send_full_costmap: True

# The yaml_filename does not need to be specified since it going to be set by defaults in launch.
# If you'd rather set it in the yaml, remove the default "map" value in the tb3_simulation_launch.py
# file & provide full path to map below. If CLI map configuration or launch default is provided, that will be used.
# map_server:
#   ros__parameters:
#     yaml_filename: ""

map_saver:
  ros__parameters:
    use_sim_time: true
    save_map_timeout: 5.0
    free_thresh_default: 0.25
    occupied_thresh_default: 0.65
    map_subscribe_transient_local: True

planner_server:
  ros__parameters:
    use_sim_time: true
    expected_planner_frequency: 20.0
    planner_plugins: ["GridBased"]
    costmap_update_timeout: 1.0
    GridBased:
      plugin: "nav2_navfn_planner::NavfnPlanner"
      tolerance: 0.5
      use_astar: false
      allow_unknown: true

smoother_server:
  ros__parameters:
    use_sim_time: true
    smoother_plugins: ["simple_smoother"]
    simple_smoother:
      plugin: "nav2_smoother::SimpleSmoother"
      tolerance: 1.0e-10
      max_its: 1000
      do_refinement: True

behavior_server:
  ros__parameters:
    use_sim_time: true
    local_costmap_topic: local_costmap/costmap_raw
    global_costmap_topic: global_costmap/costmap_raw
    local_footprint_topic: local_costmap/published_footprint
    global_footprint_topic: global_costmap/published_footprint
    cycle_frequency: 10.0
    behavior_plugins: ["spin", "backup", "drive_on_heading", "assisted_teleop", "wait"]
    spin:
      plugin: "nav2_behaviors::Spin"
    backup:
      plugin: "nav2_behaviors::BackUp"
    drive_on_heading:
      plugin: "nav2_behaviors::DriveOnHeading"
    wait:
      plugin: "nav2_behaviors::Wait"
    assisted_teleop:
      plugin: "nav2_behaviors::AssistedTeleop"
    local_frame: odom
    global_frame: map
    robot_base_frame: base_link
    transform_tolerance: 0.1
    simulate_ahead_time: 2.0
    max_rotational_vel: 1.0
    min_rotational_vel: 0.4
    rotational_acc_lim: 3.2

waypoint_follower:
  ros__parameters:
    use_sim_time: true
    loop_rate: 20
    stop_on_failure: false
    action_server_result_timeout: 900.0
    waypoint_task_executor_plugin: "wait_at_waypoint"
    wait_at_waypoint:
      plugin: "nav2_waypoint_follower::WaitAtWaypoint"
      enabled: True
      waypoint_pause_duration: 200

route_server:
  ros__parameters:
    use_sim_time: true
    # The graph_filepath does not need to be specified since it going to be set by defaults in launch.
    # If you'd rather set it in the yaml, remove the default "graph" value in the launch file(s).
    # file & provide full path to map below. If graph config or launch default is provided, it is used
    # graph_filepath: $(find-pkg-share nav2_route)/graphs/aws_graph.geojson
    boundary_radius_to_achieve_node: 1.0
    radius_to_achieve_node: 2.0
    smooth_corners: true
    operations: ["AdjustSpeedLimit", "ReroutingService", "CollisionMonitor"]
    ReroutingService:
      plugin: "nav2_route::ReroutingService"
    AdjustSpeedLimit:
      plugin: "nav2_route::AdjustSpeedLimit"
    CollisionMonitor:
      plugin: "nav2_route::CollisionMonitor"
      max_collision_dist: 3.0
    edge_cost_functions: ["DistanceScorer", "CostmapScorer"]
    DistanceScorer:
      plugin: "nav2_route::DistanceScorer"
    CostmapScorer:
      plugin: "nav2_route::CostmapScorer"

velocity_smoother:
  ros__parameters:
    use_sim_time: true
    smoothing_frequency: 20.0
    stamp_smoothed_velocity_with_smoothing_time: False
    scale_velocities: False
    feedback: "OPEN_LOOP"
    max_velocity: [0.26, 0.0, 1.0]
    min_velocity: [-0.26, 0.0, -1.0]
    max_accel: [2.5, 0.0, 3.2]
    max_decel: [-2.5, 0.0, -3.2]
    odom_topic: "odom"
    odom_duration: 0.1
    deadband_velocity: [0.0, 0.0, 0.0]
    velocity_timeout: 1.0

collision_monitor:
  ros__parameters:
    use_sim_time: true
    base_frame_id: "base_link"
    odom_frame_id: "odom"
    cmd_vel_in_topic: "cmd_vel_smoothed"
    cmd_vel_out_topic: "cmd_vel"
    state_topic: "collision_monitor_state"
    transform_tolerance: 0.2
    source_timeout: 1.0
    base_shift_correction: True
    stop_pub_timeout: 2.0
    # Polygons represent zone around the robot for "stop", "slowdown" and "limit" action types,
    # and robot footprint for "approach" action type.
    polygons: ["FootprintApproach"]
    FootprintApproach:
      type: "polygon"
      action_type: "approach"
      footprint_topic: "/local_costmap/published_footprint"
      time_before_collision: 1.2
      simulation_time_step: 0.1
      min_points: 6
      visualize: False
      enabled: True
    observation_sources: ["scan"]
    scan:
      type: "scan"
      topic: "scan"
      min_height: 0.15
      max_height: 2.0
      enabled: True

docking_server:
  ros__parameters:
    use_sim_time: true
    controller_frequency: 50.0
    initial_perception_timeout: 5.0
    wait_charge_timeout: 5.0
    dock_approach_timeout: 30.0
    undock_linear_tolerance: 0.05
    undock_angular_tolerance: 0.1
    max_retries: 3
    base_frame: "base_link"
    fixed_frame: "odom"
    dock_backwards: false
    dock_prestaging_tolerance: 0.5

    # Types of docks
    dock_plugins: ['simple_charging_dock']
    simple_charging_dock:
      plugin: 'opennav_docking::SimpleChargingDock'
      docking_threshold: 0.05
      staging_x_offset: -0.7
      use_external_detection_pose: true
      use_battery_status: false # true
      use_stall_detection: false # true

      external_detection_timeout: 1.0
      external_detection_translation_x: -0.18
      external_detection_translation_y: 0.0
      external_detection_rotation_roll: -1.57
      external_detection_rotation_pitch: -1.57
      external_detection_rotation_yaw: 0.0
      filter_coef: 0.1

    # Dock instances
    # The following example illustrates configuring dock instances.
    # docks: ['home_dock']  # Input your docks here
    # home_dock:
    #   type: 'simple_charging_dock'
    #   frame: map
    #   pose: [0.0, 0.0, 0.0]

    controller:
      k_phi: 3.0
      k_delta: 2.0
      v_linear_min: 0.15
      v_linear_max: 0.15
      use_collision_detection: true
      costmap_topic: "local_costmap/costmap_raw"
      footprint_topic: "local_costmap/published_footprint"
      transform_tolerance: 0.1
      projection_time: 5.0
      simulation_step: 0.1
      dock_collision_threshold: 0.3
__CMB_EOF__
mkdir -p "src/campus_mail_bot/config"
cat > "src/campus_mail_bot/config/routes.yaml" <<'__CMB_EOF__'
# Delivery routes. Coordinates are WORLD-frame metres (as in worlds/campus_offices.sdf).
# mission_runner converts them to the map frame:  map = world - start_world
# (SLAM Toolbox and the starter map both put the map origin at the robot start pose).
start_world: [-3.5, -2.5]

locations:            # x, y (world), yaw (rad, 0 = +x, 1.5708 = +y / facing into the office)
  reception: {x: -3.5, y: -2.5, yaw: 0.0}
  office_a:  {x: -3.0, y:  2.5, yaw: 1.5708}
  office_b:  {x:  0.0, y:  2.5, yaw: 1.5708}
  office_c:  {x:  3.0, y:  2.5, yaw: 1.5708}

routes:               # the first waypoint is the start (not scored); the rest are scored goals
  default: [reception, office_a, office_b, office_c]
  alt:     [reception, office_c, office_a, office_b]
__CMB_EOF__
mkdir -p "src/campus_mail_bot/config"
cat > "src/campus_mail_bot/config/slam_params.yaml" <<'__CMB_EOF__'
# SLAM Toolbox - online asynchronous mapping, tuned for a 2-core VM.
slam_toolbox:
  ros__parameters:
    use_sim_time: true

    solver_plugin: solver_plugins::CeresSolver
    ceres_linear_solver: SPARSE_NORMAL_CHOLESKY
    ceres_preconditioner: SCHUR_JACOBI
    ceres_trust_strategy: LEVENBERG_MARQUARDT
    ceres_dogleg_type: TRADITIONAL_DOGLEG
    ceres_loss_function: None

    odom_frame: odom
    map_frame: map
    base_frame: base_link
    scan_topic: /scan
    use_map_saver: true
    mode: mapping

    debug_logging: false
    throttle_scans: 1
    transform_publish_period: 0.02
    map_update_interval: 3.0
    resolution: 0.05
    min_laser_range: 0.0
    max_laser_range: 9.5
    minimum_time_interval: 0.5
    transform_timeout: 0.5
    tf_buffer_duration: 30.0
    stack_size_to_use: 40000000
    enable_interactive_mode: false

    use_scan_matching: true
    use_scan_barycenter: true
    minimum_travel_distance: 0.2
    minimum_travel_heading: 0.2
    scan_buffer_size: 10
    scan_buffer_maximum_scan_distance: 10.0
    link_match_minimum_response_fine: 0.1
    link_scan_maximum_distance: 1.5
    loop_search_maximum_distance: 3.0
    do_loop_closing: true
    loop_match_minimum_chain_size: 10
    loop_match_maximum_variance_coarse: 3.0
    loop_match_minimum_response_coarse: 0.35
    loop_match_minimum_response_fine: 0.45

    correlation_search_space_dimension: 0.5
    correlation_search_space_resolution: 0.01
    correlation_search_space_smear_deviation: 0.1
    loop_search_space_dimension: 8.0
    loop_search_space_resolution: 0.05
    loop_search_space_smear_deviation: 0.03

    distance_variance_penalty: 0.5
    angle_variance_penalty: 1.0
    fine_search_angle_offset: 0.00349
    coarse_search_angle_offset: 0.349
    coarse_angle_resolution: 0.0349
    minimum_angle_penalty: 0.9
    minimum_distance_penalty: 0.5
    use_response_expansion: true
__CMB_EOF__
mkdir -p "src/campus_mail_bot/launch"
cat > "src/campus_mail_bot/launch/delivery.launch.py" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "src/campus_mail_bot/launch"
cat > "src/campus_mail_bot/launch/mapping.launch.py" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "src/campus_mail_bot/launch"
cat > "src/campus_mail_bot/launch/sim_common.launch.py" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "src/campus_mail_bot/maps"
cat > "src/campus_mail_bot/maps/campus_map.yaml" <<'__CMB_EOF__'
image: campus_map.pgm
mode: trinary
resolution: 0.05
origin: [-2.00, -2.00, 0.0]
negate: 0
occupied_thresh: 0.65
free_thresh: 0.196
__CMB_EOF__
mkdir -p "src/campus_mail_bot"
cat > "src/campus_mail_bot/package.xml" <<'__CMB_EOF__'
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>campus_mail_bot</name>
  <version>1.0.0</version>
  <description>Campus Mail Bot: autonomous indoor office delivery robot (DSAI 4304). ROS 2 Jazzy, Gazebo Harmonic, SLAM Toolbox, Nav2.</description>
  <maintainer email="campusmailbot@example.com">Campus Mail Bot Team</maintainer>
  <license>Apache-2.0</license>

  <exec_depend>rclpy</exec_depend>
  <exec_depend>geometry_msgs</exec_depend>
  <exec_depend>nav_msgs</exec_depend>
  <exec_depend>sensor_msgs</exec_depend>
  <exec_depend>tf2_ros_py</exec_depend>
  <exec_depend>python3-yaml</exec_depend>
  <exec_depend>nav2_simple_commander</exec_depend>
  <exec_depend>nav2_bringup</exec_depend>
  <exec_depend>nav2_map_server</exec_depend>
  <exec_depend>slam_toolbox</exec_depend>
  <exec_depend>ros_gz_sim</exec_depend>
  <exec_depend>ros_gz_bridge</exec_depend>
  <exec_depend>tf2_ros</exec_depend>
  <exec_depend>rviz2</exec_depend>
  <exec_depend>teleop_twist_keyboard</exec_depend>

  <export>
    <build_type>ament_python</build_type>
  </export>
</package>
__CMB_EOF__
mkdir -p "src/campus_mail_bot/resource"
cat > "src/campus_mail_bot/resource/campus_mail_bot" <<'__CMB_EOF__'

__CMB_EOF__
mkdir -p "src/campus_mail_bot/rviz"
cat > "src/campus_mail_bot/rviz/mapping.rviz" <<'__CMB_EOF__'
Panels:
  - Class: rviz_common/Displays
    Name: Displays
    Property Tree Widget:
      Expanded:
        - /Global Options1
      Splitter Ratio: 0.5
    Tree Height: 400
  - Class: rviz_common/Views
    Name: Views
Visualization Manager:
  Class: ""
  Displays:
    - Alpha: 0.5
      Cell Size: 1
      Class: rviz_default_plugins/Grid
      Color: 160; 160; 164
      Enabled: true
      Name: Grid
      Normal Cell Count: 0
      Plane: XY
      Plane Cell Count: 14
      Reference Frame: <Fixed Frame>
      Value: true
    - Alpha: 1.0
      Binary representation: false
      Binary threshold: 100
      Class: rviz_default_plugins/Map
      Color Scheme: map
      Draw Behind: true
      Enabled: true
      Name: Map /map (SLAM)
      Topic:
        Depth: 1
        Durability Policy: Transient Local
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /map
      Update Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /map_updates
      Use Timestamp: false
      Value: true
    - Alpha: 1
      Autocompute Intensity Bounds: true
      Autocompute Value Bounds: {Max Value: 10, Min Value: -10, Value: true}
      Axis: Z
      Channel Name: intensity
      Class: rviz_default_plugins/LaserScan
      Color: 255; 40; 40
      Color Transformer: FlatColor
      Decay Time: 0
      Enabled: true
      Invert Rainbow: false
      Name: LaserScan /scan
      Position Transformer: XYZ
      Selectable: true
      Size (Pixels): 3
      Size (m): 0.03
      Style: Points
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Best Effort
        Value: /scan
      Use Fixed Frame: true
      Use rainbow: true
      Value: true
    - Class: rviz_default_plugins/TF
      Enabled: true
      Frame Timeout: 15
      Frames:
        All Enabled: true
      Marker Scale: 0.6
      Name: TF
      Show Arrows: true
      Show Axes: true
      Show Names: true
      Update Interval: 0
      Value: true
  Enabled: true
  Global Options:
    Background Color: 48; 48; 48
    Fixed Frame: map
    Frame Rate: 20
  Name: root
  Tools:
    - Class: rviz_default_plugins/MoveCamera
    - Class: rviz_default_plugins/Select
    - Class: rviz_default_plugins/FocusCamera
    - Class: rviz_default_plugins/Measure
      Line color: 128; 128; 0
    - Class: rviz_default_plugins/SetInitialPose
      Covariance x: 0.25
      Covariance y: 0.25
      Covariance yaw: 0.06853891909122467
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /initialpose
    - Class: rviz_default_plugins/SetGoal
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /goal_pose
  Transformation:
    Current:
      Class: rviz_default_plugins/TF
  Value: true
  Views:
    Current:
      Class: rviz_default_plugins/TopDownOrtho
      Name: Current View
      Near Clip Distance: 0.01
      Scale: 55
      Target Frame: <Fixed Frame>
      Value: TopDownOrtho (rviz_default_plugins)
      X: 3
      Y: 2
    Saved: ~
Window Geometry:
  Displays: {collapsed: false}
  Height: 800
  Width: 1200
__CMB_EOF__
mkdir -p "src/campus_mail_bot/rviz"
cat > "src/campus_mail_bot/rviz/nav2.rviz" <<'__CMB_EOF__'
Panels:
  - Class: rviz_common/Displays
    Name: Displays
    Property Tree Widget:
      Expanded:
        - /Global Options1
      Splitter Ratio: 0.5
    Tree Height: 400
  - Class: rviz_common/Views
    Name: Views
Visualization Manager:
  Class: ""
  Displays:
    - Alpha: 0.5
      Cell Size: 1
      Class: rviz_default_plugins/Grid
      Color: 160; 160; 164
      Enabled: true
      Name: Grid
      Normal Cell Count: 0
      Plane: XY
      Plane Cell Count: 14
      Reference Frame: <Fixed Frame>
      Value: true
    - Alpha: 1.0
      Binary representation: false
      Binary threshold: 100
      Class: rviz_default_plugins/Map
      Color Scheme: map
      Draw Behind: true
      Enabled: true
      Name: Static Map /map
      Topic:
        Depth: 1
        Durability Policy: Transient Local
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /map
      Update Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /map_updates
      Use Timestamp: false
      Value: true
    - Alpha: 0.35
      Binary representation: false
      Binary threshold: 100
      Class: rviz_default_plugins/Map
      Color Scheme: costmap
      Draw Behind: false
      Enabled: true
      Name: Global Costmap
      Topic:
        Depth: 1
        Durability Policy: Transient Local
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /global_costmap/costmap
      Update Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /global_costmap/costmap_updates
      Use Timestamp: false
      Value: true
    - Alpha: 0.6
      Binary representation: false
      Binary threshold: 100
      Class: rviz_default_plugins/Map
      Color Scheme: costmap
      Draw Behind: false
      Enabled: true
      Name: Local Costmap
      Topic:
        Depth: 1
        Durability Policy: Transient Local
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /local_costmap/costmap
      Update Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /local_costmap/costmap_updates
      Use Timestamp: false
      Value: true
    - Alpha: 1
      Buffer Length: 1
      Class: rviz_default_plugins/Path
      Color: 255; 0; 0
      Enabled: true
      Head Diameter: 0.2
      Head Length: 0.2
      Length: 0.3
      Line Style: Lines
      Line Width: 0.04
      Name: Global Plan /plan
      Offset: {X: 0, Y: 0, Z: 0}
      Pose Color: 255; 85; 255
      Pose Style: None
      Radius: 0.03
      Shaft Diameter: 0.1
      Shaft Length: 0.1
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /plan
      Value: true
    - Alpha: 1
      Buffer Length: 1
      Class: rviz_default_plugins/Path
      Color: 0; 100; 255
      Enabled: true
      Head Diameter: 0.2
      Head Length: 0.2
      Length: 0.3
      Line Style: Lines
      Line Width: 0.04
      Name: Local Plan /local_plan
      Offset: {X: 0, Y: 0, Z: 0}
      Pose Color: 255; 85; 255
      Pose Style: None
      Radius: 0.03
      Shaft Diameter: 0.1
      Shaft Length: 0.1
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /local_plan
      Value: true
    - Alpha: 1
      Class: nav2_rviz_plugins/ParticleCloud
      Color: 0; 180; 0
      Enabled: true
      Max Arrow Length: 0.3
      Min Arrow Length: 0.02
      Name: AMCL Particle Cloud
      Shape: Arrow (Flat)
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Best Effort
        Value: /particle_cloud
      Value: true
    - Alpha: 1
      Class: rviz_default_plugins/Polygon
      Color: 25; 255; 0
      Enabled: true
      Name: Robot Footprint
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /local_costmap/published_footprint
      Value: true
    - Alpha: 1
      Autocompute Intensity Bounds: true
      Autocompute Value Bounds: {Max Value: 10, Min Value: -10, Value: true}
      Axis: Z
      Channel Name: intensity
      Class: rviz_default_plugins/LaserScan
      Color: 255; 40; 40
      Color Transformer: FlatColor
      Decay Time: 0
      Enabled: true
      Invert Rainbow: false
      Name: LaserScan /scan
      Position Transformer: XYZ
      Selectable: true
      Size (Pixels): 3
      Size (m): 0.03
      Style: Points
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Best Effort
        Value: /scan
      Use Fixed Frame: true
      Use rainbow: true
      Value: true
    - Class: rviz_default_plugins/TF
      Enabled: true
      Frame Timeout: 15
      Frames:
        All Enabled: true
      Marker Scale: 0.6
      Name: TF
      Show Arrows: true
      Show Axes: true
      Show Names: true
      Update Interval: 0
      Value: true
  Enabled: true
  Global Options:
    Background Color: 48; 48; 48
    Fixed Frame: map
    Frame Rate: 20
  Name: root
  Tools:
    - Class: rviz_default_plugins/MoveCamera
    - Class: rviz_default_plugins/Select
    - Class: rviz_default_plugins/FocusCamera
    - Class: rviz_default_plugins/Measure
      Line color: 128; 128; 0
    - Class: rviz_default_plugins/SetInitialPose
      Covariance x: 0.25
      Covariance y: 0.25
      Covariance yaw: 0.06853891909122467
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /initialpose
    - Class: rviz_default_plugins/SetGoal
      Topic:
        Depth: 5
        Durability Policy: Volatile
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /goal_pose
  Transformation:
    Current:
      Class: rviz_default_plugins/TF
  Value: true
  Views:
    Current:
      Class: rviz_default_plugins/TopDownOrtho
      Name: Current View
      Near Clip Distance: 0.01
      Scale: 55
      Target Frame: <Fixed Frame>
      Value: TopDownOrtho (rviz_default_plugins)
      X: 3
      Y: 2
    Saved: ~
Window Geometry:
  Displays: {collapsed: false}
  Height: 800
  Width: 1200
__CMB_EOF__
mkdir -p "src/campus_mail_bot"
cat > "src/campus_mail_bot/setup.cfg" <<'__CMB_EOF__'
[develop]
script_dir=$base/lib/campus_mail_bot
[install]
install_scripts=$base/lib/campus_mail_bot
__CMB_EOF__
mkdir -p "src/campus_mail_bot"
cat > "src/campus_mail_bot/setup.py" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "src/campus_mail_bot/worlds"
cat > "src/campus_mail_bot/worlds/campus_offices.sdf" <<'__CMB_EOF__'
<?xml version="1.0" ?>
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
      <render_engine>ogre2</render_engine>
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
      <collision name="wall_north_col">
        <pose>0.0 4.1 0.5 0 0 0</pose>
        <geometry><box><size>10.4 0.2 1.0</size></box></geometry>
      </collision>
      <visual name="wall_north_vis">
        <pose>0.0 4.1 0.5 0 0 0</pose>
        <geometry><box><size>10.4 0.2 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="wall_south_col">
        <pose>0.0 -4.1 0.5 0 0 0</pose>
        <geometry><box><size>10.4 0.2 1.0</size></box></geometry>
      </collision>
      <visual name="wall_south_vis">
        <pose>0.0 -4.1 0.5 0 0 0</pose>
        <geometry><box><size>10.4 0.2 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="wall_west_col">
        <pose>-5.1 0.0 0.5 0 0 0</pose>
        <geometry><box><size>0.2 8.4 1.0</size></box></geometry>
      </collision>
      <visual name="wall_west_vis">
        <pose>-5.1 0.0 0.5 0 0 0</pose>
        <geometry><box><size>0.2 8.4 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="wall_east_col">
        <pose>5.1 0.0 0.5 0 0 0</pose>
        <geometry><box><size>0.2 8.4 1.0</size></box></geometry>
      </collision>
      <visual name="wall_east_vis">
        <pose>5.1 0.0 0.5 0 0 0</pose>
        <geometry><box><size>0.2 8.4 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="front_1_col">
        <pose>-4.3 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.4 0.1 1.0</size></box></geometry>
      </collision>
      <visual name="front_1_vis">
        <pose>-4.3 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.4 0.1 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="front_2_col">
        <pose>-1.5 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.8 0.1 1.0</size></box></geometry>
      </collision>
      <visual name="front_2_vis">
        <pose>-1.5 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.8 0.1 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="front_3_col">
        <pose>1.5 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.8 0.1 1.0</size></box></geometry>
      </collision>
      <visual name="front_3_vis">
        <pose>1.5 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.8 0.1 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="front_4_col">
        <pose>4.3 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.4 0.1 1.0</size></box></geometry>
      </collision>
      <visual name="front_4_vis">
        <pose>4.3 1.2 0.5 0 0 0</pose>
        <geometry><box><size>1.4 0.1 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="divider_ab_col">
        <pose>-1.5 2.6 0.5 0 0 0</pose>
        <geometry><box><size>0.1 2.8 1.0</size></box></geometry>
      </collision>
      <visual name="divider_ab_vis">
        <pose>-1.5 2.6 0.5 0 0 0</pose>
        <geometry><box><size>0.1 2.8 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="divider_bc_col">
        <pose>1.5 2.6 0.5 0 0 0</pose>
        <geometry><box><size>0.1 2.8 1.0</size></box></geometry>
      </collision>
      <visual name="divider_bc_vis">
        <pose>1.5 2.6 0.5 0 0 0</pose>
        <geometry><box><size>0.1 2.8 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      <collision name="reception_partition_col">
        <pose>-2.0 -2.05 0.5 0 0 0</pose>
        <geometry><box><size>0.1 3.9 1.0</size></box></geometry>
      </collision>
      <visual name="reception_partition_vis">
        <pose>-2.0 -2.05 0.5 0 0 0</pose>
        <geometry><box><size>0.1 3.9 1.0</size></box></geometry>
        <material><ambient>0.85 0.85 0.8 1</ambient><diffuse>0.85 0.85 0.8 1</diffuse></material>
      </visual>
      </link>
    </model>

    <model name="office_furniture">
      <static>true</static>
      <link name="link">
      <collision name="reception_desk_col">
        <pose>-4.3 -3.3 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
      </collision>
      <visual name="reception_desk_vis">
        <pose>-4.3 -3.3 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      <collision name="pillar_col">
        <pose>1.0 -0.8 0.5 0 0 0</pose>
        <geometry><box><size>0.5 0.5 1.0</size></box></geometry>
      </collision>
      <visual name="pillar_vis">
        <pose>1.0 -0.8 0.5 0 0 0</pose>
        <geometry><box><size>0.5 0.5 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      <collision name="cabinet_col">
        <pose>3.8 -2.0 0.5 0 0 0</pose>
        <geometry><box><size>0.6 1.2 1.0</size></box></geometry>
      </collision>
      <visual name="cabinet_vis">
        <pose>3.8 -2.0 0.5 0 0 0</pose>
        <geometry><box><size>0.6 1.2 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      <collision name="desk_a_col">
        <pose>-4.2 3.5 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
      </collision>
      <visual name="desk_a_vis">
        <pose>-4.2 3.5 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      <collision name="desk_b_col">
        <pose>0.0 3.6 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
      </collision>
      <visual name="desk_b_vis">
        <pose>0.0 3.6 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      <collision name="desk_c_col">
        <pose>4.2 3.5 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
      </collision>
      <visual name="desk_c_vis">
        <pose>4.2 3.5 0.5 0 0 0</pose>
        <geometry><box><size>1.0 0.5 1.0</size></box></geometry>
        <material><ambient>0.75 0.45 0.2 1</ambient><diffuse>0.75 0.45 0.2 1</diffuse></material>
      </visual>
      </link>
    </model>

    <!-- ===================== mail_bot (differential drive) =====================
         Frames: odom -> base_link (Gazebo DiffDrive via /tf), base_link -> lidar_link (static TF).
         Wheel radius 0.05 m, wheel separation 0.34 m, chassis 0.36 x 0.30 m. -->
    <model name="mail_bot">
      <pose>-3.5 -2.5 0.01 0 0 0</pose>

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
  </world>
</sdf>
__CMB_EOF__
mkdir -p "tools"
cat > "tools/generate_world_and_map.py" <<'__CMB_EOF__'
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
__CMB_EOF__
mkdir -p "tools"
cat > "tools/make_nav2_params.py" <<'__CMB_EOF__'
#!/usr/bin/env python3
"""Build nav2_baseline.yaml / nav2_tuned.yaml from the official Nav2 *jazzy* nav2_params.yaml.

Usage: make_nav2_params.py <jazzy_nav2_params.yaml> <out_dir>
Only the inflation radius differs between the two outputs.
(The repo ships the generated files; this script documents exactly what was changed.)
"""
import re
import sys

DWB = '''    FollowPath:
      plugin: "dwb_core::DWBLocalPlanner"
      debug_trajectory_details: true
      min_vel_x: 0.0
      min_vel_y: 0.0
      max_vel_x: 0.26
      max_vel_y: 0.0
      max_vel_theta: 1.0
      min_speed_xy: 0.0
      max_speed_xy: 0.26
      min_speed_theta: 0.0
      acc_lim_x: 2.5
      acc_lim_y: 0.0
      acc_lim_theta: 3.2
      decel_lim_x: -2.5
      decel_lim_y: 0.0
      decel_lim_theta: -3.2
      vx_samples: 20
      vy_samples: 5
      vtheta_samples: 20
      sim_time: 1.7
      linear_granularity: 0.05
      angular_granularity: 0.025
      transform_tolerance: 0.2
      xy_goal_tolerance: 0.25
      trans_stopped_velocity: 0.25
      short_circuit_trajectory_evaluation: true
      stateful: true
      critics: ["RotateToGoal", "Oscillation", "BaseObstacle", "GoalAlign", "PathAlign", "PathDist", "GoalDist"]
      BaseObstacle.scale: 0.02
      PathAlign.scale: 32.0
      PathAlign.forward_point_distance: 0.1
      GoalAlign.scale: 24.0
      GoalAlign.forward_point_distance: 0.1
      PathDist.scale: 32.0
      GoalDist.scale: 24.0
      RotateToGoal.scale: 32.0
      RotateToGoal.slowing_factor: 5.0
      RotateToGoal.lookahead_time: -1.0

'''


def build(src, inflation, header):
    t = src
    # 1) use_sim_time everywhere
    t = re.sub(r'^(\s*)ros__parameters:\n', lambda m: f'{m.group(0)}{m.group(1)}  use_sim_time: true\n', t, flags=re.M)
    # 2) DWB instead of MPPI
    t = re.sub(r'    FollowPath:\n      plugin: "nav2_mppi_controller::MPPIController".*?(?=\nlocal_costmap:)',
               DWB.rstrip('\n') + '\n', t, flags=re.S)
    # 3) drop loopback simulator (not used)
    t = t.split('\nloopback_simulator:')[0].rstrip('\n') + '\n'
    # 4) robot specifics
    t = t.replace('robot_radius: 0.22', 'robot_radius: 0.24')
    t = t.replace('inflation_radius: 0.70', f'inflation_radius: {inflation}')
    t = t.replace('inflation_radius: 0.7\n', f'inflation_radius: {inflation}\n')
    t = t.replace('laser_max_range: 100.0', 'laser_max_range: 10.0')
    t = t.replace('max_particles: 2000', 'max_particles: 1000').replace('min_particles: 500', 'min_particles: 300')
    t = t.replace('    scan_topic: scan\n',
                  '    scan_topic: scan\n    set_initial_pose: true\n    always_reset_initial_pose: false\n'
                  '    initial_pose:\n      x: 0.0\n      y: 0.0\n      z: 0.0\n      yaw: 0.0\n', 1)
    t = t.replace('controller_frequency: 20.0', 'controller_frequency: 15.0', 1)
    t = t.replace('max_velocity: [0.5, 0.0, 2.0]', 'max_velocity: [0.26, 0.0, 1.0]')
    t = t.replace('min_velocity: [-0.5, 0.0, -2.0]', 'min_velocity: [-0.26, 0.0, -1.0]')
    t = t.replace('base_frame_id: "base_footprint"', 'base_frame_id: "base_link"')
    return header + t


if __name__ == '__main__':
    src = open(sys.argv[1]).read()
    out = sys.argv[2]
    common = ('# Derived from the official Nav2 Jazzy nav2_params.yaml by tools/make_nav2_params.py\n'
              '# Changes: use_sim_time everywhere, DWB local controller, robot_radius 0.24, base_link frames,\n'
              '# AMCL initial pose (0,0,0)=start pose, 1000 particles (2-core VM), 15 Hz controller, 0.26 m/s limits.\n')
    open(f'{out}/nav2_baseline.yaml', 'w').write(build(
        src, '0.55', '# BASELINE: inflation_radius 0.55 m (global + local costmap)\n' + common))
    open(f'{out}/nav2_tuned.yaml', 'w').write(build(
        src, '0.30', '# TUNED: inflation_radius 0.30 m (global + local costmap) - the ONLY difference from baseline\n' + common))
    print('wrote nav2_baseline.yaml and nav2_tuned.yaml')
__CMB_EOF__
mkdir -p "tools"
cat > "tools/summarize_results.py" <<'__CMB_EOF__'
#!/usr/bin/env python3
"""Turn results/trials_results.csv into a Markdown table (and per-config summary) ready to paste
into docs/03_IEEE_TECHNICAL_REPORT_TEMPLATE.md.   Usage: python3 tools/summarize_results.py [csv]"""
import csv
import statistics as st
import sys
from collections import defaultdict

path = sys.argv[1] if len(sys.argv) > 1 else 'results/trials_results.csv'
rows = list(csv.DictReader(open(path)))
if not rows:
    sys.exit('No rows found in ' + path)

print('### Per-trial results\n')
print('| Trial | Route | Tag | Goals | Time (s) | Distance (m) | Min obstacle (m) | Status |')
print('|---|---|---|---|---|---|---|---|')
for r in rows:
    print(f"| {r['Trial']} | {r['Route']} | {r['Tag']} | {r['Goals_Reached']}/{r['Total_Goals']} | "
          f"{r['Time_sec']} | {r['Distance_m']} | {r['Min_Obstacle_Dist']} | {r['Status']} |")

print('\n### Summary by configuration and route\n')
print('| Tag | Route | Runs | Goal success | Mean time (s) | Mean distance (m) | Min obstacle (m) |')
print('|---|---|---|---|---|---|---|')
g = defaultdict(list)
for r in rows:
    g[(r['Tag'], r['Route'])].append(r)
for (tag, route), rs in sorted(g.items()):
    reached = sum(int(r['Goals_Reached']) for r in rs)
    total = sum(int(r['Total_Goals']) for r in rs)
    t = [float(r['Time_sec']) for r in rs]
    d = [float(r['Distance_m']) for r in rs]
    m = [float(r['Min_Obstacle_Dist']) for r in rs if r['Min_Obstacle_Dist'] not in ('nan', '')]
    print(f"| {tag} | {route} | {len(rs)} | {reached}/{total} ({100*reached/total:.0f}%) | "
          f"{st.mean(t):.1f} | {st.mean(d):.2f} | {min(m) if m else float('nan'):.2f} |")
__CMB_EOF__
chmod +x setup.sh scripts/*.sh tools/*.py
echo "Generating starter world + map ..."
python3 tools/generate_world_and_map.py
touch src/campus_mail_bot/resource/campus_mail_bot
echo "Done. Next:  cd $ROOT && ./setup.sh"
