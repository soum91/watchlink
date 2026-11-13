WatchLink 0.1.0 is an experimental pairing-storage access probe, not dual pairing.

- iPhone companion and Watch app with user-initiated access checks.
- Optional bounded MCM protected-path probe with own-cache restoration.
- Metadata reports with Watch transfer, Copy, Share, and Files export.
- Rootless companion packaging and a Sileo index generated only from real packages.

IPAs need personal signing. Protected Watch probing needs a provisioned dedicated
App Group ending `.watchlink.probe`. Sileo installs only the iPhone companion.

Physical execution, watchOS 27.2 pairing-state access, key preservation, and phone
switching remain unverified. Pairing records and MobileGestalt are never changed.
