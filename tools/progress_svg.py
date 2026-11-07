#!/usr/bin/env python3
"""Draw the progress bars of the README from progress/jp/report.json (written by tools/report.py) into progress/jp/progress.svg.

    python tools/progress_svg.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
m = json.load(open(os.path.join(ROOT, "progress", "jp", "report.json")))["measures"]
rows = [("Functions", m["matched_functions_percent"], f'{m["matched_functions"]} / {m["total_functions"]}'),
        ("Code", m["matched_code_percent"], f'{int(m["matched_code"]):,} / {int(m["total_code"]):,} bytes'),
        ("Data", m["matched_data_percent"], f'{int(m["matched_data"]):,} / {int(m["total_data"]):,} bytes')]
W, H, LEFT, BAR = 560, 28 + 30 * len(rows), 90, 300
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Segoe UI, Arial, sans-serif" font-size="13">',
       f'<rect width="{W}" height="{H}" rx="6" fill="#161b22"/>',
       '<text x="14" y="20" fill="#e6edf3" font-weight="bold">Painter Momopie: byte matching</text>']
for i, (name, pct, detail) in enumerate(rows):
    y = 34 + 30 * i
    out.append(f'<text x="14" y="{y + 13}" fill="#e6edf3">{name}</text>')
    out.append(f'<rect x="{LEFT}" y="{y}" width="{BAR}" height="18" rx="4" fill="#30363d"/>')
    out.append(f'<rect x="{LEFT}" y="{y}" width="{BAR * pct / 100:.1f}" height="18" rx="4" fill="#3fb950"/>')
    out.append(f'<text x="{LEFT + BAR / 2}" y="{y + 13}" fill="#ffffff" text-anchor="middle" font-weight="bold">{pct:.2f}%</text>')
    out.append(f'<text x="{LEFT + BAR + 10}" y="{y + 13}" fill="#8b949e">{detail}</text>')
out.append("</svg>")
open(os.path.join(ROOT, "progress", "jp", "progress.svg"), "w", newline="\n").write("\n".join(out) + "\n")
print("wrote progress/jp/progress.svg")
