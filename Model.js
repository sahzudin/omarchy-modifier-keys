// Mapping tables for the Modifier Keys panel.
//
// Each row is a physical modifier key. Each target is what the user can
// remap it to. `token` is the XKB option emitted for that choice; a null
// token means "keep this key's default behavior". The plugin only manages
// the tokens listed here (ctrl:*, altwin:*, caps:* and compose:caps); every
// other token already present in kb_options is preserved by the apply script.

var ROWS = [
  {
    id: "caps",
    label: "Caps Lock",
    targets: [
      { id: "capslock", label: "Caps", token: null },
      { id: "compose", label: "Compose", token: "compose:caps" },
      { id: "ctrl", label: "Ctrl", token: "ctrl:nocaps" },
      { id: "escape", label: "Esc", token: "caps:escape" },
      { id: "super", label: "Super", token: "caps:super" },
      { id: "menu", label: "Menu", token: "caps:menu" },
      { id: "hyper", label: "Hyper", token: "caps:hyper" },
      { id: "backspace", label: "Bksp", token: "caps:backspace" },
      { id: "none", label: "Off", token: "caps:none" }
    ]
  },
  {
    id: "lctrl",
    label: "Left Ctrl",
    targets: [
      { id: "ctrl", label: "Ctrl", token: null },
      { id: "alt", label: "Alt", token: "ctrl:swap_lalt_lctl" },
      { id: "super", label: "Super", token: "ctrl:swap_lwin_lctl" },
      { id: "meta", label: "Meta", token: "ctrl:lctrl_meta" }
    ]
  },
  {
    id: "rctrl",
    label: "Right Ctrl",
    targets: [
      { id: "ctrl", label: "Ctrl", token: null },
      { id: "alt", label: "Alt", token: "ctrl:rctrl_ralt" },
      { id: "super", label: "Super", token: "ctrl:swap_rwin_rctl" },
      { id: "meta", label: "Meta", token: "ctrl:rctrl_meta" }
    ]
  },
  {
    id: "lalt",
    label: "Left Alt",
    targets: [
      { id: "alt", label: "Alt", token: null },
      { id: "ctrl", label: "Ctrl", token: "ctrl:swap_lalt_lctl" },
      { id: "super", label: "Super", token: "altwin:swap_lalt_lwin" }
    ]
  },
  {
    id: "ralt",
    label: "Right Alt",
    targets: [
      { id: "alt", label: "Alt", token: null },
      { id: "ctrl", label: "Ctrl", token: "ctrl:ralt_rctrl" },
      { id: "super", label: "Super", token: "altwin:swap_ralt_rwin" }
    ]
  },
  {
    id: "lsuper",
    label: "Left Super",
    targets: [
      { id: "super", label: "Super", token: null },
      { id: "ctrl", label: "Ctrl", token: "ctrl:swap_lwin_lctl" },
      { id: "alt", label: "Alt", token: "altwin:swap_lalt_lwin" }
    ]
  },
  {
    id: "rsuper",
    label: "Right Super",
    targets: [
      { id: "super", label: "Super", token: null },
      { id: "ctrl", label: "Ctrl", token: "ctrl:swap_rwin_rctl" },
      { id: "alt", label: "Alt", token: "altwin:swap_ralt_rwin" }
    ]
  }
]

function rowCount() {
  return ROWS.length
}

function rowAt(index) {
  return ROWS[index]
}

function findTarget(row, targetId) {
  for (var i = 0; i < row.targets.length; i++) {
    if (row.targets[i].id === targetId) return row.targets[i]
  }
  return null
}

function targetToken(row, targetId) {
  var target = findTarget(row, targetId)
  return target ? target.token : null
}

// Default selection per row: the target with no token (native behavior).
function defaultSelections() {
  var selections = {}
  for (var i = 0; i < ROWS.length; i++) {
    var row = ROWS[i]
    var fallback = row.targets[0].id
    for (var j = 0; j < row.targets.length; j++) {
      if (row.targets[j].token === null) {
        fallback = row.targets[j].id
        break
      }
    }
    selections[row.id] = fallback
  }
  return selections
}

// Build the full managed-token list for a selections map.
//
// Symmetric swap tokens (altwin:swap_*_lwin, ctrl:swap_l*_l*) change two keys
// at once, so they are only emitted while BOTH sides still agree. Otherwise
// reverting one row would leave the other row's inferred value in place and
// the swap would silently re-apply.
function buildTokens(selections) {
  var tokens = []
  var add = function(token) {
    if (token && tokens.indexOf(token) < 0) tokens.push(token)
  }

  // Caps Lock targets are one-directional.
  add(targetToken(ROWS[0], selections.caps))

  // One-directional Control targets.
  if (selections.lctrl === "meta") add("ctrl:lctrl_meta")
  if (selections.rctrl === "meta") add("ctrl:rctrl_meta")
  if (selections.rctrl === "alt") add("ctrl:rctrl_ralt")
  if (selections.ralt === "ctrl") add("ctrl:ralt_rctrl")

  // Symmetric swaps: both sides must agree.
  if (selections.lctrl === "alt" && selections.lalt === "ctrl") add("ctrl:swap_lalt_lctl")
  if (selections.lctrl === "super" && selections.lsuper === "ctrl") add("ctrl:swap_lwin_lctl")
  if (selections.rctrl === "super" && selections.rsuper === "ctrl") add("ctrl:swap_rwin_rctl")
  if (selections.lalt === "super" && selections.lsuper === "alt") add("altwin:swap_lalt_lwin")
  if (selections.ralt === "super" && selections.rsuper === "alt") add("altwin:swap_ralt_rwin")

  return tokens
}

// Infer per-row selections from a token list. Must be the inverse of
// buildTokens for every combination the UI can produce.
function inferSelections(tokens) {
  var selections = defaultSelections()
  var has = function(token) { return tokens.indexOf(token) >= 0 }

  if (has("ctrl:nocaps")) selections.caps = "ctrl"
  else if (has("caps:escape")) selections.caps = "escape"
  else if (has("caps:super")) selections.caps = "super"
  else if (has("caps:menu")) selections.caps = "menu"
  else if (has("caps:hyper")) selections.caps = "hyper"
  else if (has("caps:backspace")) selections.caps = "backspace"
  else if (has("caps:none")) selections.caps = "none"
  else if (has("compose:caps")) selections.caps = "compose"
  else selections.caps = "capslock"

  if (has("ctrl:swap_lalt_lctl")) { selections.lctrl = "alt"; selections.lalt = "ctrl" }
  if (has("ctrl:swap_lwin_lctl")) { selections.lctrl = "super"; selections.lsuper = "ctrl" }
  if (has("ctrl:lctrl_meta")) selections.lctrl = "meta"
  if (has("ctrl:rctrl_ralt")) selections.rctrl = "alt"
  if (has("ctrl:swap_rwin_rctl")) { selections.rctrl = "super"; selections.rsuper = "ctrl" }
  if (has("ctrl:rctrl_meta")) selections.rctrl = "meta"
  if (has("ctrl:ralt_rctrl")) selections.ralt = "ctrl"
  if (has("altwin:swap_lalt_lwin")) { selections.lalt = "super"; selections.lsuper = "alt" }
  if (has("altwin:swap_ralt_rwin")) { selections.ralt = "super"; selections.rsuper = "alt" }

  return selections
}

// Apply a user choice for one row and keep the whole selection map
// consistent, so the round-trip buildTokens -> inferSelections reproduces it.
//
// Symmetric swaps change two keys at once: choosing one side pins the other
// side to the swapped role, and choosing a default (native) target unpins the
// counterpart so the swap can be reverted from either row.
function applyTarget(selections, rowId, targetId) {
  var s = {}
  for (var k in selections) s[k] = selections[k]
  s[rowId] = targetId

  var row = null
  for (var i = 0; i < ROWS.length; i++) {
    if (ROWS[i].id === rowId) { row = ROWS[i]; break }
  }
  var token = targetToken(row, targetId)

  // Pin the counterpart when a symmetric swap target is chosen.
  if (token === "ctrl:swap_lalt_lctl") { s.lctrl = "alt"; s.lalt = "ctrl" }
  else if (token === "ctrl:swap_lwin_lctl") { s.lctrl = "super"; s.lsuper = "ctrl" }
  else if (token === "ctrl:swap_rwin_rctl") { s.rctrl = "super"; s.rsuper = "ctrl" }
  else if (token === "altwin:swap_lalt_lwin") { s.lalt = "super"; s.lsuper = "alt" }
  else if (token === "altwin:swap_ralt_rwin") { s.ralt = "super"; s.rsuper = "alt" }

  // Unpin the counterpart when a default target is chosen. The values below
  // are exclusively produced by the symmetric swap pins above, so this can
  // never clobber an independent one-directional choice.
  if (token === null) {
    if (rowId === "lctrl") {
      if (s.lalt === "ctrl") s.lalt = "alt"
      if (s.lsuper === "ctrl") s.lsuper = "super"
    } else if (rowId === "lalt") {
      if (s.lctrl === "alt") s.lctrl = "ctrl"
      if (s.lsuper === "alt") s.lsuper = "super"
    } else if (rowId === "lsuper") {
      if (s.lctrl === "super") s.lctrl = "ctrl"
      if (s.lalt === "super") s.lalt = "alt"
    } else if (rowId === "rctrl") {
      if (s.rsuper === "ctrl") s.rsuper = "super"
    } else if (rowId === "ralt") {
      if (s.rsuper === "alt") s.rsuper = "super"
    } else if (rowId === "rsuper") {
      if (s.rctrl === "super") s.rctrl = "ctrl"
      if (s.ralt === "super") s.ralt = "alt"
    }
  }

  // Normalize through the token round-trip so the displayed rows always match
  // the options that will actually be applied.
  return inferSelections(buildTokens(s))
}

if (typeof module !== "undefined") {
  module.exports = {
    ROWS: ROWS,
    rowCount: rowCount,
    rowAt: rowAt,
    findTarget: findTarget,
    targetToken: targetToken,
    defaultSelections: defaultSelections,
    buildTokens: buildTokens,
    inferSelections: inferSelections,
    applyTarget: applyTarget
  }
}