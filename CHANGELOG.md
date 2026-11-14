# Changelog

## 0.1.1

- Give Copy, Share, and Save independent List-row button handling.
- Replace concurrent SwiftUI export/share sheets with one UIKit presentation flow.
- Save and share an immutable JSON file of the displayed report.
- Catch clipboard and export-controller Objective-C exceptions and show usable errors.
- Label reports as coming from iPhone or Watch and reopen the latest received report.
- Add simulator UI regression checks for Copy, Save, Share, and repeated export actions.
- Run iPhone UI checks on the stable simulator image with bounded setup commands; compile the Watch separately with Xcode 27.

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
