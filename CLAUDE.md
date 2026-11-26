# Claude instructions

Read and follow AGENTS.md in full. Preserve WatchLink's read-only pairing probe safeguards, privacy restrictions and existing changelog history.

## Mandatory factual release and diagnostic export policy

All releases must describe specific verified changes since the preceding release, cite real commits and diffs, and reconcile GitHub Release notes with CHANGELOG.md. Generic claims or invented features are prohibited. Rebuild-only releases must identify exact packaging, toolchain, signing or artifact differences. Keep release-event and scheduled checks enabled and never suppress failed factual audits.

Every diagnostic/log report must offer Copy with clipboard read-back verification and visible success/failure feedback, native Share sheet, Save as plain-text `.txt` via Files picker (`fileExporter` or `UIDocumentPickerViewController` on iOS), and selectable full text as fallback. No silent clipboard-only actions. Include app/version, device/OS and actionable return/error codes; redact secrets and personal identifiers. Verify cross-app paste and Share/Files on a signed device, otherwise explicitly mark unverified. Preserve all existing safety and release rules.

## Mandatory cross-project file picker standard

**RELEASE-BLOCKING:** Follow [MANDATORY_FILE_PICKER.md](https://github.com/soum91/tweaks/blob/main/MANDATORY_FILE_PICKER.md) and this repository's AGENTS.md for every existing and future importer, exporter, signer, browser and file picker. A picker that merely opens but ignores a file tap is broken. Require end-to-end real-device selection/import verification before claiming a fix; preserve security scope and asynchronous staged files; report actionable failures. Propagate this requirement to every new app. Do not weaken existing policies.
