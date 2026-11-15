#!/usr/bin/env python3
"""Build real native apps on macOS; refuse missing SDKs."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import sys
import zlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)

def output(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()

def version():
    value = (ROOT / "VERSION").read_text().strip()
    if len(value.split(".")) != 3 or not all(p.isdecimal() for p in value.split(".")):
        raise ValueError("VERSION must use x.y.z")
    return value

def icon(path, size):
    def rounded(x, y, left, top, right, bottom, radius):
        dx = max(left + radius - x, 0, x - (right - radius))
        dy = max(top + radius - y, 0, y - (bottom - radius))
        return left <= x <= right and top <= y <= bottom and dx*dx + dy*dy <= radius*radius
    scan = bytearray()
    for y in range(size):
        scan.append(0)
        for x in range(size):
            u, v = x * 1024 / size, y * 1024 / size
            color = (12, 23, 42, 255)
            for left, top, right, bottom, tint in [(180,170,560,710,(53,211,230,255)), (464,314,844,854,(147,121,255,255))]:
                if rounded(u,v,left+120,top-85,right-120,bottom+85,28): color=(44,59,83,255)
                if rounded(u,v,left,top,right,bottom,100): color=tint
                if rounded(u,v,left+30,top+30,right-30,bottom-30,76): color=(18,33,55,255)
                if (u-(left+right)/2)**2+(v-(top+bottom)/2)**2 < 50**2: color=tint
            scan.extend(color)
    def chunk(kind, data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",size,size,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(bytes(scan),9))+chunk(b"IEND",b""))

def build_apps(number):
    """Let Xcode produce bundle metadata and the companion copy phase."""
    project_dir = ROOT / "build/xcode"
    project_dir.mkdir(parents=True, exist_ok=True)
    sdk_version = output("xcrun", "--sdk", "watchos", "--show-sdk-version")
    if int(sdk_version.split(".")[0]) < 27:
        raise RuntimeError("watchOS 27 SDK required.")
    resources = {}
    for platform in ("ios", "watchos"):
        assets = project_dir / (platform + ".xcassets")
        appicon = assets / "AppIcon.appiconset"
        appicon.mkdir(parents=True, exist_ok=True)
        (assets / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}))
        (appicon / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": platform, "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}))
        icon(appicon / "AppIcon.png", 1024)
        resources[platform] = str(assets)
    base = {"SWIFT_VERSION": "5.0", "MARKETING_VERSION": version(), "CURRENT_PROJECT_VERSION": str(number),
            "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGNING_ALLOWED": "NO", "SUPPORTS_MACCATALYST": "NO",
            "SWIFT_OBJC_BRIDGING_HEADER": str(ROOT / "Native/Probe.h"), "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon"}
    def target(watch):
        name = "WatchLinkWatch" if watch else "WatchLink"
        properties = {"CFBundleDisplayName": "WatchLink", "NSBluetoothAlwaysUsageDescription": "Find your nearby WatchLink iPhone receiver and send your scan report directly over Bluetooth.", "NSLocalNetworkUsageDescription": "Transfer your WatchLink report directly between your Watch and iPhone on local Wi-Fi.", "NSBonjourServices": ["_watchlink._tcp"]}
        if watch:
            properties["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True}
            properties.update({"WKCompanionAppBundleIdentifier": "dev.watchlink.companion", "WKRunsIndependentlyOfCompanionApp": True})
        else:
            properties.update({"UILaunchScreen": {}, "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"]})
        result = {"type": "application", "platform": "watchOS" if watch else "iOS",
                  "sources": [str(ROOT / "App/BluetoothReportLink.swift"), str(ROOT / "App/ReportBluetoothProtocol.swift"), str(ROOT / "App/Shared.swift"), str(ROOT / "App/LocalReportLink.swift"), str(ROOT / ("App/Watch.swift" if watch else "App/Phone.swift")), str(ROOT / "Native/Probe.m"), resources["watchos" if watch else "ios"]],
                  "info": {"path": str(project_dir / (name + "-Info.plist")), "properties": properties},
                  "settings": {"base": {**base, "PRODUCT_BUNDLE_IDENTIFIER": "dev.watchlink.companion.watchapp" if watch else "dev.watchlink.companion", "TARGETED_DEVICE_FAMILY": "4" if watch else "1,2"}}, "scheme": {}}
        if not watch:
            result["dependencies"] = [{"target": "WatchLinkWatch", "embed": True}]
        return result
    spec = {"name": "WatchLink", "options": {"deploymentTarget": {"iOS": "16.0", "watchOS": "27.0"}, "xcodeVersion": "27.0", "projectFormat": "xcode27_0"},
            "targets": {"WatchLink": target(False), "WatchLinkWatch": target(True)}}
    spec_path = project_dir / "project.json"
    spec_path.write_text(json.dumps(spec, indent=2))
    run("xcodegen", "generate", "--spec", spec_path, "--project", project_dir)
    pbx = project_dir / "WatchLink.xcodeproj/project.pbxproj"
    # Match the Xcode 27 companion layout already used by WristPane.
    text = pbx.read_text()
    text = text.replace('dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";', 'dstPath = "";').replace('dstSubfolderSpec = 16;', 'dstSubfolderSpec = 13;')
    pbx.write_text(text)
    for scheme, platform in (("WatchLinkWatch", "watchOS"), ("WatchLink", "iOS")):
        run("xcodebuild", "-project", project_dir / "WatchLink.xcodeproj", "-scheme", scheme, "-configuration", "Release",
            "-destination", "generic/platform=" + platform, "-derivedDataPath", project_dir / "DerivedData", "CODE_SIGNING_ALLOWED=NO", "build")
    products = project_dir / "DerivedData/Build/Products"
    watch = ROOT / "build/watch/WatchLinkWatch.app"
    phone = ROOT / "build/phone/WatchLink.app"
    for source, app, is_watch in ((products / "Release-watchos/WatchLinkWatch.app", watch, True), (products / "Release-iphoneos/WatchLink.app", phone, False)):
        if app.exists(): shutil.rmtree(app)
        shutil.copytree(source, app)
        icon(app / "AppIcon.png", 108 if is_watch else 120)
        for name in ("THIRD_PARTY_NOTICES.md", "CHANGELOG.md"): shutil.copy2(ROOT / name, app / name)
        shutil.copytree(ROOT / "licenses", app / "licenses", dirs_exist_ok=True)
    embedded = phone / "PlugIns/WatchLinkWatch.app"
    if not embedded.is_dir(): raise RuntimeError("Xcode did not embed the Watch app in PlugIns/.")
    shutil.rmtree(embedded)
    shutil.copytree(watch, embedded)
    for app in (watch, embedded, phone):
        for library in app.rglob("*.dylib"):
            run("codesign", "--force", "--sign", "-", library)
        run("codesign", "--force", "--sign", "-", "--entitlements", ROOT / "packaging/sideload.entitlements", app)
    return watch, phone

def ipa(app, destination):
    with zipfile.ZipFile(destination,"w",zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob("*")):
            if path.is_file(): archive.write(path,"Payload/"+app.name+"/"+path.relative_to(app).as_posix())

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--build-number",type=int,default=1)
    args=parser.parse_args()
    if sys.platform!="darwin": raise SystemExit("Build requires macOS and Xcode. Use GitHub Actions.")
    if args.build_number<1: raise SystemExit("Build number must be positive.")
    dist=ROOT/"dist"
    dist.mkdir(exist_ok=True)
    watch, phone = build_apps(args.build_number)
    ipa(phone,dist/f"WatchLink-{version()}-unsigned.ipa")
    ipa(watch,dist/f"WatchLinkWatch-{version()}-unsigned.ipa")
    phone_only = ROOT / "build/phone-only/WatchLink.app"
    if phone_only.exists(): shutil.rmtree(phone_only)
    shutil.copytree(phone, phone_only)
    shutil.rmtree(phone_only / "PlugIns/WatchLinkWatch.app")
    run("codesign", "--force", "--sign", "-", "--entitlements", ROOT / "packaging/sideload.entitlements", phone_only)
    ipa(phone_only, dist/f"WatchLinkPhone-{version()}-unsigned.ipa")
    (dist/"build-info.json").write_text(json.dumps({"version":version(),"build":args.build_number,
        "xcode":output("xcodebuild","-version"),"watchSDK":output("xcrun","--sdk","watchos","--show-sdk-version"),
        "iPhoneSDK":output("xcrun","--sdk","iphoneos","--show-sdk-version"),
        "packaging":"xcodegen+xcodebuild", "watchBundleLayout":"PlugIns", "defaultAppGroups":False,
        "hardwareTested":False,"dualPairingImplemented":False},indent=2)+"\n")
    print("Native compilation complete. Hardware execution remains unverified.")

if __name__=="__main__": main()
