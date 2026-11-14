# Third-party notices

The class-7 MCM app-group cache symlink access strategy in Native/Probe.m is
adapted from these MIT-licensed projects:

- Gester, KAMUI contributors: https://github.com/sasobhabha/Gester
- HermesEnabler 2, Jinwoo Kim: https://github.com/pookjw/HermesEnabler

The original notices are retained in licenses/. The adaptation limits targets,
exports no secrets, checks symbols dynamically, and journals its temporary own-cache changes.

Research references, not incorporated source:

- https://github.com/34306/watched
- https://legizmo.app/
- https://github.com/seemoo-lab/watchwitch
- https://github.com/LordixDemon/apple_watch_connector
- https://support.apple.com/guide/security/secc7d85209d/web

These projects do not endorse WatchLink or establish dual pairing support.

The additional query configurations (0x8000000000 and 0x800000000) were
verified against forcequitOS/worse_query:
https://github.com/forcequitOS/worse_query/blob/main/worse_query/worse_query.m
The upstream PoC is GPL-3.0-or-later. Its source is not bundled here; WatchLink
uses the existing independently adapted, journaled MCM implementation with these
API configuration values. Upstream destructive cache cleanup is not used.
