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

Validation: native iPhone/watchOS compilation and real IPA/rootless package checks
passed. On the iOS 26.4.1 simulator, Copy and Share passed and Save opened without
crashing. The repeated Save/cancellation test did not pass: the simulator's first-use
keyboard tutorial blocked Cancel. A revised test handles that tutorial, but its run
stalled after simulator data-migration failure, before test execution. The full UI
suite is therefore unverified and is available through manual workflow dispatch.
Retry Copy and Save on the physical Dopamine iOS 16.1.1 phone after updating.
