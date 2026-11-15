WatchLink 0.1.4 repairs report retrieval paths.

The iPhone app now has Get Watch report. Open WatchLink on the Watch and request its saved report from the paired iPhone. Watch Send report attempts immediate messaging and background application context as well as an immutable file snapshot. Receipt acknowledgement follows validation and local persistence. Connection state and error domain/code replace the generic failure alone.

The Watch also offers native Share report text, Share report file (.txt), and a compact readable summary. watchOS has no iPhone-style clipboard button here; share to an available service and copy on the phone. Physical transport and sharing require device verification.

The supplied 0.1.3 report was from iOS 27.2, with protected modes skipped for missing App Group provisioning and sandbox-denied file access. It was not the Watch report. Multi-phone pairing remains unimplemented.
