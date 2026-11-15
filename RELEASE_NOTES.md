WatchLink 0.1.6 hardens the direct report transfer after a device send timeout.

TCP headers, payloads and acknowledgements are accumulated across partial reads. A final receipt is flushed before connection cancellation. Incorrect codes, rejected reports and route waits have distinct messages. Network.framework chooses the local route instead of forcing a physical Wi-Fi interface; cellular transport remains prohibited.

Real loopback TCP integration tests exercise a 65KB report, incorrect receiver code, rejected imports, a header/body split across writes, exact payload persistence and receipt acknowledgement. These tests do not prove physical Apple Watch routing or diagnose which weakness caused the user's timeout.

The iPhone rejects iOS reports as Watch transfers and provides Show saved Watch report. Exports use distinct Watch/iPhone filenames. Multi-phone pairing is not implemented. Physical phone/Watch transfer remains unverified.
