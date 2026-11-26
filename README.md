# AmiSnip

**Capture a screen area on AmigaOS 3.x, like Win+Shift+S**

AmiSnip is a small commodity that lets you capture any area of the screen with the mouse, the same way Windows does with Win+Shift+S.

- **Version:** 1.3
- **Requires:** AmigaOS 3.0+, 68000+; Picasso96 or CyberGraphX (`cybergraphics.library`) for RTG screens
- **Download:** [Aminet (util/cdity)](https://aminet.net/package/util/cdity/AmiSnip)

## How it works

Press the hotkey (**LAmiga + Shift + S** by default). The front screen freezes and gets darker. Drag a frame around the area you want: it is shown at full brightness, with its size in pixels next to it. You can move the frame or resize it with the handles before taking the picture.

When you confirm, a small floating menu appears next to the frame:

| Option | What it does |
|---|---|
| Copy to clipboard | Ready to paste with Amiga+V in any program |
| Save as... | Choose a drawer and a name; the extension picks the format (.iff .png .jpg .bmp .gif) |
| Open in MultiView | Opens the capture in the program you choose in the preferences (PPaint, MultiView...) |
| Format: PNG | File format for this capture (IFF, PNG, JPEG, BMP or GIF); starts with the one in the preferences and is used by Save as and Open in |
| Back | Return to the frame to change it |

It works with native screens (OCS/ECS/AGA, including EHB and HAM) and with RTG screens (Picasso96 / CyberGraphX, 8 to 32 bit).

## Installation

Double-click **Install-AmiSnip**. The installer copies the commodity to `SYS:WBStartup` (or another drawer you choose) and the preferences editor to `SYS:Prefs`, and can start AmiSnip straight away.

If you have AmiSnip 1.0 running, quit it from Exchange before installing.

## Capturing

| Action | Result |
|---|---|
| Drag with the left button | Draw a new frame |
| Drag inside the frame | Move it |
| Drag an edge or a handle | Resize it |
| Return / Enter | Confirm the frame |
| Double-click inside the frame | Confirm the frame |
| Return with no frame / F | Take the whole screen |
| Esc / right mouse button | Cancel |

In the floating menu you can also use the keys **C** (copy), **S** (save as), **O** (open), **F** (next format), **Return** (copy) and **Esc** (back).

Running AmiSnip again while it is already active starts a capture, so you can launch it from a dock or toolbar.

## Preferences (`SYS:Prefs/AmiSnipPrefs`)

| Setting | Description |
|---|---|
| AmiSnip enabled | Switch the hotkey on or off |
| Hotkey | Any commodities key description, e.g. `lcommand shift s` or `ctrl alt p` |
| Save drawer | Default drawer for the files |
| File format | IFF ILBM, PNG, JPEG, BMP or GIF |
| JPEG quality | 10 to 100 (default 85) |
| After capture | Show the menu, or go straight to: copy to clipboard / save to drawer / copy + save |
| Open with | Program used by "Open in..." |
| Dimming | None, light, medium or strong |
| Frame colour | White, yellow, cyan, red or green |
| Beep after capture | Confirmation beep |

**Save** stores the settings for good (`ENVARC:`), **Use** only until the next reboot (`ENV:`). AmiSnip picks up the changes immediately. The Project menu has About and Quit; the Edit menu can reset to the defaults or go back to the last saved settings.

You can also open the preferences with "Show" in Exchange.

From the CLI:

```
AmiSnip [QUIT] [CX_PRIORITY=<n>]
```

`QUIT` stops a running AmiSnip.

## Notes

**File formats**

- **IFF ILBM:** 24-bit (RTG) or with the screen palette (native).
- **PNG:** compressed (deflate), 24-bit or 8-bit indexed.
- **JPEG:** baseline, 4:4:4 (no colour subsampling, so text stays sharp), quality set in the preferences.
- **BMP:** 24-bit or 8-bit indexed, uncompressed.
- **GIF:** 8-bit. Native screens keep their palette; RTG captures with up to 256 colours keep them exactly, others use a 252-colour palette with ordered dithering.

The clipboard always gets IFF ILBM.

- On native screens the area outside the frame is dimmed using one extra bitplane. Screens with 256 colours, EHB, HAM or dual playfield have no spare plane, so they are shown without dimming (the frame and handles still work).
- HAM captures are converted to 24-bit for PNG, JPEG, BMP and GIF.
- "Open in..." saves the capture to `T:` first.
- A beep without the "Beep after capture" option means something failed: not enough memory, a drawer that does not exist, etc.

## Requirements

- AmigaOS 3.0 or newer (3.1, 3.2 and CaffeineOS are the targets), 68000+
- The About picture in the preferences needs OS 3.1 or newer
- For RTG screens: Picasso96 or CyberGraphX (`cybergraphics.library`)
- RTG captures need about 3 x width x height bytes of free memory twice (about 12 MB for 1920x1080)

## History

- **1.3** (22.11.2026) Format selector in the floating menu.
- **1.2.1** (21.11.2026) Moving the floating menu or the save requester no longer leaves grey trails on the frozen screen.
- **1.2** (21.11.2026) New formats: compressed PNG, JPEG (with quality setting), BMP and GIF. HAM captures can be saved in every format. New icons.
- **1.1** (21.11.2026) Floating menu after the capture (copy, save as, open in a program). Preferences editor with About. Installer. QUIT argument. "Show" in Exchange opens the preferences.
- **1.0** (21.11.2026) First release.

## Credits

Programmed in 68000 assembly by **Isra Ortuño (Gogeta) - Amigatronics**, with the help of Claude (Anthropic).

[amigatronics.com](https://amigatronics.com) · [en.amigatronics.com](https://en.amigatronics.com) · amigatronics@amigatronics.com

## License

Released under the [MIT License](LICENSE).
