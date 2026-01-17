cols = 9
rows = 9
n_traps = 12
cell_size = 32
cell_font = 28
status_font = 24

gfx=love.graphics

colors = {
  background = Color[Color.black],
  status = Color[Color.green],
  hint = Color[Color.yellow],
  cell_border = Color[Color.white],
  cell_bg_not_revealed = { 0.5, 0.5, 0.5 },
  cell_bg_revealed = Color[Color.green],
  cell_bg_flagged = Color[Color.yellow],
  cell_bg_blown = Color[Color.red],
  cell_fg_trap = Color[Color.black],
  cell_fg_flagged = Color[Color.red],
  cell_fg_default = Color[Color.blue],
  cell_fg_revealed_1 = Color[Color.white],
  cell_fg_revealed_2 = Color[Color.black],
  cell_fg_revealed_3 = Color[Color.magenta],
  cell_fg_revealed_4 = Color[Color.red]
}

screen_w, screen_h = gfx.getDimensions()
fonts = {
  status = gfx.newFont(status_font),
  cell   = gfx.newFont(cell_font)
}

cell_fh = font.getHeight(fonts.cell)
status_fh = font.getHeight(fonts.status)

padding = status_fh
hint_start = screen_h - padding - status_fh
status_start = hint_start - padding - status_fh

field_size = cols*cell_size
field_x = (screen_w - field_size) / 2
field_y = (status_start - padding - field_size)/2

cells = cols*rows

--- runtime variables
state = { }
grid = { }
counters = { }
traps = { }

function newCell()
  local cell = {
    revealed = false,
    flagged = false,
    trap = nil,
    exposed = false,
    blown = false,
    n_traps_nearby = 0,
  }
  return cell
end

function flowInitGrid()
  grid = { }
  for i = 1, cols do
    local col = {}
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
  counters.traps = 0

  flowInitGrid()
end

function getNeighbourPositions(i, j)
  local result = { }
  local i_min = math.max(i-1, 1)
  local i_max = math.min(i+1, cols)
  local j_min = math.max(j-1, 1)
  local j_max = math.min(j+1, rows)
  for n = i_min, i_max do
    for m = j_min, j_max do
      local is_original = (n==i) and (m==j)
      if not is_original then
        table.insert(result, {n,m})
      end
    end
  end
  return result
end

function getNonNeighbourPositions(i, j)
  local result = { }
  for n = 1, cols do
    local i_near = math.abs( i - n ) <= 1
    for m = 1, rows do
      local j_near = math.abs( j - m ) <= 1
      local proximity = i_near and j_near
      if not proximity then
        table.insert(result, {n,m})
      end
    end
  end
  return result
end

function flowPlaceTrap(i,j)
  local cell = grid[i][j]
  cell.trap = true

  table.insert( traps, {i,j} ) -- for later reference
  counters.traps = counters.traps+1

  local neighbours = getNeighbourPositions(i,j)
  for idx, position in ipairs(neighbours) do
    local pos_i, pos_j = unpack(position)
    local neighbour = grid[ pos_i ][ pos_j ]
    neighbour.n_traps_nearby = neighbour.n_traps_nearby + 1
  end
end

-- [i,j] is the firt click index, guaranteed to be safe zone
function flowTrapsPlacement(i,j)
  math.randomseed(os.time())
  local positions = getNonNeighbourPositions( i, j )
  local n = #positions
  local m = math.min( n_traps, n )
  for ipos, pos in ipairs(positions) do
    local p = (m / n)
    local selected = math.random() < p
    if selected then
      flowPlaceTrap( unpack(pos) )
      m = m - 1
    end
    n = n - 1
  end
end

function flowStart(i,j)
  flowTrapsPlacement(i,j)

  state.status = 'started'
  state.started = os.time()
  counters.clicks = 0
  counters.seconds = 0
  counters.revealed = 0
  counters.flagged = 0
  counters.blown = 0
  counters.pending = cells - n_traps
end


function flowUpdateTimer()
  if state.started then
    counters.seconds = os.time() - state.started
  end
end

-- blow or reveal
function flowCheckCell(i,j)
  local cell = grid[i][j]
  if cell.trap then
    cell.blown = true
    counters.blown = counters.blown + 1
  else
    cell.revealed = true
    counters.revealed = counters.revealed + 1
    counters.pending = counters.pending - 1
  end
end

function flowExpose()
  for _, cell_index in ipairs(traps) do
    local i, j = unpack( cell_index )
    grid[i][j].exposed=true
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
    flowExpose()
  end
end

function flowReveal(i,j)
  flowCheckCell(i,j)
  flowEvaluateGameStatus(i,j)
  return (state.status == 'finished')
end

function flowToggleFlag(i,j)
  local cell = grid[i][j]
  cell.flagged = not(cell.flagged)
  local adjust = cell.flagged and 1 or -1
  counters.flagged = counters.flagged + adjust
end

function drawExposedCells()
  for _, trap_cell_index in ipairs(traps) do
    local i, j = unpack( trap_cell_index )
    drawCell(i, j)
  end
end

function actionInit()
  flowInitState()
  redraw()
end

function actionFlag(i,j)
  local cell = grid[i][j]
  if not(cell.revealed) then
    flowToggleFlag(i,j)
    drawCell(i,j)
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
    local game_finished = flowReveal(i,j)
    drawCell(i,j)
    if game_finished then
      drawExposedCells()
    end
  end
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
  local c = cell_size
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
    if isPointInGameField(x,y) then
      local i, j = detectCellPosition(x,y)
      actionFlag(i,j)
      flowUpdateTimer()
      redrawStatus()
    end
  end
end

function love.doubleclick(x,y)
  if state.status=='finished' then
    actionInit()
  else
    if isPointInGameField(x,y) then
      local i, j = detectCellPosition(x,y)
      actionReveal(i,j)
      flowUpdateTimer()
      redrawStatus()
    end
  end
end

function getStatusLine()
  local msg = nil
  if not(state.status == 'ready') then
    local r = counters.revealed
    local p = counters.pending
    local f = counters.flagged
    local t = counters.traps
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
  
  gfx.setColor(colors.background)
  local status_h = status_fh * 2 + padding
  local status_y = status_start - padding
  gfx.rectangle('fill', 0, status_y, screen_w, status_h)
  
  gfx.setFont(fonts.status)
  if status then
    gfx.setColor(colors.status)
    gfx.printf( status, 0, status_start, screen_w, 'center')
  end
  if hint then
    gfx.setColor(colors.hint)
    gfx.printf( hint, 0, hint_start, screen_w, 'center')
  end
end

-- drawing cells
function getCellRectangle(i,j)
  local cell_x_rel = (i-1)*cell_size
  local cell_y_rel = (j-1)*cell_size
  local cell_x = field_x + cell_x_rel
  local cell_y = field_y + cell_y_rel
  return { cell_x, cell_y }
end

function renderCell(coords, bgcolor, fgcolor, txt)
  local cell_x, cell_y = unpack(coords)
  gfx.setColor( bgcolor )
  gfx.rectangle('fill', cell_x, cell_y, cell_size, cell_size)
  gfx.setColor( colors.cell_border )
  gfx.rectangle('line', cell_x, cell_y, cell_size, cell_size)
  if txt then
    gfx.setColor( fgcolor )
    local text_y = cell_y + cell_size*0.5 - cell_fh*0.5
    gfx.printf( txt, cell_x, text_y, cell_size, 'center' )
  end
end

function getCellBackgroundColor(cell)
  if cell.flagged then
    return colors.cell_bg_flagged
  elseif cell.blown then
    return colors.cell_bg_blown
  elseif cell.revealed then
    return colors.cell_bg_revealed
  else
    return colors.cell_bg_not_revealed
  end
end

function getTrapsAroundColor(n_traps_nearby)
  for v = 8,1,-1 do
    if n_traps_nearby >= v then
      local color_name = "cell_fg_revealed_"..v
      if colors[color_name] then
        return colors[color_name]
      end
    end
  end
  return colors.cell_fg_default
end

function getCellForegroundColor(cell)
  if cell.flagged then
    return colors.cell_fg_flagged
  end
  if cell.trap then
    return colors.cell_fg_trap
  end
  return getTrapsAroundColor(cell.n_traps_nearby)
end

function getCellDisplayContent(cell)
  local is_exposed_trap = cell.trap and cell.exposed

  if cell.blown then
    return "X"
  elseif is_exposed_trap then
    return '*'
  elseif cell.flagged then
    return '?'
  elseif cell.revealed then
    if cell.n_traps_nearby > 0 then
      return ''..cell.n_traps_nearby
    end
  end

  return false
end

function drawCell(i,j)
  local cell = grid[i][j]
  local coords = getCellRectangle(i,j)

  local bgColor = getCellBackgroundColor(cell)
  local fgColor = getCellForegroundColor(cell)
  local content = getCellDisplayContent(cell)

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
  gfx.setColor(colors.background)
  gfx.rectangle('fill', 0, 0, screen_w, screen_h)
  redrawField()
  redrawStatus()
end

actionInit()
