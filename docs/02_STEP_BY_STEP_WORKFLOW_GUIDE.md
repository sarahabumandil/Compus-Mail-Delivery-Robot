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
