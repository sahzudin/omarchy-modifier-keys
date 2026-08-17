#!/usr/bin/env bash
set -euo pipefail

# Finishes the install that `omarchy plugin add` can't do on its own:
#
#   1. Adds "Setup > Keyboard > Modifier Keys" to the Omarchy menu. The menu
#      reads its extension rows from a single user file
#      (~/.config/omarchy/extensions/omarchy-menu.jsonc), so a plugin cannot
#      inject rows by itself — this merges them in. The original file is kept
#      as omarchy-menu.jsonc.bak on first run.
#   2. Makes sure the plugin is actually referenced in shell.json. Without a
#      reference the shell never loads it, so neither the panel nor the bar
#      icon exist.
#
# Safe to re-run: every step is a no-op once it has been applied.
#
# Run from the plugin folder:
#   ~/.config/omarchy/plugins/io.github.sahzudin.modifier-keys/install.sh

PLUGIN_ID="io.github.sahzudin.modifier-keys"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BAR_SECTION="${1:-right}"

# ---------------------------------------------------------------- menu rows

python3 - "$MENU_FILE" "$PLUGIN_ID" <<'PY'
import json
import os
import re
import shutil
import sys

path, plugin_id = sys.argv[1], sys.argv[2]

ROWS = [
    ("setup.keyboard", {"icon": "", "label": "Keyboard"}),
    ("setup.keyboard.modifiers", {
        "icon": "",
        "label": "Modifier Keys",
        "description": "Remap Caps Lock, Control, Alt, and Super",
        "action": "omarchy-shell shell summon %s '{}'" % plugin_id,
    }),
]


# The menu file is JSONC: comments and trailing commas are legal, and the
# stock file omarchy ships is *only* comments. Blindly appending before the
# final "}" gets the separator wrong (a "," at the end of a comment line is
# inside the comment, so it neither counts as one nor can be relied on),
# which is how a hand-rolled merge silently produces invalid JSON. Strip the
# comments first, and decide from the parsed object instead of from the text.
#
# Returns the comment-free text plus the index, in the *original* text, of the
# top-level "{" — the one row insertion has to happen after.
def scan(text):
    out, i, n, in_string, brace = [], 0, len(text), False, None
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
        elif c == '"':
            in_string = True
            out.append(c)
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
        else:
            if c == "{" and brace is None:
                brace = i
            out.append(c)
            i += 1
    return "".join(out), brace


content = ""
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as handle:
        content = handle.read()
if not content.strip():
    content = "{\n}\n"

bare, brace = scan(content)
try:
    existing = json.loads(re.sub(r",(\s*[}\]])", r"\1", bare.strip()) or "{}")
except ValueError as error:
    sys.exit("%s is not valid JSONC (%s) — fix it, then re-run." % (path, error))
if brace is None or not isinstance(existing, dict):
    sys.exit("%s is not a JSONC object — fix it, then re-run." % path)

missing = [(key, row) for key, row in ROWS if key not in existing]
if not missing:
    print("Menu entries already present.")
    sys.exit(0)

insert_at = brace + 1

block = "".join(
    "\n  %s: %s," % (json.dumps(key), json.dumps(row, indent=2, ensure_ascii=False)
                     .replace("\n", "\n  "))
    for key, row in missing
)
# A trailing comma is legal JSONC, so the block always ends with one and the
# separator is correct whether or not entries already follow it.
rest = content[insert_at:]
new_content = content[:insert_at] + block + ("" if rest.startswith("\n") else "\n") + rest

backup = path + ".bak"
os.makedirs(os.path.dirname(path), exist_ok=True)
if os.path.exists(path) and not os.path.exists(backup):
    shutil.copy(path, backup)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(new_content)

print("Added %s to %s" % (", ".join(key for key, _ in missing), path))
PY

# ------------------------------------------------------------- shell.json

# `omarchy plugin list` reports a plugin that declares `bar-widget` as enabled
# only when it sits in the bar, and `omarchy plugin enable` is a no-op when
# shell.json already mentions the id anywhere (say a stale `plugins[]` entry
# left by an earlier install) — so it can neither report nor fix "referenced,
# but not in the bar". Ask shell.json directly, and clear the stale entry
# first so enable has somewhere to put the widget.
referenced=false
in_bar=false
if [[ -f $SHELL_CONFIG ]] && command -v jq >/dev/null; then
  referenced=$(jq -r --arg id "$PLUGIN_ID" '
    ((.plugins // []) + ((.bar.layout // {}) | to_entries | map(.value[]?)))
    | any(.id == $id)
  ' "$SHELL_CONFIG")
  in_bar=$(jq -r --arg id "$PLUGIN_ID" '
    ((.bar.layout // {}) | to_entries | map(.value[]?)) | any(.id == $id)
  ' "$SHELL_CONFIG")
fi

if [[ $in_bar == true ]]; then
  echo "Plugin already enabled and in the bar."
else
  if [[ $referenced == true ]]; then
    echo "Clearing a stale shell.json entry that blocks bar placement..."
    omarchy plugin disable "$PLUGIN_ID" >/dev/null
  fi
  omarchy plugin enable "$PLUGIN_ID" --section "$BAR_SECTION"
fi

omarchy-shell -q shell rescanPlugins
omarchy-shell -q omarchy.menu refresh

echo
echo "Done. Open it from Setup > Keyboard > Modifier Keys, or the bar icon."
