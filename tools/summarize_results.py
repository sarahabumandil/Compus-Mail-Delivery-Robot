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
