#!/usr/bin/env python3
"""Snapshot GitHub release asset download counters and draw an SVG history."""
import csv
import datetime as dt
import html
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

REPO = os.environ.get("GITHUB_REPOSITORY", "amoutiers/maxi-superpowers")
OUT = Path("stats")
CSV = OUT / "release-downloads.csv"
SVG = OUT / "release-downloads.svg"
FIELDS = ["date", "release", "asset_id", "asset_name", "downloads"]


def releases():
    page = 1
    while True:
        req = Request(
            f"https://api.github.com/repos/{REPO}/releases?per_page=100&page={page}",
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {os.environ['GH_TOKEN']}",
                "User-Agent": "release-download-stats",
            },
        )
        with urlopen(req, timeout=30) as response:
            batch = json.load(response)
        if not batch:
            break
        yield from batch
        if len(batch) < 100:
            break
        page += 1


def chart(rows):
    # Count each asset once per day. Sum latest snapshots for each day.
    by_day = {}
    for row in rows:
        by_day.setdefault(row["date"], {})[row["asset_id"]] = int(row["downloads"])
    days = sorted(by_day)
    values = [sum(by_day[day].values()) for day in days]
    width, height = 960, 360
    left, right, top, bottom = 76, 30, 54, 70
    w, h = width - left - right, height - top - bottom
    peak = max(values, default=1) or 1
    coords = [
        (left + i * w / max(len(days) - 1, 1), top + h * (1 - v / peak))
        for i, v in enumerate(values)
    ]
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in coords)
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<text x="76" y="30" font-size="20" font-family="sans-serif" fill="#222">GitHub release asset downloads</text>',
    ]
    for n in range(5):
        v = peak * n / 4
        y = top + h * (1 - n / 4)
        lines += [
            f'<line x1="{left}" y1="{y:.1f}" x2="{left+w}" y2="{y:.1f}" stroke="#e5e7eb"/>',
            f'<text x="{left-12}" y="{y+4:.1f}" text-anchor="end" font-size="12" font-family="sans-serif">{v:.0f}</text>',
        ]
    if coords:
        lines.append(f'<polyline points="{poly}" fill="none" stroke="#2563eb" stroke-width="3" stroke-linejoin="round"/>')
        for i in sorted(set([0, len(days) // 2, len(days) - 1])):
            x = coords[i][0]
            lines.append(f'<text x="{x:.1f}" y="{height-34}" text-anchor="middle" font-size="12" font-family="sans-serif">{html.escape(days[i])}</text>')
        lines.append(f'<text x="{left+w}" y="30" text-anchor="end" font-size="15" font-family="sans-serif">Latest snapshot: {values[-1]:,}</text>')
    else:
        lines.append('<text x="80" y="180" font-size="16" font-family="sans-serif">No release assets found</text>')
    lines.append('</svg>')
    SVG.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    OUT.mkdir(exist_ok=True)
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    existing = []
    if CSV.exists():
        with CSV.open(newline="", encoding="utf-8") as stream:
            existing = list(csv.DictReader(stream))
    # Re-running the workflow on the same date replaces that day's snapshot.
    existing = [r for r in existing if r["date"] != today]
    current = []
    for release in releases():
        for asset in release.get("assets", []):
            current.append({
                "date": today,
                "release": release["tag_name"],
                "asset_id": str(asset["id"]),
                "asset_name": asset["name"],
                "downloads": str(asset["download_count"]),
            })
    rows = sorted(existing + current, key=lambda r: (r["date"], r["release"], r["asset_id"]))
    with CSV.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    chart(rows)
    print(f"Recorded {len(current)} release assets for {today}")


if __name__ == "__main__":
    main()
