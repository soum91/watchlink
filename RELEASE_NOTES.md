WatchLink 0.1.2 rebuilds the installation package through Xcode.

- Xcode now produces platform, SDK, deployment, bundle, and compiled icon metadata.
- The Watch companion uses the modern PlugIns layout, matching the WristPane package layout.
- Default sideload signatures no longer request an unprovisioned placeholder App Group.
- The combined IPA remains the FlareStore download. A separate WatchLinkPhone IPA isolates iPhone installation if the combined install still stalls.
- Protected scanning remains optional and needs a separately provisioned App Group.

This addresses packaging differences found while investigating an iPhone 17 installation stall. The stall's device-side error was not available, so no single cause or successful physical installation is claimed. Native compilation and package validation are distinct from device installation. Multi-phone pairing is not implemented.
