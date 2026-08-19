# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An [Omarchy](https://omarchy.org) plugin (Quickshell/QML) that provides macOS-style
modifier key remapping (Caps Lock, Control, Alt, Super) through XKB options. It has
no build system, package manager, or test suite — it's QML consumed directly by
Quickshell at runtime, plus one standalone Python script.

## Testing changes

There's no build/lint/test tooling in this repo. To verify changes:

- **Python backend** (`scripts/apply.py`) can be run standalone, independent of Quickshell:
  ```sh
  python3 scripts/apply.py get            # print current XKB modifier tokens as JSON
  python3 scripts/apply.py set ctrl:nocaps,caps:escape   # apply tokens, reload Hyprland
  python3 scripts/apply.py reset          # drop all managed tokens, reload
  ```
- **QML/UI changes** require reloading the plugin inside a live Omarchy session
  (`omarchy plugin reload io.github.sahzudin.modifier-keys` or restarting Quickshell) —
  there is no headless QML test runner here.
- **Model.js token logic** (`buildTokens` / `inferSelections` / `applyTarget`) is plain
  JS with a CommonJS export guard at the bottom (`module.exports = {...}`), so it can be
  required and exercised from plain `node` for quick round-trip checks without touching Qt.

## Architecture

**Two entry points share one UI.** `manifest.json` declares `kinds: ["panel",
"bar-widget"]` with `entryPoints.panel = Panel.qml` and `entryPoints.barWidget =
BarWidget.qml`. Both load `PanelContent.qml` (bar-anchored popup) or embed directly
(standalone centered panel), and both host the same `ModifierContent.qml` — that file
owns all state, keyboard navigation, and the apply/refresh logic. Panel.qml and
PanelContent.qml only differ in window chrome/anchoring (bar-attached popup vs.
centered overlay layershell surface).

**Data flow for a remap:**
1. `Model.js` defines `ROWS` — one entry per physical modifier key (Caps Lock, L/R
   Ctrl, L/R Alt, L/R Super), each with a list of `targets` (what it can become) and
   the XKB `token` each target emits (`null` = native behavior, untouched).
2. `ModifierContent.qml` holds `selections` (row id → target id) and calls
   `Model.buildTokens(selections)` to turn that into the token list to apply, or
   `Model.inferSelections(tokens)` to go the other way when reading live state.
3. Applying spawns `scripts/apply.py set <tokens>` as a `Quickshell.Io.Process`;
   refreshing spawns `scripts/apply.py get`. Both are async — see `onApplyResult`/
   `onState` in `ModifierContent.qml`.
4. `apply.py` reads/writes `kb_options` in `~/.config/hypr/input.lua`, preserving any
   token it doesn't manage (`MANAGED_RE` matches only `ctrl:*`, `altwin:*`, `caps:*`,
   `compose:caps`), then runs `hyprctl reload` and reports back whether the applied
   option actually matches what was written.

**Symmetric vs. one-directional tokens is the trickiest part of `Model.js`.** Some XKB
tokens affect only one row (e.g. `ctrl:lctrl_meta`), but swap tokens like
`altwin:swap_lalt_lwin` or `ctrl:swap_lwin_lctl` affect *two* rows at once and are only
emitted when both sides agree on the swap. `applyTarget()` pins/unpins the counterpart
row when a swap target is chosen/unchosen, then re-normalizes through
`inferSelections(buildTokens(s))` so the displayed selections always match what will
actually be applied — read the comments in `Model.js` before changing this logic, since
breaking the round-trip (`buildTokens` → `inferSelections` → same selections) causes UI
state to silently diverge from the applied XKB options.

**Keyboard navigation** (`j`/`k` rows, `h`/`l` targets, `Enter`/`Space` apply, `r`
refresh, `Esc` close) is driven by `PanelKeyCatcher` (from `qs.Ui`, not part of this
repo) wrapping the whole content; `ModifierContent.qml` just implements the
`onMoveRequested`/`onActivateRequested`/`onTextKey` handlers and tracks
`focusRow`/`focusPill`/`cursorActive`.

**External dependencies:** `qs.Ui` and `qs.Commons` (imported throughout the `.qml`
files) are Quickshell/Omarchy shell modules that live outside this repo — components
like `BarWidget`, `Panel`, `PanelContent`, `KeyboardPanel`, `CursorSurface`,
`BorderSurface`, `Button`, `Style`, `Color` are provided by the host shell, not defined
here.

**`install.sh`** is a separate concern from the plugin's QML/Python runtime — it does
the two things a manifest cannot express, and is idempotent so it can always be re-run:

1. Patches `~/.config/omarchy/extensions/omarchy-menu.jsonc` to add the menu row (a
   plugin can't inject menu rows; the shell merges exactly two sources, its defaults
   and that one user file), backing the original up to `omarchy-menu.jsonc.bak`. The
   file is JSONC — comments and trailing commas — so the merge strips comments with a
   small string-aware scanner, parses the result to decide what is already there, and
   inserts after the top-level `{` with a trailing comma. Appending before the final
   `}` instead is what the first version did, and it put the separator comma inside a
   trailing `//` comment whenever the file ended in one, silently invalidating the file
   (the menu's `onLoadFailed` then drops *all* the user's custom rows).
2. Repairs bar placement. Because the manifest declares both `panel` and `bar-widget`,
   `PluginRegistry.setEnabled` only inserts a `bar.layout` entry when `shell.json`
   mentions the id nowhere — so a leftover bare `plugins[]` entry makes `omarchy plugin
   enable` a no-op and `omarchy bar move` fail with `could not find widget`. The script
   reads `shell.json` with `jq` (not `omarchy plugin list`, whose `enabled` field for a
   bar-widget reports `inBar()`, not whether the plugin is referenced at all) and, if
   the id is referenced but absent from the bar, disables before re-enabling.

Note that the running shell writes `shell.json` from its in-memory copy, so editing
that file directly while the shell is up gets silently overwritten — drive it through
`omarchy plugin` / `omarchy bar`, which go through the shell's IPC.
