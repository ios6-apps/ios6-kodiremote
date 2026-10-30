# Third-party notices

KodiRemote contains no third-party source code or libraries. Everything under `src/` is original and covered by the
[MIT licence](LICENSE); there is no `third_party/` directory.

Things that are used but not distributed with this repository:

- **iOS SDK headers and stub libraries.** Building for a real device links against Apple's iOS 9.3 SDK (stubs are enough).
  The SDK is Apple's property, subject to the Xcode and Apple SDKs Agreement, and is not part of this repository.
  `tools/setup-sdk.sh` downloads the public copy from [theos/sdks](https://github.com/theos/sdks) on your machine.
- **Python packages** (only for `make_assets.py`): [Pillow](https://python-pillow.org/), installed by you. The mock server
  `tools/mock_kodi.py` and the tests use the Python standard library only.

"Kodi" and "XBMC" are trademarks of the XBMC Foundation (Kodi Foundation). This project is an independent remote control
for Kodi's public JSON-RPC interface and is not affiliated with or endorsed by that foundation.
