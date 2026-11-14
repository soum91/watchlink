import gzip
import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from repo_index import generate
from verify_artifacts import executable_platform

class DistributionTests(unittest.TestCase):
    def package(self,root,architecture="iphoneos-arm64",version="0.1.0"):
        stage=root/"fixture"
        (stage/"DEBIAN").mkdir(parents=True)
        (stage/"DEBIAN/control").write_text(f"Package: dev.watchlink.probe\nVersion: {version}\nArchitecture: {architecture}\nMaintainer: Test fixture\nDescription: Disposable test fixture\n")
        repo=root/"repo"
        (repo/"pool").mkdir(parents=True)
        output=repo/"pool/fixture.deb"
        subprocess.run(["dpkg-deb","--root-owner-group","--build",str(stage),str(output)],check=True,capture_output=True)
        return repo,output
    def test_empty_repo_not_published(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            with self.assertRaises(ValueError): generate(root,"https://example.invalid/repo")
            self.assertFalse((root/"Release").exists())
    def test_real_package_checksums_and_index(self):
        with tempfile.TemporaryDirectory() as folder:
            repo,package=self.package(Path(folder))
            self.assertEqual(generate(repo,"https://example.invalid/repo"),1)
            index=(repo/"Packages").read_bytes()
            self.assertEqual(gzip.decompress((repo/"Packages.gz").read_bytes()),index)
            self.assertIn(hashlib.sha256(package.read_bytes()).hexdigest().encode(),index)
            self.assertIn(b"Filename: https://example.invalid/repo/pool/fixture.deb",index)
            self.assertIn(hashlib.sha256(index).hexdigest(),(repo/"Release").read_text())
    def test_wrong_architecture_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            repo,_=self.package(Path(folder),architecture="iphoneos-arm")
            with self.assertRaises(ValueError): generate(repo,"https://example.invalid/repo")
    def test_incompatible_version_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            repo,_=self.package(Path(folder),version="0.1.0-1")
            with self.assertRaises(ValueError): generate(repo,"https://example.invalid/repo")
    def test_malformed_executable_rejected(self):
        invalid=struct.pack("<8I",0xfeedfacf,0x0100000c,0,2,1,8,0,0)+struct.pack("<II",0x32,0)
        for data in (b"",b"not executable",invalid):
            with self.assertRaises(ValueError): executable_platform(data)
    def test_phone_watch_platforms_distinguished(self):
        for platform in (2,4):
            data=struct.pack("<8I",0xfeedfacf,0x0100000c,0,2,1,24,0,0)+struct.pack("<6I",0x32,24,platform,0,0,0)
            self.assertEqual(executable_platform(data),platform)

    def test_universal_watch_executable_and_invalid_offsets(self):
        leaf=struct.pack("<8I",0xfeedfacf,0x0200000c,0,2,1,24,0,0)+struct.pack("<6I",0x32,24,4,0,0,0)
        header=struct.pack(">IIiiIII",0xcafebabe,1,0x0200000c,0,28,len(leaf),0)
        self.assertEqual(executable_platform(header+leaf),4)
        with self.assertRaises(ValueError): executable_platform(header[:-12]+struct.pack(">III",0,len(leaf),0)+leaf)
        invalid_phone=struct.pack("<8I",0xfeedfacf,0x0200000c,0,2,1,24,0,0)+struct.pack("<6I",0x32,24,2,0,0,0)
        with self.assertRaises(ValueError): executable_platform(invalid_phone)

if __name__=="__main__": unittest.main()
