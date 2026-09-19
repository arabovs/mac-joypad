# Joypad

Turn an iPhone into a Mac controller. Open the pad in Safari, then use the D‑pad and buttons on the phone. Cursor and other Mac apps get typed keys. OpenEmu games need Karabiner’s virtual keyboard (see below).

| iPhone | Mac key |
| --- | --- |
| D‑pad | Arrow keys |
| Q W E R | Q W E R |
| A S D F | A S D F |
| Select / Start | J / K |

## Run locally

From the project folder:

```bash
cd /path/to/joypad
./build.sh
open /Applications/Joypad.app
```

`./build.sh` compiles a release app, copies it to `dist/Joypad.app` and `/Applications/Joypad.app`, and ad-hoc signs it. The first build clones Karabiner VirtualHIDDevice headers into `vendor/` (gitignored). You need Xcode Command Line Tools (`clang++`, `swift`).

Always launch **`/Applications/Joypad.app`** after a rebuild (or `open dist/Joypad.app`). macOS may ask to allow incoming network connections — choose Allow.

Rebuilds change the code signature, so Accessibility may need to be granted again for that copy of Joypad.

## Use it

1. Open **Joypad** on the Mac.
2. Allow **Accessibility** (System Settings → Privacy & Security → Accessibility → Joypad). The window has **Open Accessibility settings**.
3. Pick **Wi‑Fi** or **Cable** in the app.

**Wi‑Fi:** iPhone and Mac on the same network, Personal Hotspot off. Open **Safari** to the `http://` link shown in Joypad (Chrome hangs if it upgrades to https).

**Cable:** plug in USB‑C and tap Trust. Personal Hotspot off. On the Mac, **Open Internet Sharing**, share Wi‑Fi to **iPhone USB**, turn Internet Sharing on. On the iPhone, Safari to `http://192.168.2.1:7777`.

4. Click Cursor, TextEdit, or the game so it is focused, then use the phone.

Add the page to the iPhone Home Screen from Safari for a fullscreen controller.

## OpenEmu

OpenEmu’s running game ignores fake Mac keystrokes. Joypad talks to **Karabiner-Elements**’ virtual HID keyboard instead.

1. Install [Karabiner-Elements](https://karabiner-elements.pqrs.org/) and allow its system extension. You do not need remaps.
2. In Joypad, click **Allow HID helper** and enable it in Login Items (admin password once). Wait until the chip says **OpenEmu keyboard live**.
3. In OpenEmu, keep **Input = Keyboard** with the bindings above. Grant **OpenEmu** Input Monitoring if it asks.

## Notes

- Keys go to the frontmost Mac app, so click the game after opening the controller.
- Keep Joypad running while you play. A menu bar controller icon stays available if the window is closed.
- Use Safari and `http://`. Chrome’s HTTPS-First mode will hang on the pad page.
