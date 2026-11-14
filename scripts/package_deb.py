#!/usr/bin/env python3
import argparse
from pathlib import Path
import shutil
import subprocess
from build import ROOT, version

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--ldid",default="ldid")
    args=parser.parse_args()
    app=ROOT/"build/phone/WatchLink.app"
    if not (app/"WatchLink").is_file(): raise SystemExit("Compiled iPhone executable missing; refusing placeholder package.")
    if (app/"WatchLink").read_bytes()[:4] not in (b"\xcf\xfa\xed\xfe",b"\xca\xfe\xba\xbe"):
        raise SystemExit("Expected a Mach-O executable.")
    stage=ROOT/"build/deb"
    if stage.exists(): shutil.rmtree(stage)
    target=stage/"var/jb/Applications/WatchLink.app"
    shutil.copytree(app,target)
    shutil.rmtree(target/"Watch",ignore_errors=True)
    shutil.rmtree(target/"PlugIns/WatchLinkWatch.app",ignore_errors=True)
    shutil.rmtree(target/"_CodeSignature",ignore_errors=True)
    subprocess.run([args.ldid,"-S"+str(ROOT/"packaging/phone-jailbreak.entitlements"),str(target/"WatchLink")],check=True)
    control=stage/"DEBIAN"
    control.mkdir()
    (control/"control").write_text((ROOT/"packaging/control").read_text().replace("Version: 0.1.0","Version: "+version()))
    for name in ("postinst","postrm"):
        shutil.copy2(ROOT/"packaging"/name,control/name)
        (control/name).chmod(0o755)
    (target/"WatchLink").chmod(0o755)
    dist=ROOT/"dist"
    dist.mkdir(exist_ok=True)
    destination=dist/f"dev.watchlink.probe_{version()}_iphoneos-arm64.deb"
    subprocess.run(["dpkg-deb","--root-owner-group","--build",str(stage),str(destination)],check=True)
    subprocess.run(["dpkg-deb","--info",str(destination)],check=True)

if __name__=="__main__": main()
