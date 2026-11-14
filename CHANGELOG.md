# Changelog

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
