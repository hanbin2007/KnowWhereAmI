#!/usr/bin/env python3
"""Exports PNG attachments from an .xcresult bundle with readable file names."""
import json, pathlib, re, shutil, subprocess, sys, tempfile

result, destination = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
destination.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as raw:
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                    "--output-path", raw], check=True)
    manifest = json.loads((pathlib.Path(raw) / "manifest.json").read_text())
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName") or attachment["exportedFileName"]
            name = re.sub(r"_\d+_[0-9A-F-]{36}", "", name)
            name = re.sub(r"[^A-Za-z0-9._ -]+", "-", name).strip()
            source = pathlib.Path(raw) / attachment["exportedFileName"]
            if source.suffix.lower() in (".png", ".jpg", ".jpeg", ".heic"):
                shutil.copy(source, destination / name)
                print(destination / name)
