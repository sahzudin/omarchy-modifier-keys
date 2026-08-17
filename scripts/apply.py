#!/usr/bin/env python3
"""Backend for the Modifier Keys plugin.

Reads and writes XKB modifier options in ~/.config/hypr/input.lua, then
reloads Hyprland so the new options take effect immediately.

The plugin only manages the modifier-swap tokens it can produce
(ctrl:*, altwin:*, caps:* and compose:caps). Every other token in
kb_options (shift:..., grp:..., compose:<other>) is preserved untouched.
"""
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
INPUT_LUA = os.path.join(HOME, ".config", "hypr", "input.lua")

MANAGED_RE = re.compile(r"^(ctrl|altwin|caps):|^compose:caps$")

# --------------------------------------------------------------------------
# helpers


def lua_escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def split_tokens(raw):
    if not raw:
        return []
    return [t for t in raw.split(",") if t.strip()]


def is_managed(token):
    return bool(MANAGED_RE.match(token))


def read_file_state():
    if not os.path.exists(INPUT_LUA):
        return None, None
    with open(INPUT_LUA, "r", encoding="utf-8") as handle:
        content = handle.read()
    match = re.search(r'kb_options\s*=\s*"([^"]*)"', content)
    return content, (match.group(1) if match else None)


def hyprctl_options():
    try:
        result = subprocess.run(
            ["hyprctl", "getoption", "input:kb_options"],
            capture_output=True, text=True, timeout=10,
        )
        match = re.search(r"^str:\s*(.*)$", result.stdout, re.M)
        if match:
            return match.group(1).strip()
    except Exception:
        pass
    return ""


def current_kb_options():
    _, file_options = read_file_state()
    if file_options is not None:
        return file_options
    return hyprctl_options()


def reload_hyprland():
    try:
        result = subprocess.run(
            ["hyprctl", "reload"], capture_output=True, text=True, timeout=20,
        )
        return result.stdout.strip() or result.stderr.strip()
    except Exception as exc:  # pragma: no cover - process launch failure
        return "hyprctl reload failed: %s" % exc


def write_file(content, kb_options):
    """Return a new input.lua body with kb_options set, creating/inserting as needed."""
    if content and re.search(r"kb_options\s*=", content):
        return re.sub(
            r'(kb_options\s*=\s*)"[^"]*"',
            lambda match: '%s"%s"' % (match.group(1), lua_escape(kb_options)),
            content,
            count=1,
        )

    line = '    kb_options = "%s",' % lua_escape(kb_options)

    if content and re.search(r"input\s*=\s*\{", content):
        match = re.search(r"input\s*=\s*\{", content)
        return content[: match.end()] + "\n" + line + content[match.end():]

    if not content:
        content = (
            "-- Modifier key remapping managed by the Modifier Keys plugin.\n"
            "hl.config({\n"
            "  input = {\n"
            "    kb_options = \"%s\",\n"
            "  },\n"
            "})\n" % lua_escape(kb_options)
        )
        return content

    return content.rstrip() + "\n\nhl.config({ input = { kb_options = \"%s\" } })\n" % lua_escape(kb_options)


def persist(kb_options):
    content, _ = read_file_state()
    new_content = write_file(content or "", kb_options)
    with open(INPUT_LUA, "w", encoding="utf-8") as handle:
        handle.write(new_content)
    reload_output = reload_hyprland()
    applied = hyprctl_options()
    warning = None
    if applied != kb_options:
        warning = (
            "Applied option differs from the file after reload "
            "(reload output: %r)." % reload_output
        )
    return kb_options, applied, warning

# --------------------------------------------------------------------------
# commands


def cmd_get():
    raw = current_kb_options()
    tokens = split_tokens(raw)
    return {
        "ok": True,
        "raw": raw,
        "tokens": tokens,
        "managed": [t for t in tokens if is_managed(t)],
        "free": [t for t in tokens if not is_managed(t)],
        "file": INPUT_LUA,
        "fileExists": os.path.exists(INPUT_LUA),
    }


def cmd_set(new_tokens_csv):
    new_tokens = split_tokens(new_tokens_csv)

    content, file_options = read_file_state()
    existing = split_tokens(file_options if file_options is not None else hyprctl_options())

    seen = set()
    merged = []
    for token in existing:
        if not is_managed(token):
            seen.add(token)
            merged.append(token)
    for token in new_tokens:
        if token and token not in seen:
            seen.add(token)
            merged.append(token)

    final = ",".join(merged)
    applied, actual, warning = persist(final)

    return {
        "ok": True,
        "kb_options": applied,
        "actual": actual,
        "warning": warning,
        "file": INPUT_LUA,
    }


def cmd_reset():
    return cmd_set("")


def main():
    args = sys.argv[1:]
    if not args or args[0] == "get":
        print(json.dumps(cmd_get()))
    elif args[0] == "set":
        new = args[1] if len(args) > 1 else ""
        print(json.dumps(cmd_set(new)))
    elif args[0] == "reset":
        print(json.dumps(cmd_reset()))
    else:
        print(json.dumps({"ok": False, "error": "unknown command: %s" % args[0]}))
        sys.exit(1)


if __name__ == "__main__":
    main()