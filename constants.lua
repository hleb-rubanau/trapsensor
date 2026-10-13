require("config")

--- *** derived constants definitions ***
fmt = string.format

sfx = compy.audio
gfx = love.graphics
screen_w, screen_h = gfx.getDimensions()

fonts = {
  label = gfx.newFont(LABEL_FONT_SIZE),
  cell = gfx.newFont(CELL_FONT_SIZE)
}

-- for cell we use glyph height, not font line height

cell_fh = fonts.cell:getHeight()
label_fh = fonts.label:getHeight()

-- screen: the terminal on the left, the board on the right,
-- the prompt and input lines along the bottom

board_x = screen_w * TERMINAL_SHARE
board_w = screen_w - board_x
board_h = screen_h - INPUT_H

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
