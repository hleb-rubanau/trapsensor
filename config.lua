DEFAULT_COLS = 9
DEFAULT_ROWS = 9
DEFAULT_MINES = 12

CELL_SIZE = 32
CELL_FONT_SIZE = 26
STATUS_FONT_SIZE = 24

SCREEN_VPAD = 0.1

COLORS = { }
COLORS.background = {
  0.15,
  0.15,
  0.18
}
COLORS.status = {
  0.7,
  0.85,
  0.7
}
COLORS.hint = {
  0.9,
  0.8,
  0.5
}
COLORS.cell_border = {
  0.2,
  0.2,
  0.22
}
COLORS.cell_bg_locked = {
  0.45,
  0.5,
  0.58
}
COLORS.cell_bg_unlocked = {
  0.82,
  0.78,
  0.7
}
COLORS.cell_bg_flagged = {
  0.85,
  0.6,
  0.2
}
COLORS.cell_bg_blown = {
  0.7,
  0.1,
  0.1
}
COLORS.cell_fg_mine = Color[Color.black]
COLORS.cell_mine_blink = Color[Color.white]

COLORS.cell_fg_flagged = {
  0.25,
  0.15,
  0.05
}
COLORS.cell_fg_default = Color[Color.black]
COLORS.cell_fg_unlocked = { }
COLORS.cell_fg_unlocked[1] = {
  0.1,
  0.1,
  0.8
}
COLORS.cell_fg_unlocked[2] = {
  0.1,
  0.55,
  0.1
}
COLORS.cell_fg_unlocked[3] = {
  0.8,
  0.1,
  0.1
}
COLORS.cell_fg_unlocked[4] = {
  0.1,
  0.1,
  0.45
}
COLORS.cell_fg_unlocked[5] = {
  0.5,
  0.1,
  0.1
}

HINTS = {
  ready = "Double-click to start, click to switch mode",
  started = "Click to flag, double-click to open",
  won = "WIN!!! (double-click to restart)",
  lost = "Loss... (double-click to restart)"
}

