require("config")

--- *** derived constants definitions ***
fmt = string.format

sfx = compy.audio
gfx = love.graphics
screen_w, screen_h = gfx.getDimensions()

fonts = {
  status = gfx.newFont(STATUS_FONT_SIZE),
  cell = gfx.newFont(CELL_FONT_SIZE)
}

-- for cell we use glyph height, not font line height

cell_fh = fonts.cell:getHeight()
status_fh = fonts.status:getHeight()

-- geometry and coordinates of status panel

status_padding = status_fh
lower_edge = screen_h * (1 - SCREEN_VPAD)
hint_start = (lower_edge - status_padding) - status_fh
status_start = (hint_start - status_padding) - status_fh
status_y = status_start - status_padding
status_h = lower_edge - status_y

-- geometry and coordinates of gamefield

max_field_width = screen_w
max_field_height = status_y
max_cols = math.floor(max_field_width / CELL_SIZE)
max_rows = math.floor(max_field_height / CELL_SIZE)

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
