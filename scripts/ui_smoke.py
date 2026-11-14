#!/usr/bin/env python3
"""Run real iOS simulator UI checks against the current app sources."""
import json
from pathlib import Path
import subprocess
import sys
from build import ROOT

def output(*args):
    return subprocess.check_output([str(a) for a in args], text=True, timeout=120)

def main():
    if sys.platform != "darwin": raise SystemExit("Simulator UI checks require macOS/Xcode.")
    directory = ROOT / "build/ui"
    directory.mkdir(parents=True, exist_ok=True)
    base = {"SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "16.0", "CODE_SIGNING_ALLOWED": "NO"}
    spec = {
        "name": "WatchLinkSmoke",
        "options": {"deploymentTarget": {"iOS": "16.0"}},
        "targets": {
            "WatchLinkSmoke": {
                "type": "application", "platform": "iOS",
                "sources": [str(ROOT / p) for p in ("App/Phone.swift", "App/Shared.swift", "Native/Probe.m")],
                "info": {"path": str(directory / "PhoneInfo.plist"), "properties": {
                    "CFBundleDisplayName": "WatchLink", "CFBundleShortVersionString": (ROOT / "VERSION").read_text().strip(),
                    "CFBundleVersion": "1", "UILaunchScreen": {},
                    "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}}},
                "settings": {"base": {**base, "PRODUCT_BUNDLE_IDENTIFIER": "dev.watchlink.smoke",
                    "SWIFT_OBJC_BRIDGING_HEADER": str(ROOT / "Native/Probe.h"), "TARGETED_DEVICE_FAMILY": "1,2"}}
            },
            "WatchLinkUITests": {
                "type": "bundle.ui-testing", "platform": "iOS",
                "sources": [str(ROOT / "tests/ui/ReportActionsTests.swift")],
                "dependencies": [{"target": "WatchLinkSmoke"}],
                "settings": {"base": {**base, "PRODUCT_BUNDLE_IDENTIFIER": "dev.watchlink.smoke.uitests",
                    "GENERATE_INFOPLIST_FILE": "YES", "TEST_TARGET_NAME": "WatchLinkSmoke"}}
            }
        },
        "schemes": {"WatchLinkSmoke": {"build": {"targets": {"WatchLinkSmoke": "all"}},
            "test": {"targets": ["WatchLinkUITests"], "parallelizable": False}}}
    }
    project = directory / "project.json"
    project.write_text(json.dumps(spec, indent=2))
    subprocess.run(["xcodegen", "generate", "--spec", str(project), "--project", str(directory)], check=True, timeout=90)
    devices = json.loads(output("xcrun", "simctl", "list", "devices", "available", "--json"))["devices"]
    eligible = [d for runtime, group in devices.items() if ".iOS-" in runtime for d in group
                if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if not eligible: raise SystemExit("No installed iPhone simulator runtime. UI tests were not run.")
    selected = sorted(eligible, key=lambda d: (d["state"] == "Booted", d["name"]), reverse=True)[0]
    identifier = selected["udid"]
    if selected["state"] != "Booted":
        subprocess.run(["xcrun", "simctl", "boot", identifier], check=True, timeout=120)
    subprocess.run(["xcrun", "simctl", "bootstatus", identifier, "-b"], check=True, timeout=180)
    command = ["xcodebuild", "test", "-project", str(directory / "WatchLinkSmoke.xcodeproj"),
        "-scheme", "WatchLinkSmoke", "-destination", "platform=iOS Simulator,id=" + identifier,
        "-derivedDataPath", str(directory / "DerivedData"), "-resultBundlePath", str(directory / "ReportActions.xcresult"),
        "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]
    subprocess.run(command, check=True, timeout=360)

if __name__ == "__main__": main()
