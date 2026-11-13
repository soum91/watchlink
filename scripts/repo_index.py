#!/usr/bin/env python3
import argparse
import datetime
import gzip
import hashlib
from pathlib import Path
import re
import subprocess

def control_fields(path):
    text=subprocess.check_output(["dpkg-deb","--field",str(path)],text=True)
    fields={}
    key=None
    for line in text.splitlines():
        if line.startswith(" ") and key: fields[key]+="\n"+line
        elif ":" in line:
            key,value=line.split(":",1)
            fields[key]=value.strip()
    return fields

def generate(root,base_url):
    if not base_url.startswith("https://") or any(c.isspace() for c in base_url):
        raise ValueError("HTTPS repository base URL required.")
    packages=sorted((root/"pool").glob("*.deb"))
    if not packages: raise ValueError("No compiled Debian packages; refusing empty repository.")
    records=[]
    for path in packages:
        fields=control_fields(path)
        if fields.get("Package")!="dev.watchlink.probe" or fields.get("Architecture")!="iphoneos-arm64":
            raise ValueError("Unexpected package identity or architecture.")
        if not re.fullmatch(r"\d+\.\d+\.\d+",fields.get("Version","")):
            raise ValueError("Package version must use x.y.z.")
        data=path.read_bytes()
        fields.update({"Filename":base_url.rstrip("/")+"/pool/"+path.name,"Size":str(len(data)),
            "MD5sum":hashlib.md5(data).hexdigest(),"SHA256":hashlib.sha256(data).hexdigest()})
        records.append("\n".join(key+": "+value for key,value in fields.items()))
    data=("\n\n".join(records)+"\n\n").encode()
    root.mkdir(parents=True,exist_ok=True)
    (root/"Packages").write_bytes(data)
    (root/"Packages.gz").write_bytes(gzip.compress(data,mtime=0))
    lines=["Origin: WatchLink","Label: WatchLink Research","Suite: stable","Codename: watchlink",
        "Architectures: iphoneos-arm64","Components: main","Description: Experimental pairing access probe",
        "Date: "+datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")]
    for label,algorithm in (("MD5Sum","md5"),("SHA256","sha256")):
        lines.append(label+":")
        for filename in ("Packages","Packages.gz"):
            payload=(root/filename).read_bytes()
            lines.append(f" {hashlib.new(algorithm,payload).hexdigest()} {len(payload):16d} {filename}")
    (root/"Release").write_text("\n".join(lines)+"\n")
    return len(records)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--root",type=Path,default=Path("repo"))
    parser.add_argument("--base-url",required=True)
    args=parser.parse_args()
    print(f"Indexed {generate(args.root,args.base_url)} actual package(s).")

if __name__=="__main__": main()
