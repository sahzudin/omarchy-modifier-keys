#!/usr/bin/env bash
set -euo pipefail

# Remove the shared Omarchy menu entries added by install.sh. Run this before
# `omarchy plugin remove`, while this file still exists.

PLUGIN_ID="io.github.sahzudin.modifier-keys"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

python3 - "$MENU_FILE" "$PLUGIN_ID" <<'PY'
import json
import os
import re
import sys

path, plugin_id = sys.argv[1], sys.argv[2]

if not os.path.exists(path):
    print("Menu file does not exist; nothing to remove.")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as handle:
    content = handle.read()


def scan(text):
    """Return comment-free JSONC text and its original-source offsets."""
    out, offsets, i, n, in_string = [], [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            offsets.append(i)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                offsets.append(i + 1)
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
        elif c == '"':
            in_string = True
            out.append(c)
            offsets.append(i)
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i = min(i + 2, n)
        else:
            out.append(c)
            offsets.append(i)
            i += 1
    return "".join(out), offsets


bare, offsets = scan(content)
normalized = re.sub(r",(\s*[}\]])", r"\1", bare.strip()) or "{}"
try:
    existing = json.loads(normalized)
except ValueError as error:
    sys.exit("%s is not valid JSONC (%s) — fix it, then re-run." % (path, error))
if not isinstance(existing, dict):
    sys.exit("%s is not a JSONC object — fix it, then re-run." % path)

leaf = "setup.keyboard.modifiers"
parent = "setup.keyboard"
expected_action = "omarchy-shell shell summon %s '{}'" % plugin_id
remove = set()

leaf_value = existing.get(leaf)
if isinstance(leaf_value, dict) and leaf_value.get("action") == expected_action:
    remove.add(leaf)

# install.sh supplies this parent only as a container for the leaf. Remove it
# when it is unchanged and no other setup.keyboard descendants will remain.
parent_value = existing.get(parent)
other_children = any(
    key.startswith(parent + ".") and key not in remove
    for key in existing
)
if (parent_value == {"icon": "", "label": "Keyboard"}
        and not other_children and leaf in remove):
    remove.add(parent)

if not remove:
    print("No plugin-owned menu entries found.")
    sys.exit(0)


def top_level_properties(text):
    """Find top-level object property spans in comment-free JSON text."""
    decoder = json.JSONDecoder()
    start = text.find("{")
    if start < 0:
        return []
    i, result = start + 1, []
    while True:
        while i < len(text) and (text[i].isspace() or text[i] == ","):
            i += 1
        if i >= len(text) or text[i] == "}":
            return result
        key_start = i
        key, i = decoder.raw_decode(text, i)
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text) or text[i] != ":":
            raise ValueError("expected ':' after top-level key")
        i += 1
        while i < len(text) and text[i].isspace():
            i += 1
        _, value_end = decoder.raw_decode(text, i)
        i = value_end
        while i < len(text) and text[i].isspace():
            i += 1
        if i < len(text) and text[i] == ",":
            i += 1
        result.append((key, key_start, i))


try:
    properties = top_level_properties(bare)
except (ValueError, json.JSONDecodeError) as error:
    sys.exit("Could not locate menu entries in %s (%s)." % (path, error))

spans = []
for key, start, end in properties:
    if key in remove:
        original_start = offsets[start]
        original_end = offsets[end - 1] + 1
        spans.append((original_start, original_end))

for start, end in sorted(spans, reverse=True):
    content = content[:start] + content[end:]

with open(path, "w", encoding="utf-8") as handle:
    handle.write(content)

print("Removed %s from %s" % (", ".join(sorted(remove)), path))
PY

if command -v omarchy-shell >/dev/null; then
  omarchy-shell -q omarchy.menu refresh
fi

echo "Menu cleanup complete. You can now remove the plugin."
