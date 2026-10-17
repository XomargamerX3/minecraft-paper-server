#!/usr/bin/env python3
"""Print the newest STABLE Paper build as shell-readable KEY=value lines."""
import json
import sys
import urllib.request

api = sys.argv[1]
wanted = sys.argv[2] if len(sys.argv) > 2 else ""


def get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


versions = get(f"{api}/projects/paper/versions?limit=25")["versions"]

if wanted:
    chosen = next((v for v in versions if v["version"]["id"] == wanted), None)
    if chosen is None:
        sys.exit(f"resolve_paper: version {wanted!r} is not available")
else:
    chosen = next(
        (v for v in versions if v["version"]["support"]["status"] == "SUPPORTED"), None
    )
    if chosen is None:
        sys.exit("resolve_paper: no supported Paper version found")

vid = chosen["version"]["id"]
java_min = chosen["version"]["java"]["version"]["minimum"]

build = None
for b in sorted((int(x) for x in chosen["builds"]), reverse=True):
    info = get(f"{api}/projects/paper/versions/{vid}/builds/{b}")
    if info["channel"] == "STABLE":
        build = info
        break
if build is None:
    sys.exit(f"resolve_paper: no stable build for {vid}")

dl = build["downloads"]["server:default"]
print(f"MC_VERSION={vid}")
print(f"JAVA_MIN={java_min}")
print(f"BUILD={build['id']}")
print(f"DOWNLOAD_URL={dl['url']}")
print(f"DOWNLOAD_SHA={dl['checksums']['sha256']}")
print(f"SIZE_BYTES={dl['size']}")
