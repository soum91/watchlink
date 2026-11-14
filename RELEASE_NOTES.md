WatchLink 0.1.1 fixes report export controls.

- Copy, Share, and Save now handle taps independently.
- A single presentation flow prevents overlapping share and document-picker sheets.
- Save and Share use a JSON snapshot of the displayed report.
- Clipboard/controller exceptions produce an error instead of escaping into Swift.
- The report identifies its source as iPhone or Watch, and the latest received report survives relaunch.

This release remains an access probe; multi-phone pairing is not implemented.
Sileo installs the iPhone companion. Watch IPAs need signing and the protected
Watch probe needs its provisioned App Group. Physical iOS 16 jailbreak behavior
still requires user verification; simulator checks do not establish device behavior.
