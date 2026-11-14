#!/usr/bin/env python3
"""Index an already-published combined IPA using its actual release metadata."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--release-json', type=Path, required=True)
    parser.add_argument('--build-info', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'source.json')
    args = parser.parse_args()
    release = json.loads(args.release_json.read_text())
    build = json.loads(args.build_info.read_text())
    version = build['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or release['tag_name'] != 'v' + version:
        raise SystemExit('Release and native x.y.z version must match.')
    if release.get('draft') or not release.get('published_at'):
        raise SystemExit('Only published releases can enter the feed.')
    number = int(build['build'])
    if number < 1:
        raise SystemExit('Invalid native build number.')
    name = f'WatchLink-{version}-unsigned.ipa'
    asset = next((a for a in release['assets'] if a['name'] == name), None)
    if not asset or asset['size'] <= 0:
        raise SystemExit('Published combined IPA is missing or empty.')
    url = asset['browser_download_url']
    if not url.startswith('https://github.com/soum91/watchlink/releases/download/'):
        raise SystemExit('Unexpected IPA download origin.')
    description = ('Pairing-storage access research probe with an embedded Apple Watch companion. '
                   'Multi-phone pairing is not implemented. iOS 16+ and watchOS 27+; '
                   'use a Watch-aware signer such as EmberSign to sign/install the Watch companion. '
                   'Protected access requires a provisioned dedicated App Group.')
    entry = dict(version=version, buildVersion=str(number), date=release['published_at'][:10],
                 localizedDescription=description, downloadURL=url, size=asset['size'], minOSVersion='16.0')
    versions = []
    if args.output.exists():
        versions = json.loads(args.output.read_text())['apps'][0]['versions']
    versions = [entry] + [v for v in versions if v['version'] != version]
    versions.sort(key=lambda v: tuple(map(int, v['version'].split('.'))), reverse=True)
    latest = versions[0]
    icon = 'https://github.com/soum91.png'
    app = dict(name='WatchLink', bundleIdentifier='dev.watchlink.companion', developerName='WatchLink contributors',
               iconURL=icon, tintColor='#35D3E6', category='utilities', subtitle='iPhone + Apple Watch access probe',
               localizedDescription=description, versions=versions, version=latest['version'],
               versionDate=latest['date'], versionDescription=latest['localizedDescription'],
               downloadURL=latest['downloadURL'], size=latest['size'], minOSVersion='16.0')
    source = dict(name='WatchLink', identifier='dev.watchlink.source', subtitle='iPhone + Apple Watch research builds',
                  description=description, iconURL=icon, website='https://github.com/soum91/watchlink',
                  sourceURL='https://raw.githubusercontent.com/soum91/watchlink/main/source.json',
                  tintColor='#35D3E6', apps=[app], news=[])
    args.output.write_text(json.dumps(source, indent=2) + '\n')
    print(f'Indexed published WatchLink {version} ({number}): {asset["size"]} bytes')

if __name__ == '__main__':
    main()
