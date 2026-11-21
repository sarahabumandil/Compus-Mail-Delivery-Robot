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
