require("config")
require("constants")
require("variables")
require("functions")

--- *** event handlers and initialization ***

function askBeforeStart()
  function compy.on_answer(text)
    local i, j, act_open = read_cell_command(text)
    if not (i and j and act_open) then
      compy.ask(PROMPTS.ready)
    else
      actionStart(i, j)
    end
  end
  compy.ask(PROMPTS.ready)
end

function askAfterStart()
  function compy.on_answer(text)
    -- a move that ends the game asks over this
    compy.ask(PROMPTS.started)
    actionCellEntered(text)
  end
  compy.ask(PROMPTS.started)
end

function askForRestart()
  function compy.on_answer(text)
    compy.ask(PROMPTS.restart)
    if validate_restart_command(text) then
      actionRestart()
    end
  end
  compy.ask(PROMPTS.restart)
end

function readyInput()
  singleclick = nil
  function doubleclick(x, y)
    actionUser(actionStart, x, y)
  end
  askBeforeStart()
end

function startedInput()
  function singleclick(x, y)
    actionUser(actionFlag, x, y)
  end
  function doubleclick(x, y)
    actionUser(actionUnlock, x, y)
  end
  askAfterStart()
end

function gameoverInput()
  singleclick = nil
  function doubleclick(x, y)
    actionRestart()
  end
  askForRestart()
end

function love.singleclick(x, y)
  if singleclick then
    singleclick(x, y)
  end
end

function love.doubleclick(x, y)
  if doubleclick then
    doubleclick(x, y)
  end
end

initialize()
