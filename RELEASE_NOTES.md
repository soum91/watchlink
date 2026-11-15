WatchLink 0.1.10 invokes the NanoRegistry paired-device query API read-only.

- The report now calls NRPairedDeviceRegistry sharedInstance and its getPairedDevices, getDevices, and getActivePairedDevice selectors instead of only checking that they exist.
- For each call it records whether it was invoked, returned nil, or threw, plus result and element class names and array counts. For the active paired device it records the class name and its property names only.
- No property values, device identifiers, names, serials, filenames, or key material are read or exported. No pairing records, daemons, MobileGestalt, or keychain values are changed.
- The earlier availability-only registryAPISurvey is retained; registryInvocationSurvey is the new invoking section.

The release tests framing and compiles both app targets. On a normal sandbox these selectors are expected to return nil or throw unless the signature carries the required NanoRegistry entitlements; that outcome is itself the result. Physical Watch behavior and any non-nil return remain unverified. Native multi-pairing is not implemented.

Update the combined package through EmberSign 0.2.97 or later.
