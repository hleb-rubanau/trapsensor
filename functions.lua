require("config")
require("constants")
require("variables")

function game_mode(cols, rows, mines)
  local n_cols = math.min(cols, max_cols)
  local n_rows = math.min(rows, max_rows)
  local n_cells = n_cols * n_rows
  local max_mines = math.floor(n_cells * MINES_PERCENT / 100)
  local n_mines = max_mines
  if mines then
    n_mines = math.min(mines, max_mines)
  end
  return n_cols, n_rows, n_mines
end

function add_game_mode(cols, rows, mines)
  local n_cols, n_rows, n_mines = game_mode(cols, rows, mines)
  table.insert(modes, {
    n_cols,
    n_rows,
    n_mines
  })
end

function initModes()
  add_game_mode(DEFAULT_COLS, DEFAULT_ROWS, DEFAULT_MINES)
  add_game_mode(MIDDLE_COLS, MIDDLE_ROWS)
  add_game_mode(max_cols, max_rows)
end

--- *** helper functions: cells manipulation  ***

function between(low, mid, high)
  return (low <= mid) and (mid <= high)
end

function on_board(i, j)
  local cols = config.cols
  local rows = config.rows
  return between(1, i, cols) and between(1, j, rows)
end

function neighborhood_size(i, j)
  local edge_cols = (i == 0) or (i == config.cols)
  local edge_rows = (j == 0) or (j == config.rows)
  local size_cols = edge_cols and 2 or 3
  local size_rows = edge_rows and 2 or 3
  return size_cols * size_rows
end

function not_neighbor(col, row)
  return function(i, j)
    local proximity = (i - col) ^ 2 + (j - row) ^ 2
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
    if config.cols < col then
      col = 1
      row = row + 1
      if config.rows < row then
        return nil
      end
    end
    return col, row
  end
end

function cell_filter(cells, filter)
  local iterator
  function iterator()
    local col, row = cells()
    if (nil == row) then
      return nil
    end
    if filter(col, row) then
      return col, row
    end
    return iterator()
  end
  return iterator
end

function mineable_positions(col, row)
  return cell_filter(all_cells(), not_neighbor(col, row))
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

function count_mined_neighbors(col, row)
  local result = 0
  for i, j in neighbors(col, row) do
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

function unlockable_neighbors(i, j)
  return cell_filter(neighbors(i, j), cell_is_unlockable)
end

--- *** conversions between screen and field/cells ***

function isPointInGameField(x, y)
  local x_min = config.field_x
  local x_max = config.field_x_max
  local y_min = config.field_y
  local y_max = config.field_y_max
  local x_in_field = between(x_min, x, x_max)
  local y_in_field = between(y_min, y, y_max)
  return (x_in_field and y_in_field)
end

function detectCellPosition(x, y)
  if not isPointInGameField(x, y) then
    return nil, nil
  end
  local i = math.ceil((x - config.field_x) / CELL_SIZE)
  local j = math.ceil((y - config.field_y) / CELL_SIZE)
  if i == 0 then
    i = 1
  end
  if j == 0 then
    j = 1
  end
  return i, j
end

function getCellCoordinates(i, j)
  local x = config.field_x + (i - 1) * CELL_SIZE
  local y = config.field_y + (j - 1) * CELL_SIZE
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

function getModeLine()
  local c = config.cols
  local r = config.rows
  local m = config.mines
  return fmt("Mode: %s x %s (%s mines)", c, r, m)
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
  local statusLineBuilder = getModeLine
  if status ~= "ready" then
    counters.seconds = os.time() - state.started
    statusLineBuilder = getStatsLine
  end
  local statusLine = statusLineBuilder()
  drawStatusPanel(HINTS[status], statusLine)
end

--- *** visualization: game field *** 

function renderCellTile(x, y, bgcolor)
  gfx.setColor(bgcolor)
  gfx.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE)
  gfx.setColor(COLORS.cell_border)
  gfx.rectangle("line", x, y, CELL_SIZE, CELL_SIZE)
end

function mine_canvas_range(center, padding)
  local start_point = (center - CELL_SIZE / 2) + padding
  local end_point = center + CELL_SIZE / 2 - padding
  return start_point, end_point
end

function drawMineSpikes(cx, cy, p)
  local outer_left, outer_right = mine_canvas_range(cx, p)
  local outer_top, outer_bottom = mine_canvas_range(cy, p)
  local inner_left, inner_right = mine_canvas_range(cx, 2 * p)
  local inner_top, inner_bottom = mine_canvas_range(cy, 2 * p)
  gfx.line(cx, outer_top, cx, outer_bottom)
  gfx.line(outer_left, cy, outer_right, cy)
  gfx.line(inner_left, inner_top, inner_right, inner_bottom)
  gfx.line(inner_left, inner_bottom, inner_right, inner_top)
end

function drawMine(x, y)
  local cx = x + 0.5 * CELL_SIZE
  local cy = y + 0.5 * CELL_SIZE
  local r = 0.3 * CELL_SIZE
  local padding = 0.1 * CELL_SIZE
  drawMineSpikes(cx, cy, padding)
  gfx.setColor(COLORS.cell_fg_mine)
  gfx.circle("fill", cx, cy, r)
  gfx.setColor(COLORS.cell_mine_blink)
  gfx.circle("fill", cx - r / 3, cy - r / 3, r / 4)
end

function drawFlag(x, y)
  local cx, cy = x + CELL_SIZE / 2, y + CELL_SIZE / 2
  local left, right = mine_canvas_range(cx, 0.3 * CELL_SIZE)
  local top, bottom = mine_canvas_range(cy, 0.25 * CELL_SIZE)
  local flag_h = 0.3 * CELL_SIZE
  local bisect = top + flag_h / 2
  local low = top + flag_h
  gfx.setColor(COLORS.cell_fg_flagged)
  gfx.line(left, top, left, bottom)
  gfx.polygon("fill", left, top, right, bisect, left, low)
end

function renderCellText(x, y, fgcolor, txt)
  gfx.setColor(fgcolor)
  local text_y = y + CELL_SIZE * 0.5 - cell_fh * 0.5
  gfx.printf(txt, x, text_y, CELL_SIZE, "center")
end

function getMinesAroundColor(n_mines_nearby)
  for v = 8, 1, -1 do
    if v <= n_mines_nearby then
      local maybe_color = COLORS.cell_fg_unlocked[v]
      if maybe_color then
        return maybe_color
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
  drawFlag(x, y)
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
  drawMine(x, y)
end

function drawCellExposed(i, j, was_flagged)
  local x, y = getCellCoordinates(i, j)
  bgcolor = COLORS.cell_bg_locked
  if was_flagged then
    bgcolor = COLORS.cell_bg_flagged
  end
  renderCellTile(x, y, bgcolor)
  drawMine(x, y)
end

function redraw()
  gfx.setColor(COLORS.background)
  gfx.rectangle("fill", 0, 0, screen_w, screen_h)
  gfx.setFont(fonts.cell)
  for i = 1, config.cols do
    for j = 1, config.rows do
      drawCellLocked(i, j)
    end
  end
  redrawStatus("ready")
end

--- *** flows: game rules and logic *** 

function flowInitConfig(mode)
  local cols, rows, n_mines = unpack(mode)
  config.cols = cols
  config.rows = rows
  config.cells = cols * rows
  config.mines = n_mines
  config.field_w = cols * CELL_SIZE
  config.field_h = rows * CELL_SIZE
  config.field_x = (max_field_width - config.field_w) / 2
  config.field_y = (max_field_height - config.field_h) / 2
  config.field_x_max = config.field_x + config.field_w
  config.field_y_max = config.field_y + config.field_h
end

function flowInitGrid()
  for i = 1, max_cols do
    grid[i] = { }
    for j = 1, max_rows do
      grid[i][j] = { }
    end
  end
end

function flowResetCells()
  for i = 1, config.cols do
    for j = 1, config.rows do
      local cell = grid[i][j]
      cell.mine = false
      cell.flagged = false
      cell.unlocked = false
    end
  end
end

function flowInitState()
  readyInput()
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
  local mineable_cells = config.cells - neighborhood_size(i, j)
  local mines_to_place = config.mines
  for col, row in mineable_positions(i, j) do
    local p = mines_to_place / mineable_cells
    if math.random() < p then
      flowPlaceMine(col, row)
      mines_to_place = mines_to_place - 1
    end
    mineable_cells = mineable_cells - 1
  end
end

function flowStart(i, j)
  flowMinesPlacement(i, j)
  startedInput()
  state.started = os.time()
  counters.clicks = 0
  counters.seconds = 0
  counters.unlocked = 0
  counters.flagged = 0
  counters.unlockable = config.cells - counters.mines
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
  redrawStatus("started")
end

function flowBlow(i, j)
  drawCellBlown(i, j)
  for col, row in cells_to_expose(i, j) do
    local cell = grid[col][row]
    drawCellExposed(col, row, cell.flagged)
  end
end

function flowSafeUnlock(i, j)
  local n_neighbors = count_mined_neighbors(i, j)
  drawCellUnlocked(i, j, n_neighbors)
  grid[i][j].unlocked = true
  counters.unlocked = counters.unlocked + 1
  if n_neighbors == 0 then
    for col, row in unlockable_neighbors(i, j) do
      flowSafeUnlock(col, row)
    end
  end
end

function flowUnlock(i, j)
  if cell_is_mined(i, j) then
    flowBlow(i, j)
    redrawStatus("lost")
    gameoverInput()
    return
  end
  flowSafeUnlock(i, j)
  if counters.unlockable == counters.unlocked then
    redrawStatus("won")
    gameoverInput()
    return
  end
  redrawStatus("started")
end

--- *** actions: interactive actions entry points ***

function actionInit()
  flowInitState()
  redraw()
end

function actionNextMode()
  if mode_idx == #modes then
    mode_idx = 1
  else
    mode_idx = mode_idx + 1
  end
  flowInitConfig(modes[mode_idx])
  actionInit()
end

function actionFlag(i, j)
  if cell_is_flaggable(i, j) then
    flowToggleFlag(i, j)
  end
end

function actionUnlock(i, j)
  if cell_is_unlockable(i, j) then
    counters.clicks = counters.clicks + 1
    flowUnlock(i, j)
  end
end

function actionUser(action_func, x, y)
  local i, j = detectCellPosition(x, y)
  if not (i and j) then
    return 
  end
  action_func(i, j)
end

function initialize()
  initModes()
  flowInitConfig(modes[1])
  flowInitGrid()
  actionInit()
end
