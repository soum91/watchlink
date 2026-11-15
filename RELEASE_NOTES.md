WatchLink 0.1.7 corrects the Watch network API choice.

Apple TN3135 restricts raw Network.framework connections and Bonjour in ordinary watchOS apps. The previous raw-TCP Watch sender was therefore the wrong design, regardless of passing desktop tests. This release uses supported URLSession HTTP on Watch.

On iPhone start Wi-Fi receiver. On Watch enter the iPhone address:port and six-digit code, then Send report over HTTP. Bonjour discovery on Watch is no longer required. The receiver keeps the iPhone awake for its two-minute window, then restores its earlier idle setting. Private IPv4 destinations only; cellular transfers disabled; no cloud endpoint.

Native tests exercise actual URLSession HTTP through the production receiver, exact 65KB report persistence, rejected codes/imports and fragmented TCP framing. These checks do not prove physical Watch routing or permissions. Watch installation/transfer still needs a device retry. Multi-phone pairing remains unimplemented.
