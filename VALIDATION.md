# Validation

Preparation check on 2026-11-13: all six distribution tests passed. Python source
compilation and shell syntax validation passed. Native build and Debian packaging
correctly refused to generate artifacts without macOS/Xcode and a real executable.

The source preparation environment has no iOS/watchOS SDK. Native compilation
has not been performed. No device has executed the app; all runtime behavior is
unverified.

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
