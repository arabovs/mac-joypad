# Joypad

Turn an iPhone into a Mac controller. Plug it in with USB‑C, open the page on the phone, and the D‑pad plus eight buttons type keys into whichever Mac app is focused.

| iPhone | Mac key |
| --- | --- |
| D‑pad | Arrow keys |
| Q W E R | Q W E R |
| A S D F | A S D F |

## Run it

```bash
./build.sh
open dist/Joypad.app
```

First launch, macOS may ask to allow incoming network connections — choose Allow.

## Use it

1. Open **Joypad** on the Mac.
2. Allow **Accessibility** when asked (System Settings → Privacy & Security → Accessibility → Joypad). Without this, the phone can connect but keys will not be injected.
3. Plug the iPhone in with USB‑C and tap **Trust**. Turn **Personal Hotspot off**.
4. On the Mac, click **Open Internet Sharing**. Share your connection from **Wi‑Fi** to **iPhone USB**, then turn Internet Sharing on.
5. On the iPhone, open **Safari** (not Chrome) to `http://192.168.2.1:7777`.
6. Click the game or app on the Mac so it is focused, then play.

Add the page to the iPhone Home Screen from Safari for a fullscreen controller.

## Notes

- Keys go to the frontmost Mac app, so click the game after opening the controller.
- Keep Joypad running while you play. A menu bar controller icon stays available if the window is closed.
- The USB cable can carry the controller page after Internet Sharing is enabled to **iPhone USB**. Use Safari and `http://192.168.2.1:7777`.
