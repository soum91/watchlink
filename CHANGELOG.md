# Changelog

## [v0.1.6] - 2026-11-15

## Verified changes since v0.1.5

- Harden TCP report delivery and validate actual fragmented network transfers ([`852b3555`](https://github.com/soum91/watchlink/commit/852b3555865dceac9b3d493d03136a8e60eda5ca); `.github/workflows/release.yml`, `App/LocalReportLink.swift`, `App/Phone.swift`, and 6 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.5...v0.1.6)

## [v0.1.5] - 2026-11-15

## Verified changes since v0.1.4

- Add explicit local Wi-Fi Watch report delivery independent of companion association ([`31d76b71`](https://github.com/soum91/watchlink/commit/31d76b71b01faec3690b63b78cd9cf3161c9d35d); `App/LocalReportLink.swift`, `App/Phone.swift`, `App/Shared.swift`, and 7 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.4...v0.1.5)

## [v0.1.4] - 2026-11-15

## Verified changes since v0.1.3

- Read transfer metadata from the WCSessionFile object ([`f397a936`](https://github.com/soum91/watchlink/commit/f397a9360b996e0d426958caaad916461cd3ec11); `App/Shared.swift`)
- Retrieve Watch reports from iPhone; add acknowledged delivery and native Watch sharing ([`3e74ab9d`](https://github.com/soum91/watchlink/commit/3e74ab9d7ceb4f62525d955c933dee329c93d992); `App/Phone.swift`, `App/Shared.swift`, `App/Watch.swift`, and 4 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.3...v0.1.4)

## [v0.1.3] - 2026-11-14

## Verified changes since v0.1.2

- Bound storage findings and preserve Watch report transfer size limits ([`1b001dd8`](https://github.com/soum91/watchlink/commit/1b001dd890625ba8ede7554ceb383d32859280d9); `Native/Probe.m`)
- Add worse_query query modes and bounded multi-pairing access investigation ([`2a359a61`](https://github.com/soum91/watchlink/commit/2a359a616f421b2f1c6b24eba4d51f4d224d3a7d); `.github/workflows/release.yml`, `Native/Probe.m`, `README.md`, and 5 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.2...v0.1.3)

## [v0.1.2] - 2026-11-14

## Verified changes since v0.1.1

- Build 0.1.2 using Xcode metadata, modern Watch layout and optional App Groups ([`a4c007ef`](https://github.com/soum91/watchlink/commit/a4c007ef9ff35eb0a51b5d75732ecb6a8f69c526); `.github/workflows/release.yml`, `README.md`, `RELEASE_NOTES.md`, and 8 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.1...v0.1.2)

## [v0.1.1] - 2026-11-14

## Verified changes since v0.1.0

- Publish native probe fixes with explicit partial UI validation; retain manual UI suite ([`b3fc369b`](https://github.com/soum91/watchlink/commit/b3fc369bade0060de66106c53308036ffa92a371); `.github/workflows/release.yml`, `RELEASE_NOTES.md`, `VALIDATION.md`)
- Dismiss identified first-use keyboard tutorial before testing Files cancellation ([`9bae6369`](https://github.com/soum91/watchlink/commit/9bae636920024530e018dac8638b3ec4fe3c0f13); `tests/ui/ReportActionsTests.swift`)
- Match native share-sheet and document-picker accessibility elements ([`3e4e97c7`](https://github.com/soum91/watchlink/commit/3e4e97c7c0e316dcb4fd10150a4a23399aa10123); `tests/ui/ReportActionsTests.swift`)
- Allow cold simulator builds to finish; build native packages in parallel ([`aac6979a`](https://github.com/soum91/watchlink/commit/aac6979acea2405ef93efc8f60c8734338819cfc); `.github/workflows/release.yml`, `VALIDATION.md`, `scripts/ui_smoke.py`, and 1 more)
- Use stable iPhone simulator checks with bounded setup and separate Watch build ([`0a89545c`](https://github.com/soum91/watchlink/commit/0a89545cd17a012c578868ab49c7a1fcd75861ec); `.github/workflows/release.yml`, `scripts/ui_smoke.py`, `tests/ui/ReportActionsTests.swift`)
- Fix independent report actions, guard exports, and add simulator regression checks ([`fdfc2def`](https://github.com/soum91/watchlink/commit/fdfc2def8f0aac3a1c54f1c22cfdcba12371b072); `.github/workflows/release.yml`, `App/Phone.swift`, `App/Shared.swift`, and 8 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/compare/v0.1.0...v0.1.1)

## [v0.1.0] - 2026-11-13

## Verified changes since project start

- Restrict document exporter to iOS so the Watch target compiles ([`cd0410aa`](https://github.com/soum91/watchlink/commit/cd0410aafbfa0e0fbaddb9a9ee576bb8fe915752); `App/Shared.swift`)
- Use dedicated Xcode 27 runner for native Watch build ([`8c9ec4bf`](https://github.com/soum91/watchlink/commit/8c9ec4bf34b3f137ed70c4c802c411213520692c); `.github/workflows/release.yml`)
- Add WatchLink pairing access probe, companion apps, and release pipeline ([`5524154e`](https://github.com/soum91/watchlink/commit/5524154e5b0ef8a73abf96ba37ee0c8a985cfdd6); `.github/workflows/release.yml`, `.gitignore`, `App/Phone.swift`, and 25 more)

[Inspect exact code changes](https://github.com/soum91/watchlink/commits/v0.1.0)

## 0.1.10

- Invoke the NRPairedDeviceRegistry paired-device query selectors (sharedInstance, getPairedDevices, getDevices, getActivePairedDevice) read-only, reporting only call outcome, nil/thrown status, result and element class names, array counts, and the active device's property names. No property values, identifiers, names, serials, or key material are read or exported, and nothing is modified.
- Add registryInvocationSurvey to the iPhone and Watch reports alongside the existing availability-only registryAPISurvey.

## 0.1.9

- Advertise a short-lived iPhone report receiver using Core Bluetooth; Watch scans the dedicated service and lists nearby receiver names without IP or PIN entry.
- Transfer reports directly over acknowledged Bluetooth writes, independent of Watch Connectivity registration and local Wi-Fi routing. Remember the last successfully selected receiver for automatic selection next time.
- Bound frames and report assembly to 128 KiB and acknowledge the final commit only after report validation and persistence. Include framing tests at small and large negotiated write lengths, malformed messages, incomplete reports, and overflow.
- Add Bluetooth permission descriptions and foreground permission/power/error states. Keep manual HTTP entry as an optional fallback.
- Native multi-pairing is not implemented. Bluetooth framing is tested in CI; physical iPhone/Watch discovery and transfer remain unverified.

## 0.1.8

- Get Watch report opens the direct HTTP receiver when Watch Connectivity is unavailable, times out, or returns a transfer error. A stale installed-app flag no longer blocks a reachable session.
- Send report on Watch opens the existing Wi-Fi sender when the companion is unreachable, and after companion transport failures.
- Put receiver address, code, and saved-report receipt beside Get Watch report; remove the unproven reinstall instruction and keep receipt confirmation separate from connectivity flags.
- Preserve the active receiver code across repeated requests and use borderless receiver controls to prevent a List-row tap from dispatching multiple button actions.
- Physical Watch delivery and native multi-pairing remain unverified; this release does not implement another native pairing.

## 0.1.7

- Replace the Watch raw TCP sender with URLSession HTTP, following Apple TN3135 restrictions on ordinary watchOS apps.
- Remove Bonjour discovery from the Watch flow; display the receiver private IPv4 address and port on iPhone for entry on Watch.
- Add bounded HTTP parsing and URLSession end-to-end transport tests alongside TCP framing tests.
- Keep the iPhone awake during the two-minute receiver window and restore its previous idle setting afterward.
- Limit the Watch HTTP destination to explicitly entered private IPv4 addresses; add Watch-only ATS settings required for local cleartext HTTP.

## 0.1.6

- Accumulate TCP headers, bodies and receipts across fragmented reads instead of assuming a single complete read.
- Send a final receipt and allow it to flush before closing; distinguish PIN rejection, invalid reports and connection errors.
- Remove the forced Wi-Fi interface requirement while prohibiting cellular transport; allow local routes selected by Network.framework.
- Add real loopback TCP integration checks for a 65KB report, wrong PIN, rejected import and fragmented framing.
- Reject iPhone payloads as Watch reports, add Show saved Watch report, and export platform-specific filenames.

## 0.1.5

- Add user-started local Wi-Fi report transfer independent of Watch Connectivity association.
- Discover the iPhone receiver through Bonjour and require its short-lived 6-digit code before importing a report.
- Bound receiver lifetime, attempts, concurrent connections and report/frame sizes; acknowledge only after validation and persistence.
- Keep normal Watch Connectivity transfer and native sharing as alternatives.

## 0.1.4

- Let the iPhone request the saved Watch report directly while both apps are open.
- Add immediate delivery and application-context fallback alongside immutable queued file snapshots.
- Confirm report receipt after validation and local persistence; retain actionable error domain/code and session state.
- Add native Watch Share actions for full report text and a plain-text file, plus a compact on-watch summary.

## 0.1.3

- Compare legacy MCM flags with worse_query default and alternate query modes using separate token, access, and restoration results.
- Survey seven additional pairing/container candidates, with bounded enumeration and redacted known-component storage discovery.
- Inspect pairing-related Mach service lookup reachability without sending messages.
- Inspect NanoRegistry framework and selector availability without invoking pairing APIs.
- Preserve default App Group-free installation; protected modes remain explicitly provisioned and experimental on watchOS.

## 0.1.2

- Build iPhone and Watch apps through Xcode/XcodeGen instead of hand-writing installation metadata.
- Use the modern PlugIns Watch companion layout and Xcode-generated icon catalogs.
- Remove the unprovisioned placeholder App Group from default IPA signatures; keep it as an explicit opt-in signing template.
- Add a phone-only diagnostic IPA to distinguish host installation from companion validation.
- Validate universal watchOS executables and default entitlement requirements.

## Distribution updates

- Add a FlareStore source for the published combined iPhone + Watch IPA.
- Update the feed after successful releases using real asset sizes, native versions/builds, and retained version history.

## 0.1.1

- Give Copy, Share, and Save independent List-row button handling.
- Replace concurrent SwiftUI export/share sheets with one UIKit presentation flow.
- Save and share an immutable JSON file of the displayed report.
- Catch clipboard and export-controller Objective-C exceptions and show usable errors.
- Label reports as coming from iPhone or Watch and reopen the latest received report.
- Add simulator UI regression checks for Copy, Save, Share, and repeated export actions.
- Add bounded simulator checks through manual workflow dispatch; release builds require native compilation and real-artifact checks.
- Handle system share-sheet accessibility and the simulator keyboard tutorial in UI tests. Record partial UI results and pending physical validation.

## 0.1.0

- Name the project WatchLink, without a fixed phone-count promise.

- Add iPhone and Watch pairing-storage access probes.
- Add optional bounded MCM App Group symlink probing with recovery journal and cache restoration.
- Separate extension acquisition from actual access and cleanup results.
- Add metadata-only reports, WatchConnectivity transfer, Copy, Share, and Files export.
- Add installed version/build, a native icon, rootless packaging, and automated Sileo index generation.
- Select the dedicated Xcode 27 runner for the Watch SDK.
- Keep the iPhone document-export type out of the watchOS target.
- Add real-artifact validation and checksummed GitHub prereleases.
- Dual pairing and phone switching are not implemented; device execution remains unverified.
