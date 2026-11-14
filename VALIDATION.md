# Validation

## 0.1.1 report-action regression coverage

Manual workflow dispatch runs actual iOS simulator UI tests for independent Copy,
Save, and Share actions, document-picker cancellation, repeated Save, and continued
foreground execution. Native clipboard/export creation is guarded against
Objective-C exceptions, and export input is a saved JSON snapshot. CI results must be checked in the associated run; release publication is gated by
native compilation and real-artifact checks, not a simulator pass. Physical Dopamine iOS 16.1.1 and
watchOS behavior still require device verification.

Preparation check on 2026-11-13: all six distribution tests passed. Python source
compilation and shell syntax validation passed. Native build and Debian packaging
correctly refused to generate artifacts without macOS/Xcode and a real executable.

The local source preparation environment has no iOS/watchOS SDK. Release 0.1.0
compiled and passed real-artifact checks on GitHub Actions run 43515623611.
For 0.1.1, simulator compilation passed in run 43536962906, but the cold build
exceeded its time limit before UI execution; this does not count as a UI pass.
No physical-device runtime result is verified by the build workflow.

Distribution tests cover empty repository rejection, incorrect architecture,
unsupported versions, malformed Mach-O commands, phone/Watch platform metadata,
and consistency of actual Debian bytes with index and Release hashes. Disposable
test packages contain no app executable and are never distributed.

The release workflow must compile both apps, verify real arm64 executable
platforms and versions, verify IPA signatures, check rootless package layout,
and checksum actual artifacts before publishing.

Hardware validation must cover normal/protected scan results, denied access,
cache restoration and interrupted-operation recovery, report transfer, Copy,
Share, Files export, and continued operation of the current pairing. Record app
version/build and device model/build without exposing identifiers or secrets.

Observed 0.1.1 results on 2026-11-14:

- Native builds and real-artifact checks passed in runs 43538200017, 43539272166,
  and 43540613238.
- Copy and Share passed on iOS 26.4.1 in run 43539272166.
- Save opened the document picker without terminating the app. Cancellation failed
  with the simulator's first-use keyboard tutorial covering the controls.
- Test-only handling for the identified tutorial was committed. Run 43540613238
  subsequently stalled after simulator data-migration failure; no revised UI pass
  is claimed.
- Physical iOS 16.1.1 Copy/Save behavior and all Watch runtime behavior still need
  verification. Multi-phone pairing is not implemented.

## 0.1.2 installation packaging investigation

The 0.1.1 release IPA was inspected directly (SHA-256 c32505982b877f1c6005c8a7d423a57250519d14b291f6b4af3e299d6025eafa).
Both executables request the placeholder App Group. The host minimum is iOS 16.0
and the Watch minimum is watchOS 27.0 in both Info.plist and LC_BUILD_VERSION.
Those deployment values do not by themselves explain an installation rejection on 27.2.

Compared with the released WristPane 0.1.17 artifact, WatchLink had hand-written
SDK/bundle metadata, legacy WatchKit app metadata, and the older Watch/ embedding
layout. The new package delegates metadata and assets to Xcode and uses PlugIns/.
Default sideload signatures request no App Groups. A phone-only diagnostic IPA
is included to isolate iPhone installation from companion bundle validation.

Seven local distribution checks pass. Native build and archive verification must
pass in CI before publication. No physical iPhone 17 installation result or
device-side installation error has been collected; the root cause of the reported
stall remains unconfirmed.
