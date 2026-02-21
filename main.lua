require("config")
require("constants")
require("variables")
require("functions")

--- *** event handlers and initialization ***

function readyInput()
  function singleclick(x, y)
    actionNextMode()
  end
  function doubleclick(x, y)
    actionUser(flowStart, x, y)
    actionUser(actionUnlock, x, y)
  end
end

function startedInput()
  function singleclick(x, y)
    actionUser(actionFlag, x, y)
  end
  function doubleclick(x, y)
    actionUser(actionUnlock, x, y)
  end
end

function gameoverInput()
  singleclick = nil
  function doubleclick(x, y)
    actionInit()
  end
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
