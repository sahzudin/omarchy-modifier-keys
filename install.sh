#!/usr/bin/env bash
set -euo pipefail

# Adds a "Setup > Keyboard > Modifier Keys" entry to the Omarchy menu.
#
# The Omarchy menu reads its extension rows from a single user file
# (~/.config/omarchy/extensions/omarchy-menu.jsonc), so a plugin cannot inject
# menu entries by itself — this script merges them in for you. The original
# file is preserved as omarchy-menu.jsonc.bak on first run.
#
# Run from the plugin folder:
#   ~/.config/omarchy/plugins/io.github.sahzudin.modifier-keys/install.sh

PLUGIN_ID="io.github.sahzudin.modifier-keys"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

python3 - "$MENU_FILE" "$PLUGIN_ID" <<'PY'
import json
import os
import shutil
import sys

path = sys.argv[1]
plugin_id = sys.argv[2]

keyboard = {
    "setup.keyboard": {"icon": "\uf11c", "label": "Keyboard"},
    "setup.keyboard.modifiers": {
        "icon": "\uf11c",
        "label": "Modifier Keys",
        "description": "Remap Caps Lock, Control, Alt, and Super",
        "action": "omarchy-shell shell summon %s '{}'" % plugin_id,
    },
}

if not os.path.exists(path):
    content = "{\n}\n"
else:
    with open(path, "r", encoding="utf-8") as handle:
        content = handle.read()

if '"setup.keyboard.modifiers"' in content:
    print("Menu entries already present — nothing to do.")
    sys.exit(0)

inner = json.dumps(keyboard, indent=2, ensure_ascii=False)[1:-1]

prefix = content.rstrip()
if not prefix.endswith("}"):
    prefix += "\n}"
prefix = prefix[:-1].rstrip()
comma = "" if (prefix.endswith("{") or prefix.endswith(",")) else ","
new_content = prefix + comma + "\n" + inner + "\n}\n"

backup = path + ".bak"
if os.path.exists(path) and not os.path.exists(backup):
    shutil.copy(path, backup)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(new_content)

print("Added Setup > Keyboard > Modifier Keys to " + path)
print("Apply it with: omarchy-shell shell rescanPlugins && omarchy menu refresh")
PY