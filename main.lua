COLS = 9
ROWS = 9
N_MINES = 12
CELL_SIZE = 32
CELL_FONT_SIZE = 28
STATUS_FONT_SIZE = 24

COLORS = { }
COLORS.background = Color[Color.black]
COLORS.status = Color[Color.green]
COLORS.hint = Color[Color.yellow]
COLORS.cell_border = Color[Color.white]
COLORS.cell_bg_locked = {
  0.5,
  0.5,
  0.5
}
COLORS.cell_bg_unlocked = Color[Color.green]
COLORS.cell_bg_flagged = Color[Color.yellow]
COLORS.cell_bg_blown = Color[Color.red]
COLORS.cell_fg_mine = Color[Color.black]
COLORS.cell_fg_flagged = Color[Color.red]
COLORS.cell_fg_default = Color[Color.blue]
COLORS.cell_fg_unlocked_1 = Color[Color.white]
COLORS.cell_fg_unlocked_2 = Color[Color.black]
COLORS.cell_fg_unlocked_3 = Color[Color.magenta]
COLORS.cell_fg_unlocked_4 = Color[Color.red]

SCREEN_VPAD = 0.1

HINTS = {
  ready = "Double-click to start",
  started = "Click to flag, double-click to open",
  won = "WIN!!! (double-click to restart)",
  lost = "Loss... (double-click to restart)"
}

--- *** derived constants definitions ***

fmt = string.format

gfx = love.graphics
screen_w, screen_h = gfx.getDimensions()

fonts = {
  status = gfx.newFont(STATUS_FONT_SIZE),
  cell = gfx.newFont(CELL_FONT_SIZE)
}

-- for cell we use glyph height, not font line height

cell_fh = CELL_FONT_SIZE
status_fh = font.getHeight(fonts.status)

-- geometry and coordinates of status panel

status_padding = status_fh
lower_edge = screen_h * (1 - SCREEN_VPAD)
hint_start = (lower_edge - status_padding) - status_fh
status_start = (hint_start - status_padding) - status_fh
status_y = status_start - status_padding
status_h = lower_edge - status_y

-- geometry and coordinates of gamefield

field_size = COLS * CELL_SIZE
field_x = (screen_w - field_size) / 2
field_y = ((status_start - status_padding) - field_size) / 2

-- helper matrix: neighbour offsets

col_offset = { }
row_offset = { }
for i = -1, 1 do
  for j = -1, 1 do
    local not_self = (i ~= 0) or (j ~= 0)
    if not_self then
      table.insert(col_offset, i)
      table.insert(row_offset, j)
    end
  end
end

--- *** runtime variables *** 

state = { }
grid = { }
counters = { }
mines = { }

--- *** helper functions: cells manipulation  ***

function between(low, mid, high)
  return (low <= mid) and (mid <= high)
end

function on_board(i, j)
  return between(1, i, ROWS) and between(1, j, COLS)
end

function neighborhood_size(i, j)
  local edge_cols = (i == 0) or (i == COLS)
  local edge_rows = (j == 0) or (j == ROWS)
  local size_cols = edge_cols and 2 or 3
  local size_rows = edge_rows and 2 or 3
  return size_cols * size_rows
end

function not_neighbor(row, col)
  return function(i, j)
    local proximity = (i - row) ^ 2 + (j - col) ^ 2
    return (2 < proximity)
  end
end

function all_neighbors(i, j)
  local index = 0
  return function()
    index = index + 1
    if 8 < index then
      return nil
    end
    return col_offset[index] + i, row_offset[index] + j
  end
end

function all_cells()
  local row, col = 1, 0
  return function()
    col = col + 1
    if COLS < col then
      col = 1
      row = row + 1
      if ROWS < row then
        return nil
      end
    end
    return row, col
  end
end

function cell_filter(cells, filter)
  function iterator()
    local row, col = cells()
    if (nil == row) then
      return nil
    end
    if filter(row, col) then
      return row, col
    end
    return iterator()
  end
  return iterator
end

function mineable_positions(row, col)
  return cell_filter(all_cells(), not_neighbor(row, col))
end

function neighbors(i, j)
  return cell_filter(all_neighbors(i, j), on_board)
end

function cell_is_mined(i, j)
  return grid[i][j].mine
end

function cell_is_unlockable(i, j)
  local cell = grid[i][j]
  local result = not (cell.unlocked or cell.flagged)
  return result
end

function cell_is_flaggable(i, j)
  local cell = grid[i][j]
  local result = not (cell.unlocked)
  return result
end

function except_cell(i, j)
  return function(col, row)
    local same_cell = (i == col) and (j == row)
    return not (same_cell)
  end
end

function count_mined_neighbors(row, col)
  local result = 0
  for i, j in neighbors(row, col) do
    if cell_is_mined(i, j) then
      result = result + 1
    end
  end
  return result
end

function all_mined_cells()
  return cell_filter(all_cells(), cell_is_mined)
end

function cells_to_expose(i, j)
  return cell_filter(all_mined_cells(), except_cell(i, j))
end

--- *** conversions between screen and field/cells ***

function isPointInGameField(x, y)
  local x_in_field = between(field_x, x, field_x + field_size)
  local y_in_field = between(field_y, y, field_y + field_size)
  return (x_in_field and y_in_field)
end

function detectCellPosition(x, y)
  if not isPointInGameField(x, y) then
    return nil, nil
  end
  local i = math.ceil((x - field_x) / CELL_SIZE)
  local j = math.ceil((y - field_y) / CELL_SIZE)
  if i == 0 then
    i = 1
  end
  if j == 0 then
    j = 1
  end
  return i, j
end

function getCellCoordinates(i, j)
  local x = field_x + (i - 1) * CELL_SIZE
  local y = field_y + (j - 1) * CELL_SIZE
  return x, y
end

--- *** visualization: status panel *** 

function getStatsLine()
  local r = counters.unlocked
  local p = counters.unlockable
  local f = counters.flagged
  local t = counters.mines
  local s = counters.seconds
  local template = "Flags: %s/%s | Open: %s/%s | Sec: %s"
  return fmt(template, f, t, r, p, s)
end

function drawStatusPanel(hint, statistics)
  gfx.setColor(COLORS.background)
  gfx.rectangle("fill", 0, status_y, screen_w, status_h)
  gfx.setFont(fonts.status)
  if statistics then
    gfx.setColor(COLORS.status)
    gfx.printf(statistics, 0, status_start, screen_w, "center")
  end
  if hint then
    gfx.setColor(COLORS.hint)
    gfx.printf(hint, 0, hint_start, screen_w, "center")
  end
end

function redrawStatus(status)
  if status ~= "ready" then
    counters.seconds = os.time() - state.started
    local statistics_line = getStatsLine()
    drawStatusPanel(HINTS[status], getStatsLine(counters))
  else
    drawStatusPanel(HINTS[status])
  end
end

--- *** visualization: game field *** 

function renderCellTile(x, y, bgcolor)
  gfx.setColor(bgcolor)
  gfx.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE)
  gfx.setColor(COLORS.cell_border)
  gfx.rectangle("line", x, y, CELL_SIZE, CELL_SIZE)
end

function renderCellText(x, y, fgcolor, txt)
  gfx.setColor(fgcolor)
  local text_y = y + CELL_SIZE * 0.5 - cell_fh * 0.5
  gfx.printf(txt, x, y, CELL_SIZE, "center")
end

function getMinesAroundColor(n_mines_nearby)
  for v = 8, 1, -1 do
    if v <= n_mines_nearby then
      local color_name = "cell_fg_unlocked_" .. v
      if COLORS[color_name] then
        return COLORS[color_name]
      end
    end
  end
  return COLORS.cell_fg_default
end

function drawCellLocked(i, j)
  local x, y = getCellCoordinates(i, j)
  renderCellTile(x, y, COLORS.cell_bg_locked)
end

function drawCellFlagged(i, j)
  local x, y = getCellCoordinates(i, j)
  renderCellTile(x, y, COLORS.cell_bg_flagged)
  renderCellText(x, y, COLORS.cell_fg_flagged, "?")
end

function drawCellUnlocked(i, j, n)
  local x, y = getCellCoordinates(i, j)
  renderCellTile(x, y, COLORS.cell_bg_unlocked)
  if 0 < n then
    local fgcolor = getMinesAroundColor(n)
    renderCellText(x, y, fgcolor, "" .. n)
  end
end

function drawCellBlown(i, j)
  local x, y = getCellCoordinates(i, j)
  renderCellTile(x, y, COLORS.cell_bg_blown)
  renderCellText(x, y, COLORS.cell_fg_mine, "X")
end

function drawCellExposed(i, j, was_flagged)
  local x, y = getCellCoordinates(i, j)
  bgcolor = COLORS.cell_bg_locked
  if was_flagged then
    bgcolor = COLORS.cell_bg_flagged
  end
  renderCellTile(x, y, bgcolor)
  renderCellText(x, y, COLORS.cell_fg_mine, "*")
end

function redraw()
  gfx.setColor(COLORS.background)
  gfx.rectangle("fill", 0, 0, screen_w, screen_h)
  gfx.setFont(fonts.cell)
  for i = 1, COLS do
    for j = 1, ROWS do
      drawCellLocked(i, j)
    end
  end
  redrawStatus("ready")
end

--- *** flows: game rules and logic *** 

function flowInitGrid()
  for i = 1, COLS do
    grid[i] = { }
    for j = 1, ROWS do
      grid[i][j] = { }
    end
  end
end

function flowResetCells()
  for i = 1, COLS do
    for j = 1, ROWS do
      local cell = grid[i][j]
      cell.mine = false
      cell.flagged = false
      cell.unlocked = false
    end
  end
end

function flowInitState()
  state.status = "ready"
  state.time_started = nil
  counters.unlocked = 0
  counters.seconds = 0
  counters.clicks = 0
  counters.unlockable = 0
  counters.mines = 0
  flowResetCells()
end

function flowPlaceMine(i, j)
  local cell = grid[i][j]
  cell.mine = true
  counters.mines = counters.mines + 1
end

-- [i,j] is the firt click index, guaranteed to be safe zone

function flowMinesPlacement(i, j)
  math.randomseed(os.time())
  local available_cells = COLS * ROWS - neighborhood_size(i, j)
  local mines_to_place = N_MINES
  for row, col in mineable_positions(i, j) do
    local p = mines_to_place / available_cells
    if math.random() < p then
      flowPlaceMine(row, col)
      mines_to_place = mines_to_place - 1
    end
    available_cells = available_cells - 1
  end
end

function flowStart(i, j)
  flowMinesPlacement(i, j)
  state.status = "started"
  state.started = os.time()
  counters.clicks = 0
  counters.seconds = 0
  counters.unlocked = 0
  counters.flagged = 0
  counters.unlockable = COLS * ROWS - N_MINES
end

function flowToggleFlag(i, j)
  local cell = grid[i][j]
  cell.flagged = not (cell.flagged)
  if cell.flagged then
    drawCellFlagged(i, j)
    counters.flagged = counters.flagged + 1
  else
    drawCellLocked(i, j)
    counters.flagged = counters.flagged - 1
  end
  redrawStatus(state.status)
end

function flowBlow(i, j)
  drawCellBlown(i, j)
  for row, col in cells_to_expose(i, j) do
    local cell = grid[row][col]
    drawCellExposed(row, col, cell.flagged)
  end
end

function flowUnlock(i, j)
  if cell_is_mined(i, j) then
    flowBlow(i, j)
    return "lost"
  end
  local n_neighbors = count_mined_neighbors(i, j)
  drawCellUnlocked(i, j, n_neighbors)
  grid[i][j].unlocked = true
  counters.unlocked = counters.unlocked + 1
  if counters.unlockable == counters.unlocked then
    return "won"
  end
  return "started"
end

--- *** actions: interactive actions entry points ***

function actionInit()
  flowInitState()
  redraw()
end

function actionFlag(i, j)
  if cell_is_flaggable(i, j) then
    flowToggleFlag(i, j)
  end
end

function actionUnlock(i, j)
  if (state.status == "ready") then
    flowStart(i, j)
  end
  if cell_is_unlockable(i, j) then
    counters.clicks = counters.clicks + 1
    state.status = flowUnlock(i, j)
    redrawStatus(state.status)
  end
end

function actionUser(action, x, y)
  local i, j = detectCellPosition(x, y)
  if i and j then
    action(i, j)
  end
end

--- *** event handlers and initialization ***

function love.singleclick(x, y)
  if state.status == "started" then
    actionUser(actionFlag, x, y)
  end
end

function love.doubleclick(x, y)
  local game_won = (state.status == "won")
  local game_lost = (state.status == "lost")
  local game_over = game_won or game_lost
  if game_over then
    actionInit()
  else
    actionUser(actionUnlock, x, y)
  end
end

flowInitGrid()
actionInit()
