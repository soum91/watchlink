# WatchLink

Experimental pairing-access research for Apple Watch Series 10 on watchOS 27.2,
an iOS 16 Dopamine iPhone, and a stock iPhone on iOS 27.0.1.

**0.1.4 is an access probe. Dual pairing, phone switching, key preservation,
pairing compatibility bypasses, and a Watch jailbreak are not implemented.**

## Included

- iPhone companion and native Watch application with installed version/build.
- User-initiated normal-access and protected-access checks on pairing-storage candidates.
- Separate extension-acquired, actual file-open, and cleanup results.
- Metadata-only reports: no account/device identifiers, filenames, or key values.
- WatchConnectivity report transfer to the currently paired iPhone.
- iPhone Copy, Share, and Files export.
- Independent report buttons and one native export presenter prevent overlapping sheets.
- A report-source label identifies iPhone versus Watch results; the latest received report is retained.
- Rootless Debian packaging, a Sileo index generator, checksums, and release workflow.

No registry entries, pairing files, MobileGestalt values, daemon settings, or
keychain values are modified. Protected probing temporarily moves the probe's
dedicated App Group cache, creates a symlink there, and restores it. This is not
a filesystem-pure read operation. Interrupted probes retain a recovery journal;
uncertain recovery stops rather than deleting unrelated data.

The paths are candidates, not verified watchOS 27 storage locations. File-open
access does not prove decrypted keychain access or preservation of SEP key references.

## Installation after a successful native build

### Dopamine iOS 16

Install the `iphoneos-arm64.deb` with Sileo. It installs the companion at
`/var/jb/Applications/WatchLink.app`; it does not inject a daemon or install an
app onto the Watch. Launch WatchLink and run a normal scan first.

### FlareStore IPA source

Add `https://raw.githubusercontent.com/soum91/watchlink/main/source.json` to FlareStore.
The source indexes the published combined iPhone + Watch IPA, preserving native
x.y.z versions, build numbers, actual byte sizes, and version history. Download
with FlareStore and use EmberSign's Watch companion signing/installation flow.
The source updates automatically after successful release publication.

### Watch and stock iPhone

Use the combined `WatchLink-x.y.z-unsigned.ipa` with a Watch-aware signing tool
on the iPhone **already paired to the Watch**. A separate Watch-only IPA is also
produced for tools that explicitly support standalone watchOS application payloads.
This project does not establish a new pairing or bypass OS compatibility checks.

IPAs contain ad-hoc development signatures and must be re-signed with your valid
provisioning profiles. Protected Watch access requires a dedicated provisioned
App Group ending `.watchlink.probe`; the optional signing template is
`packaging/protected-probe.entitlements` (`group.dev.watchlink.probe`). Default IPAs
request no App Groups, so a normal scan does not require provisioning this capability. Provisioning App Groups may require a paid developer
team. A tool that strips this entitlement leaves only normal scanning available.

The Watch app requires watchOS 27.0+; the phone app requires iOS 16.0+.
Enable Developer Mode if your signing tool requires it. Installation through a
stock paired phone is supported as an intended workflow, not physically verified.

## Collect results

1. Keep the current pairing intact.
2. Run a normal scan on the Watch.
3. If correctly signed with a dedicated App Group, enable Protected access and
   run one scan. Extension issuance and actual access are independent observations.
4. Tap Send report. The phone companion must be installed and activated.
5. Use Copy, Share, or Save on the phone. The Watch retains its own report.

A queued transfer is not delivery confirmation. Reports are never uploaded
automatically. Do not erase or re-pair the Watch based on a successful scan.

## GitHub and Sileo publication

The public repository is `soum91/watchlink`. Binary releases and the Sileo endpoint
become available only after the native build and publication workflow succeeds.

On a computer with a signed-in GitHub CLI, run:

```sh
sh scripts/bootstrap-github.sh
```

The script creates the public repository if missing, pushes the source, and
requests the build workflow. Alternatively, create the repository and upload
the source, including `.github/workflows/release.yml`; a main-branch push builds it.

The workflow requires a macOS runner with Xcode and the watchOS 27 SDK. It fails
explicitly when no such SDK is installed. Hosted runner SDK availability is not
verified. No placeholder IPAs or Debian packages are generated.

After the first successful build and publish, the Sileo source will be:

```text
https://raw.githubusercontent.com/soum91/watchlink/main/repo/
```

It becomes usable only after the real `Release`, `Packages.gz`, and `.deb` files
are pushed. GitHub Pages is not required. This is a conventional unsigned
package repository, not a cryptographically signed APT archive.

Each release contains combined, Watch-only, and phone-only diagnostic unsigned IPAs, a rootless `.deb`,
source ZIP, build metadata, and SHA256SUMS. Semantic versions cannot be reused.

## Validation

```sh
python3 -m unittest discover -s tests -v
python3 scripts/build.py --build-number 1
python3 scripts/package_deb.py
python3 scripts/verify_artifacts.py
```

Manual workflow dispatch runs `scripts/ui_smoke.py` with XcodeGen on an
iPhone simulator. It checks that Copy opens neither export sheet, Save opens only
the document picker and can repeat after cancellation, and Share opens only its
activity controller. Simulator success does not establish iOS 16 jailbreak behavior.

Native compilation requires macOS/Xcode; Debian packaging also requires ldid and
dpkg-deb. Compilation, package validation, and physical execution are separate.
See VALIDATION.md for the current evidence and remaining hardware checks.

## Next research gates

First establish access to actual pairing state while preserving the current pair.
Then identify companion records and key references without exporting secrets.
Determine whether establishing a second pair destroys the first pair's keys;
a file snapshot cannot restore deleted Secure Enclave state. Only after those
checks should switching be implemented. Simultaneous native synchronization is
a separate protocol and state-management problem.

Nothing currently promises persistence through unpairing, erasure, transfer,
app removal, reboot, or watchOS updates.

## Multi-pairing access investigation (0.1.3)

The normal scan now compares direct directory access, bounded container discovery,
Mach service lookup reachability, and NanoRegistry class/selector availability.
Container surveys visit at most 64 entries per target and read only bounded MCM
container metadata. They identify known Apple component categories and check for
registry/state storage underneath matched containers. UUIDs, filenames, actual
container identifiers, pairing records and key material are never exported.

Protected scanning additionally tests the existing MCM configuration and both
worse_query query flag configurations. These are three modes of the same class-7
App Group technique, not three independent vulnerabilities. Each lease is released
and the dedicated cache restored before the next attempt. All protected modes
require a legitimately provisioned App Group ending `.watchlink.probe`; a normal
IPA without that group reports them as skipped. Worse_query's watchOS support
is experimental and unverified. No entitlement is forged or added automatically.

Service lookup sends no protocol messages. Framework inspection invokes no pairing
methods. A reachable service or present method is not proof of authorization.
These results identify candidate routes for further native pairing research; they
do not implement concurrent companions or demonstrate preservation of pairing keys.

## Retrieve a Watch report

Open WatchLink on the paired iPhone and on the Watch. Tap **Get Watch report**
on the iPhone to request the Watch's own saved scan. The iPhone validates and
saves it before offering Copy/Share/Save. Reports up to 48 KiB use an immediate
reply; larger reports use the queued file channel. Watch Send report also offers
immediate messages and background application context for smaller reports.

Watch **Share report text** and **Share report file** use the native watchOS share
sheet independently of WatchLink's Watch Connectivity channel. Choose an available
service, then copy/save on the iPhone. A compact summary can also be read on the
Watch. Clipboard-style Copy is not implemented on watchOS. Transfers expose
session state and error domain/code. File transport completion is distinguished
from acknowledgement that the receiver validated and saved the report. Paired
physical devices are required to validate these transports.
