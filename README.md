# Modifier Keys

macOS-style modifier key remapping for Omarchy. Remap Caps Lock, Control,
Alt/Option, and Super/Command to each other from a small settings panel —
no manual config edits.

- Caps Lock → Control, Escape, Super, Menu, Hyper, Backspace, Compose, or Off
- Left/Right Control ↔ Left/Right Alt ↔ Left/Right Super (and Control → Meta)

It works through XKB options, the same mechanism Omarchy uses for its default
Alt/Win swap (`altwin:swap_lalt_lwin`): the panel writes `kb_options` into
`~/.config/hypr/input.lua` and reloads Hyprland so changes apply immediately.

## Install

Both steps are required — `omarchy plugin add` cannot do the second one.

```sh
omarchy plugin add https://github.com/sahzudin/omarchy-modifier-keys.git --enable
~/.config/omarchy/plugins/io.github.sahzudin.modifier-keys/install.sh
```

The plugin ships two entry points:

- **Panel** — a settings panel, summoned from the Omarchy menu.
- **Bar widget** — a keyboard icon (`  `) in the bar.

`install.sh` finishes what the plugin cannot do from its own manifest:

- adds the **Setup → Keyboard → Modifier Keys** row to the Omarchy menu (the
  menu reads its extension rows from one user file,
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`, which no plugin can
  contribute to — the original is kept as `omarchy-menu.jsonc.bak`);
- makes sure `shell.json` actually places the plugin in the bar, and repairs
  the stale-entry case described under [Troubleshooting](#troubleshooting).

It is safe to re-run; every step is a no-op once applied. Pass a section to
place the icon elsewhere: `install.sh center`.

If you would rather add the menu rows by hand, put these in
`~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"setup.keyboard": { "icon": "", "label": "Keyboard" },
"setup.keyboard.modifiers": {
  "icon": "",
  "label": "Modifier Keys",
  "action": "omarchy-shell shell summon io.github.sahzudin.modifier-keys '{}'"
},
```

then apply them with `omarchy-shell shell rescanPlugins && omarchy menu refresh`.

### Moving or removing the bar icon

```sh
omarchy bar move io.github.sahzudin.modifier-keys --section center
omarchy plugin disable io.github.sahzudin.modifier-keys   # removes the icon
```

Note that Omarchy has no "keep the plugin, drop just the icon" verb: because
the plugin declares the `bar-widget` kind, its bar entry is the same
`shell.json` reference that keeps the panel loadable, so disabling it turns off
the menu entry's panel too. Leave the icon in place if you want the menu row to
keep working.

## Troubleshooting

**No "Modifier Keys" row in the Omarchy menu.** `omarchy plugin add` does not
add menu rows — run `install.sh` (above), then `omarchy menu refresh`.

**No icon in the bar, even though the plugin is installed.** Check what
`shell.json` says:

```sh
omarchy plugin list | grep modifier-keys
```

If it reports `disabled` while `omarchy plugin enable` claims success and
changes nothing, an earlier install left a bare `plugins[]` entry for the id.
Omarchy's `enable` only inserts a bar entry when `shell.json` mentions the id
*nowhere*, so the stale entry makes it a silent no-op, and `omarchy bar move`
fails with `could not find widget` because the widget is not in the bar yet.
Clear it first:

```sh
omarchy plugin disable io.github.sahzudin.modifier-keys
omarchy plugin enable io.github.sahzudin.modifier-keys --section right
```

`install.sh` detects and repairs this automatically.

**Edits to `shell.json` get reverted.** The running shell writes that file from
its own in-memory copy, so hand edits made while it is running are overwritten.
Use the `omarchy plugin` / `omarchy bar` commands instead.

## Usage

Open the panel (bar icon, or menu) and pick a target for each key. Changes are
applied and reloaded live — press `Esc` or click outside to close.

- `j` / `k` move between modifier rows
- `h` / `l` move between the targets of a row
- `Enter` / `Space` apply the highlighted target
- `r` refresh from the live config
- **Restore defaults** resets to Omarchy's shipped default (Caps Lock as the
  Compose key, no swaps)

## How it works

Under the hood the plugin only manages the XKB modifier tokens it can produce
(`ctrl:*`, `altwin:*`, `caps:*`, and `compose:caps`). Every other option in
`kb_options` — `shift:...`, `grp:alts_toggle`, custom compose keys, and so on —
is preserved untouched. Removing the plugin leaves your `input.lua` as-is with
the last applied mapping.

```sh
scripts/apply.py get      # print current XKB modifier tokens as JSON
scripts/apply.py set ...  # replace managed tokens and reload Hyprland
scripts/apply.py reset    # drop all managed tokens and reload
```

## Notes

- Remapping Super changes every **Super + …** shortcut (launcher, workspaces,
  terminal, …) because those shortcuts follow the physical keys.
- Not every macOS mapping exists in XKB (for example Caps Lock → Option is not
  available), so the panel only offers the combinations XKB supports.
- XKB options apply at the keyboard-layout level; they affect all keyboards
  using the active layout.

## Remove

```sh
~/.config/omarchy/plugins/io.github.sahzudin.modifier-keys/uninstall.sh
omarchy plugin remove io.github.sahzudin.modifier-keys
```

Run the uninstaller first: it removes the rows that `install.sh` added to the
shared Omarchy menu. It leaves user-edited rows and a shared Keyboard parent
that still has other children intact. Removing the plugin alone cannot perform
this cleanup because its directory (including the uninstaller) is deleted.

## License

MIT — see [LICENSE](LICENSE).
