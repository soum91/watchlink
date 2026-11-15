# Changelog

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
