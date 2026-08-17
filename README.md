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

```sh
omarchy plugin add https://github.com/sahzudin/omarchy-modifier-keys.git --enable
```

The plugin ships two entry points:

- **Panel** — a standalone settings panel, summoned from the Omarchy menu.
- **Bar widget** — an optional keyboard icon (`  `) in the bar.

### Add the menu entry

The Omarchy menu reads its extension rows from a single user file, so run the
bundled installer to merge in the **Setup → Keyboard → Modifier Keys** entry:

```sh
~/.config/omarchy/plugins/io.github.sahzudin.modifier-keys/install.sh
omarchy-shell shell rescanPlugins && omarchy menu refresh
```

Or add these rows to `~/.config/omarchy/extensions/omarchy-menu.jsonc` by hand:

```jsonc
"setup.keyboard": { "icon": "", "label": "Keyboard" },
"setup.keyboard.modifiers": {
  "icon": "",
  "label": "Modifier Keys",
  "action": "omarchy-shell shell summon io.github.sahzudin.modifier-keys '{}'"
},
```

### Bar widget (optional)

Place it in the bar, or enable it anywhere with:

```sh
omarchy plugin enable io.github.sahzudin.modifier-keys
omarchy bar move io.github.sahzudin.modifier-keys --section right
```

Remove it from the bar with `omarchy bar move io.github.sahzudin.modifier-keys --reset`
or disable the plugin.

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
omarchy plugin remove io.github.sahzudin.modifier-keys
```

## License

MIT — see [LICENSE](LICENSE).