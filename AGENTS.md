# Project rules

- This release is a pairing-access probe. Never call it working dual pairing.
- Do not change pairing records, MobileGestalt, daemons, or keychain values.
- No unpairing, erasing, or exporting private keys in the probe.
- Protected probing is user initiated and only changes its dedicated App Group cache temporarily.
- Reports must exclude personal identifiers, filenames, keychain values, and secrets.
- Display installed x.y.z version and build in every app.
- Every release requires concrete CHANGELOG entries and checksummed real artifacts.
- Distinguish compilation, packaging validation, and physical device execution.
- Retain upstream license notices. Use aliases in new authorship, never the user's legal name.

## Mandatory factual release and diagnostic export policy

All releases must describe specific verified changes since the preceding release, cite real commits and diffs, and reconcile GitHub Release notes with CHANGELOG.md. Generic claims or invented features are prohibited. Rebuild-only releases must identify exact packaging, toolchain, signing or artifact differences. Keep release-event and scheduled checks enabled and never suppress failed factual audits.

Every diagnostic/log report must offer Copy with clipboard read-back verification and visible success/failure feedback, native Share sheet, Save as plain-text `.txt` via Files picker (`fileExporter` or `UIDocumentPickerViewController` on iOS), and selectable full text as fallback. No silent clipboard-only actions. Include app/version, device/OS and actionable return/error codes; redact secrets and personal identifiers. Verify cross-app paste and Share/Files on a signed device, otherwise explicitly mark unverified. Preserve all existing safety and release rules.
