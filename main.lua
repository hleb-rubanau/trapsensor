require("config")
require("constants")
require("variables")
require("functions")

--- *** event handlers and initialization ***

function askBeforeStart()
  function compy.on_answer(text)
    local i, j, act_open = read_cell_command(text)
    if (i and j and act_open) then
      actionStart(i, j)
      compy.ask(PROMPTS.started)
    else
      printIgnored(text)
      compy.ask(PROMPTS.ready)
    end
  end
  compy.ask(PROMPTS.ready)
end

function askAfterStart()
  function compy.on_answer(text)
    -- reask (a move that ends the game asks over this)
    compy.ask(PROMPTS.started)
    actionCellEntered(text)
  end
  compy.ask(PROMPTS.started)
end

function askForRestart()
  function compy.on_answer(text)
    if validate_restart_command(text) then
      actionRestart()
      compy.ask(PROMPTS.started)
    else
      printIgnored(text)
      compy.ask(PROMPTS.restart)
    end
  end
  compy.ask(PROMPTS.restart)
end

function readyInput()
  singleclick = nil
  function doubleclick(x, y)
    actionPointer(actionStart, x, y)
  end
  askBeforeStart()
end

function startedInput()
  function singleclick(x, y)
    actionPointer(actionFlag, x, y)
  end
  function doubleclick(x, y)
    actionPointer(actionUnlock, x, y)
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
