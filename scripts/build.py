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

def build_app(platform, number):
    watch = platform == "watchos"
    sdk = output("xcrun","--sdk",platform,"--show-sdk-path")
    sdk_version = output("xcrun","--sdk",platform,"--show-sdk-version")
    if watch and int(sdk_version.split(".")[0]) < 27:
        raise RuntimeError("watchOS 27 SDK required. No Watch artifact was produced.")
    deployment = "27.0" if watch else "16.0"
    triple = f"arm64-apple-{'watchos' if watch else 'ios'}{deployment}"
    app = ROOT/"build"/("watch" if watch else "phone")/("WatchLinkWatch.app" if watch else "WatchLink.app")
    if app.exists(): shutil.rmtree(app)
    app.mkdir(parents=True)
    obj = ROOT/"build"/(platform+"-Probe.o")
    run("xcrun","--sdk",platform,"clang","-target",triple,"-isysroot",sdk,
        "-fobjc-arc","-fmodules","-O2","-c",ROOT/"Native/Probe.m","-o",obj)
    run("xcrun","--sdk",platform,"swiftc","-parse-as-library","-swift-version","5",
        "-sdk",sdk,"-target",triple,"-O","-import-objc-header",ROOT/"Native/Probe.h",
        ROOT/"App/Shared.swift",ROOT/("App/Watch.swift" if watch else "App/Phone.swift"),obj,
        "-framework","SwiftUI","-framework","Foundation","-framework","WatchConnectivity",
        "-framework","Security","-framework","CoreFoundation",
        "-Xlinker","-rpath","-Xlinker","@executable_path/Frameworks","-o",app/"WatchLink")
    info = {"CFBundleIdentifier":"dev.watchlink.companion.watchapp" if watch else "dev.watchlink.companion",
        "CFBundleExecutable":"WatchLink","CFBundleName":"WatchLink","CFBundleDisplayName":"WatchLink",
        "CFBundlePackageType":"APPL","CFBundleShortVersionString":version(),"CFBundleVersion":str(number),
        "MinimumOSVersion":deployment,"CFBundleSupportedPlatforms":["WatchOS" if watch else "iPhoneOS"],
        "CFBundleIconFiles":["AppIcon"],"DTPlatformName":platform,"DTSDKName":platform+sdk_version}
    if watch:
        info.update({"WKApplication":True,"WKWatchKitApp":True,"WKCompanionAppBundleIdentifier":"dev.watchlink.companion",
            "WKRunsIndependentlyOfCompanionApp":True,"UIDeviceFamily":[4]})
    else:
        info.update({"UIDeviceFamily":[1,2],"LSRequiresIPhoneOS":True,
            "UIApplicationSceneManifest":{"UIApplicationSupportsMultipleScenes":False},"UILaunchScreen":{},
            "UISupportedInterfaceOrientations":["UIInterfaceOrientationPortrait"]})
    (app/"Info.plist").write_bytes(plistlib.dumps(info))
    frameworks=app/"Frameworks"
    frameworks.mkdir()
    run("xcrun","swift-stdlib-tool","--copy","--scan-executable",app/"WatchLink",
        "--platform",platform,"--destination",frameworks)
    for library in frameworks.glob("*.dylib"):
        run("codesign","--force","--sign","-",library)
    icon(app/"AppIcon.png",108 if watch else 120)
    for name in ("THIRD_PARTY_NOTICES.md","CHANGELOG.md"): shutil.copy2(ROOT/name,app/name)
    shutil.copytree(ROOT/"licenses",app/"licenses",dirs_exist_ok=True)
    run("codesign","--force","--sign","-","--entitlements",ROOT/"packaging/sideload.entitlements",app)
    return app

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
    watch=build_app("watchos",args.build_number)
    phone=build_app("iphoneos",args.build_number)
    embedded=phone/"Watch"/watch.name
    embedded.parent.mkdir(exist_ok=True)
    shutil.copytree(watch,embedded,dirs_exist_ok=True)
    run("codesign","--force","--sign","-","--entitlements",ROOT/"packaging/sideload.entitlements",phone)
    ipa(phone,dist/f"WatchLink-{version()}-unsigned.ipa")
    ipa(watch,dist/f"WatchLinkWatch-{version()}-unsigned.ipa")
    (dist/"build-info.json").write_text(json.dumps({"version":version(),"build":args.build_number,
        "xcode":output("xcodebuild","-version"),"watchSDK":output("xcrun","--sdk","watchos","--show-sdk-version"),
        "hardwareTested":False,"dualPairingImplemented":False},indent=2)+"\n")
    print("Native compilation complete. Hardware execution remains unverified.")

if __name__=="__main__": main()
