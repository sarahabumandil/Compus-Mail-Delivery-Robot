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
