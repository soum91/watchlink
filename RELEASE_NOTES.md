WatchLink 0.1.9 adds nearby iPhone discovery and direct Bluetooth report transfer.

- On iPhone, Get Watch report arms a 2-minute Bluetooth receiver when Watch Connectivity is unavailable.
- On Watch, Send report opens a nearby-iPhone picker. Choose the matching receiver name; report bytes transfer over Bluetooth with a persisted receipt. The last successful receiver is selected automatically on the next explicit send.
- No IP or PIN entry is needed for this Bluetooth route. Manual HTTP is retained as a fallback. Both apps must remain open and Bluetooth access must be allowed.
- Reports are capped at 128 KiB; malformed and incomplete streams are rejected, and the final write is acknowledged only after saving. No pairing records or keys are changed.

The release tests framing and compiles both app targets. Physical Watch discovery/transfer remains unverified. Native multi-pairing and companion registration repair are not implemented.

Update the combined package through EmberSign 0.2.97 or later.
