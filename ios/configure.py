#!/usr/bin/env python3
"""Configure PAUSE iOS bundle identifiers for a real Apple development team.

Example: python3 ios/configure.py --bundle-id com.yourname.pause
Do this before xcodegen generate.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent

parser = argparse.ArgumentParser()
parser.add_argument("--bundle-id", required=True,
                    help="Unique reverse-DNS identifier, e.g. com.yourname.pause")
arguments = parser.parse_args()
bundle = arguments.bundle_id.strip()

if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,}", bundle):
    parser.error("Use a reverse-DNS identifier with at least three components: com.yourname.pause")

paths = [
    ROOT / "project.yml",
    ROOT / "App" / "PAUSE.entitlements",
    ROOT / "Monitor" / "PAUSEMonitor.entitlements",
    ROOT / "Report" / "PAUSEReport.entitlements",
    ROOT / "Shared" / "PAUSETransport.swift",
]
updated = 0
for file in paths:
    contents = file.read_text()
    revised = contents.replace("com.example.pause", bundle)
    revised = revised.replace("group.com.example.pause", "group." + bundle)
    if revised != contents:
        file.write_text(revised)
        updated += 1

if updated == 0:
    print("No placeholder identifiers remain. Your project may already be configured.")
else:
    print(f"Updated {updated} files.")
print(f"App: {bundle}")
print(f"Monitor extension: {bundle}.Monitor")
print(f"Report extension: {bundle}.Report")
print(f"App Group: group.{bundle}")
print("Register the App Group in your Apple developer team, then enable it for the app and monitor.")
print("Next: cd ios && xcodegen generate && open PAUSECompanion.xcodeproj")
