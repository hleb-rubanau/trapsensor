COLS = 9
ROWS = 9
N_MINES = 12
CELL_SIZE = 32
CELL_FONT = 28
STATUS_FONT = 24

COLOR = { }
COLOR.background = Color[Color.black]
COLOR.status = Color[Color.green]
COLOR.hint = Color[Color.yellow]
COLOR.cell_border = Color[Color.white]
COLOR.cell_bg_not_revealed = {
  0.5,
  0.5,
  0.5
}
COLOR.cell_bg_revealed = Color[Color.green]
COLOR.cell_bg_flagged = Color[Color.yellow]
COLOR.cell_bg_blown = Color[Color.red]
COLOR.cell_fg_mine = Color[Color.black]
COLOR.cell_fg_flagged = Color[Color.red]
COLOR.cell_fg_default = Color[Color.blue]
COLOR.cell_fg_revealed_1 = Color[Color.white]
COLOR.cell_fg_revealed_2 = Color[Color.black]
COLOR.cell_fg_revealed_3 = Color[Color.magenta]
COLOR.cell_fg_revealed_4 = Color[Color.red]

cols = COLS
rows = ROWS
n_mines = N_MINES

gfx=love.graphics

screen_w, screen_h = gfx.getDimensions()
fonts = {
  status = gfx.newFont(STATUS_FONT),
  cell   = gfx.newFont(CELL_FONT)
}

cell_fh = font.getHeight(fonts.cell)
status_fh = font.getHeight(fonts.status)

padding = status_fh
hint_start = screen_h - padding - status_fh
status_start = hint_start - padding - status_fh

field_size = cols*CELL_SIZE
field_x = (screen_w - field_size) / 2
field_y = (status_start - padding - field_size)/2

cells = cols*rows

--- runtime variables
state = { }
grid = { }
counters = { }
mines = { }

function newCell()
  local cell = {
    revealed = false,
    flagged = false,
    mine = nil,
    exposed = false,
    blown = false,
  }
  return cell
end

function flowInitGrid()
  grid = { }
  for i = 1, cols do
    local col = { }
    for j = 1, rows do
      col[j] = newCell()
    end
    grid[i] = col
  end
end

function flowInitState()
  state.status = 'ready'
  state.result = nil
  state.started = nil

  counters.revealed = 0
  counters.seconds =  0
  counters.clicks = 0
  counters.pending = 0
  counters.mines = 0

  flowInitGrid()
end

col_offset = { }
row_offset = { }
for i = -1, 1 do
  for j = -1, 1 do
    if (i ~= 0) or (j ~= 0) then
      table.insert(col_offset, i)
      table.insert(row_offset, j)
    end
  end
end

function cell_filter(cells, filter)
   local iterator = function()
     local row, col = cells()
     if filter(row, col) then
       return row, col
     end
     return iterator()
   end
   return iterator()
end

function between(low, mid, high)
  return (low <= mid) and (mid <= high)
end

function on_board(i, j)
  return between(1, i, rows) and between(1, j, cols)
end

function all_neighbors(i, j)
  local index = 0
  return function()
    index = index + 1
    return col_offset[index] + i, row_offset[index] + j
  end
end

function neighbors(i, j)
  return cell_filter(all_neighbors(i, j), on_board)
end

function mined_neighbors(row, col)
  local result = 0
  for i, j in neighbors(row, col) do
    if grid[i][j].mine then
      result = result + 1
    end
  end
  return result
end

function flowPlaceMine(i, j)
  local cell = grid[i][j]
  cell.mine = true
  -- for later reference
  table.insert(mines, cell)
  counters.mines = counters.mines + 1
end

function dimension(i, limit)
  if (i == 1) or (i == limit) then
    return 2
  end
  return 3
end

function forbidden(i, j)
  return dimension(i, rows) * dimension(j, cols)
end

function all_cells()
  local row, col = 1, 0
  return function()
    col = col + 1
    if col > cols then
       col = 1
       row = row + 1
       if row > rows then
         return nil
       end
    end
    return row, col
  end
end

function far(a, b)
  return math.abs(a - b) > 1
end

function far_cell(row, col)
  return function(i, j)
    return far(row, i) and far(col, j)
  end
end

function allowed_cells(i, j)
  return cell_filter(all_cells, far_cell(i, j))
end

-- [i,j] is the firt click index, guaranteed to be safe zone
function flowMinesPlacement(i, j)
  local mines_to_place = n_mines
  local cells_to_mine = cols * rows - forbidden_cells(i, j)
  math.randomseed(os.time())
  for row, col in allowed_cells(i, j) do
    local p = mines_to_place / cells_to_mine
    if math.random() < p then
      mines_to_place = mines_to_place - 1
      flowPlaceMine(i, j)
    end
    cells_to_mine = cells_to_mine - 1
  end
end

function flowStart(i,j)
  flowMinesPlacement(i,j)

  state.status = 'started'
  state.started = os.time()
  counters.clicks = 0
  counters.seconds = 0
  counters.revealed = 0
  counters.flagged = 0
  counters.blown = 0
  counters.pending = cells - n_mines
end


function flowUpdateTimer()
  if state.started then
    counters.seconds = os.time() - state.started
  end
end

-- blow or reveal
function flowCheckCell(i,j)
  local cell = grid[i][j]
  if cell.mine then
    cell.blown = true
    counters.blown = counters.blown + 1
  else
    cell.revealed = true
    counters.revealed = counters.revealed + 1
    counters.pending = counters.pending - 1
  end
end

function flowEvaluateGameStatus(i,j)
  if counters.pending == 0 then
    state.status = 'finished'
    state.result = 'win'
  end

  if counters.blown > 0 then
    state.status = 'finished'
    state.result = 'lost'
    for n, cell in ipairs(mines) do
      cell.exposed = true
    end
  end
end

function flowReveal(i,j)
  flowCheckCell(i,j)
  flowEvaluateGameStatus(i,j)
end

actionInit = flowInitState

function actionFlag(i,j)
  local cell = grid[i][j]

  if not(cell.revealed) then
    cell.flagged = not(cell.flagged)

    local adjust = cell.flagged and 1 or -1
    counters.flagged = counters.flagged + adjust

    flowUpdateTimer()
  end
end

function actionReveal(i,j)
  local game_not_started = (state.status == 'ready')
  if game_not_started then
    flowStart(i,j)
  end

  local cell = grid[i][j]
  local can_be_revealed = not( cell.revealed or cell.flagged )
  if can_be_revealed then
    flowReveal(i,j)
  end
  flowUpdateTimer()
end

function isPointInGameField(x,y)
  local x_min = field_x
  local x_max = field_x + field_size
  local y_min = field_y
  local y_max = field_y + field_size
  local x_valid = ( x >= x_min ) and ( x <= x_max )
  local y_valid = ( y >= y_min ) and ( y <= y_max )
  return x_valid and y_valid
end

function detectCellPosition(x,y)
  local x_rel = x - field_x
  local y_rel = y - field_y
  local c = CELL_SIZE
  local i = math.ceil( x_rel / c )
  local j = math.ceil( y_rel / c )
  -- corner cases, left boundary still is cell
  if x_rel == 0 then
    i = 1
  end
  if y_rel == 0 then
    j = 1
  end
  return i,j
end

function love.singleclick(x,y)
  if state.status=='started' then
    flowUpdateTimer()
    if isPointInGameField(x,y) then
      local i, j = detectCellPosition(x,y)
      actionFlag(i,j)
    end
  end
end

function love.doubleclick(x,y)
  if state.status=='finished' then
    actionInit()
  else
    flowUpdateTimer()
    if isPointInGameField(x,y) then
      local i, j = detectCellPosition(x,y)
      actionReveal(i,j)
    end
  end
end

function getStatusLine()
  local msg = nil
  if not(state.status == 'ready') then
    local r = counters.revealed
    local p = counters.pending
    local f = counters.flagged
    local t = counters.mines
    local s = counters.seconds
    local fmt = string.format
    local template = "Flags: %s/%s | Open: %s/%s | Sec: %s"
    msg = fmt(template, f, t, r, p, s)
  end
  return msg
end

function getHintsLine()
  if state.status == 'ready' then
    return 'Double-click to start'
  end
  if state.status == 'started' then
    return 'Click to flag, double-click to open'
  end

  local result = string.upper(state.result)
  return result.."! (double-click to restart)"
end

function redrawStatus()
  local status = getStatusLine()
  local hint = getHintsLine()
  gfx.setFont(fonts.status)
  if status then
    gfx.setColor(COLOR.status)
    gfx.printf( status, 0, status_start, screen_w, 'center')
  end
  if hint then
    gfx.setColor(COLOR.hint)
    gfx.printf( hint, 0, hint_start, screen_w, 'center')
  end
end

-- drawing cells
function getCellRectangle(i,j)
  local cell_x_rel = (i-1)*CELL_SIZE
  local cell_y_rel = (j-1)*CELL_SIZE
  local cell_x = field_x + cell_x_rel
  local cell_y = field_y + cell_y_rel
  return { cell_x, cell_y }
end

function renderCell(coords, bgcolor, fgcolor, txt)
  local cell_x, cell_y = unpack(coords)
  gfx.setColor( bgcolor )
  gfx.rectangle('fill', cell_x, cell_y, CELL_SIZE, CELL_SIZE)
  gfx.setColor( COLOR.cell_border )
  gfx.rectangle('line', cell_x, cell_y, CELL_SIZE, CELL_SIZE)
  if txt then
    gfx.setColor( fgcolor )
    local text_y = cell_y + CELL_SIZE*0.5 - cell_fh*0.5
    gfx.printf( txt, cell_x, text_y, CELL_SIZE, 'center' )
  end
end

function getCellDisplayContent(i, j)
  local cell = grid[i][j]
  local is_exposed_mine = cell.mine and cell.exposed

  if cell.blown then
    return "X"
  elseif is_exposed_mine then
    return '*'
  elseif cell.flagged then
    return '?'
  elseif cell.revealed then
    local n_mines_nearby = mined_neighbors(i, j)
    if nearby > 0 then
      return ''..n_mines_nearby
    end
  end

  return false
end

function drawCell(i, j)
  local coords = getCellRectangle(i,j)

  local bgColor = COLOR.cell_bg_revealed
  local fgColor = COLOR.cell_fg_default
  local content = getCellDisplayContent(i, j)

  renderCell( coords, bgColor, fgColor, content )
end

function redrawField()
  gfx.setFont( fonts.cell )
  for i = 1, cols do
    for j = 1, rows do
      drawCell(i,j)
    end
  end
end

function redraw()
  gfx.setColor(COLOR.background)
  gfx.rectangle('fill', 0, 0, screen_w, screen_h)
  redrawField()
  redrawStatus()
end

love.draw = redraw

actionInit()
