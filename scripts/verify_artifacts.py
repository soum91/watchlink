#!/usr/bin/env python3
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile
import zipfile
from build import ROOT, version

def executable_platform(payload):
    if len(payload) < 4: raise ValueError("Truncated executable")
    fat_magic = struct.unpack_from(">I", payload)[0]
    if fat_magic in (0xcafebabe, 0xcafebabf):
        if len(payload) < 8: raise ValueError("Truncated universal header")
        count = struct.unpack_from(">I", payload, 4)[0]
        entry_size = 32 if fat_magic == 0xcafebabf else 20
        table_end = 8 + count * entry_size
        if not 1 <= count <= 8 or table_end > len(payload): raise ValueError("Invalid universal architecture table")
        platforms = set()
        for index in range(count):
            pos = 8 + index * entry_size
            offset, length = struct.unpack_from(">QQ" if entry_size == 32 else ">II", payload, pos + 8)
            if offset < table_end or length < 32 or offset + length > len(payload): raise ValueError("Invalid universal slice")
            platforms.add(executable_platform(payload[offset:offset + length]))
        if len(platforms) != 1: raise ValueError("Universal slices target different platforms")
        return platforms.pop()
    if len(payload)<32: raise ValueError("Truncated executable")
    magic,cpu,subtype,filetype,count,size,flags,reserved=struct.unpack_from("<8I",payload)
    if magic!=0xfeedfacf or cpu not in (0x0100000c,0x0200000c) or filetype!=2: raise ValueError("Expected arm64 Mach-O executable")
    if 32+size>len(payload): raise ValueError("Load commands exceed executable")
    cursor=32
    platform=None
    for _ in range(count):
        if cursor+8>32+size: raise ValueError("Truncated load command")
        command,length=struct.unpack_from("<II",payload,cursor)
        if length<8 or cursor+length>32+size: raise ValueError("Invalid command length")
        if command==0x32:
            if length<24: raise ValueError("Truncated LC_BUILD_VERSION")
            platform=struct.unpack_from("<I",payload,cursor+8)[0]
        cursor+=length
    if platform is None: raise ValueError("LC_BUILD_VERSION absent")
    if cpu == 0x0200000c and platform != 4: raise ValueError("arm64_32 is only accepted for watchOS")
    return platform

def verify_app(app,platform,identifier):
    info=plistlib.loads((app/"Info.plist").read_bytes())
    if info.get("CFBundleIdentifier")!=identifier: raise ValueError("Bundle identifier mismatch")
    if info.get("CFBundleShortVersionString")!=version(): raise ValueError("Version mismatch")
    if int(info.get("CFBundleVersion","0"))<1: raise ValueError("Build number missing")
    if executable_platform((app/info["CFBundleExecutable"]).read_bytes())!=platform: raise ValueError("Mach-O platform mismatch")
    if not (app/"AppIcon.png").is_file(): raise ValueError("Icon missing")
    if platform == 4:
        ats=info.get("NSAppTransportSecurity",{})
        if not ats.get("NSAllowsArbitraryLoads") or "NSAllowsLocalNetworking" in ats:
            raise ValueError("Watch HTTP numeric-IP ATS settings missing or overridden")

def main():
    dist=ROOT/"dist"
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory)
        for label in ("WatchLink","WatchLinkWatch","WatchLinkPhone"):
            destination=root/label
            with zipfile.ZipFile(dist/f"{label}-{version()}-unsigned.ipa") as archive:
                for entry in archive.namelist():
                    if Path(entry).is_absolute() or ".." in Path(entry).parts: raise ValueError("Unsafe archive path")
                archive.extractall(destination)
                for entry in archive.infolist():
                    if not entry.is_dir():
                        (destination/entry.filename).chmod((entry.external_attr>>16)&0o777 or 0o644)
            watch=label=="WatchLinkWatch"
            app=destination/"Payload"/("WatchLinkWatch.app" if watch else "WatchLink.app")
            verify_app(app,4 if watch else 2,"dev.watchlink.companion.watchapp" if watch else "dev.watchlink.companion")
            subprocess.run(["codesign","--verify","--strict",str(app)],check=True)
            entitlements = subprocess.check_output(["codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.PIPE)
            if plistlib.loads(entitlements).get("com.apple.security.application-groups"):
                raise ValueError("Default sideload build must not require App Groups")
            if label == "WatchLink":
                verify_app(app/"PlugIns/WatchLinkWatch.app",4,"dev.watchlink.companion.watchapp")
                if (app/"Watch").exists(): raise ValueError("Legacy Watch layout in modern companion IPA")
            if label == "WatchLinkPhone" and (app/"PlugIns/WatchLinkWatch.app").exists():
                raise ValueError("Phone-only diagnostic IPA still contains Watch app")
        deb=root/"deb"
        subprocess.run(["dpkg-deb","--extract",str(dist/f"dev.watchlink.probe_{version()}_iphoneos-arm64.deb"),str(deb)],check=True)
        verify_app(deb/"var/jb/Applications/WatchLink.app",2,"dev.watchlink.companion")
        if (deb/"Applications").exists(): raise ValueError("Rootful app path in rootless package")
    print("Artifacts verified. Hardware execution remains unverified.")

if __name__=="__main__": main()
