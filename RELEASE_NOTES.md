WatchLink 0.1.8 fixes the report workflow when Watch Connectivity does not recognize the companion.

- Get Watch report starts the short-lived Wi-Fi receiver on unavailable, timed-out, or failed companion requests.
- Send report on Watch opens the Wi-Fi form when the normal companion route is unavailable.
- Keep the address, code, saved receipt, and transfer controls together; preserve the active code across repeated requests and prevent automatic List buttons from starting and stopping the receiver together.
- Remove the unsupported reinstall diagnosis. Native companion registration is still unresolved, and physical Watch HTTP delivery remains unverified. Multi-pairing is not implemented.

Re-sign the combined iPhone + Watch IPA through EmberSign 0.2.97 or later. The phone-only IPA and Sileo package do not contain the Watch companion.
