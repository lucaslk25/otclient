-- Instance Info Panel
-- Shows information about the current instance (players, type, time remaining)

local INSTANCE_OPCODE = 210

local instanceWindow = nil
local instanceButton = nil
local instanceData = nil
local timerEvent = nil

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  ProtocolGame.registerExtendedOpcode(INSTANCE_OPCODE, onExtendedOpcode)

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  ProtocolGame.unregisterExtendedOpcode(INSTANCE_OPCODE)

  stopTimer()
  destroyWindow()
end

function onGameStart()
  -- Window is created on demand when server sends data
end

function onGameEnd()
  stopTimer()
  destroyWindow()
  instanceData = nil
end

-- ============================================================================
-- ExtendedOpcode handler
-- ============================================================================

function onExtendedOpcode(protocol, code, buffer)
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)

  if not json_status then
    g_logger.error("Instance UI json error: " .. tostring(json_data))
    return false
  end

  local action = json_data["action"]
  if not action then
    return false
  end

  if action == "update" then
    local data = json_data["data"]
    if data then
      onInstanceUpdate(data)
    end
  elseif action == "clear" then
    onInstanceClear()
  end
end

-- ============================================================================
-- Data handling
-- ============================================================================

function onInstanceUpdate(data)
  instanceData = data

  ensureWindow()
  updateUI()
  showWindow()
  startTimer()
end

function onInstanceClear()
  instanceData = nil
  stopTimer()
  hideWindow()
end

-- ============================================================================
-- UI management
-- ============================================================================

function ensureWindow()
  if instanceWindow then
    return
  end

  instanceWindow = g_ui.loadUI('instance')
  instanceWindow:setup()

  instanceButton = modules.game_mainpanel.addToggleButton(
    'instanceButton',
    tr('Instance Info'),
    '/images/topbuttons/minimap',
    toggle,
    false,
    8
  )
  instanceButton:setOn(false)
end

function destroyWindow()
  if instanceWindow then
    instanceWindow:destroy()
    instanceWindow = nil
  end
  if instanceButton then
    instanceButton:destroy()
    instanceButton = nil
  end
end

function showWindow()
  if not instanceWindow then
    return
  end

  if not instanceWindow:getParent() then
    local panel = modules.game_interface.findContentPanelAvailable(
      instanceWindow,
      instanceWindow:getMinimumHeight()
    )
    if panel then
      panel:addChild(instanceWindow)
    end
  end

  instanceWindow:open()
  if instanceButton then
    instanceButton:setOn(true)
    instanceButton:show()
  end
end

function hideWindow()
  if instanceWindow then
    instanceWindow:close()
  end
  if instanceButton then
    instanceButton:setOn(false)
    instanceButton:hide()
  end
end

function toggle()
  if not instanceWindow then
    return
  end

  if instanceButton and instanceButton:isOn() then
    instanceWindow:close()
  else
    showWindow()
    fetchData()
  end
end

function onOpen()
  if instanceButton then
    instanceButton:setOn(true)
  end
end

function onClose()
  if instanceButton then
    instanceButton:setOn(false)
  end
end

-- ============================================================================
-- Timer for countdown
-- ============================================================================

function startTimer()
  stopTimer()
  timerEvent = scheduleEvent(updateTimer, 1000)
end

function stopTimer()
  if timerEvent then
    removeEvent(timerEvent)
    timerEvent = nil
  end
end

function updateTimer()
  if not instanceData or not instanceWindow then
    stopTimer()
    return
  end

  -- Decrement time remaining locally
  if instanceData.timeRemaining and instanceData.timeRemaining > 0 then
    instanceData.timeRemaining = instanceData.timeRemaining - 1
    updateTimeLabel()
  end

  timerEvent = scheduleEvent(updateTimer, 1000)
end

-- ============================================================================
-- UI update
-- ============================================================================

function updateUI()
  if not instanceWindow or not instanceData then
    return
  end

  -- Instance name
  local nameLabel = instanceWindow:recursiveGetChildById('instanceName')
  if nameLabel then
    nameLabel:setText(instanceData.name or '--')
  end

  -- Instance type
  local typeLabel = instanceWindow:recursiveGetChildById('instanceType')
  if typeLabel then
    local typeStr = instanceData.type or 'unknown'
    if typeStr == 'raid' then
      typeStr = 'Raid Instance'
    elseif typeStr == 'boss' then
      typeStr = 'Boss Instance'
    elseif typeStr == 'hunt' then
      typeStr = 'Hunt Instance'
    end
    typeLabel:setText('Type: ' .. typeStr)
  end

  -- Time remaining
  updateTimeLabel()

  -- Players
  local playersHeader = instanceWindow:recursiveGetChildById('playersHeader')
  if playersHeader then
    local count = 0
    if instanceData.players then
      count = #instanceData.players
    end
    playersHeader:setText('Players (' .. count .. '):')
  end

  local playerList = instanceWindow:recursiveGetChildById('playerList')
  if playerList then
    playerList:destroyChildren()

    if instanceData.players then
      for _, p in ipairs(instanceData.players) do
        local entry = g_ui.createWidget('PlayerEntry', playerList)
        local vocShort = shortenVocation(p.vocation or 'Unknown')
        entry:setText(p.name .. ' - ' .. vocShort .. ' ' .. (p.level or 0))
        entry:setColor('#DDDDDD')
      end
    end
  end
end

function updateTimeLabel()
  if not instanceWindow or not instanceData then
    return
  end

  local timeLabel = instanceWindow:recursiveGetChildById('timeRemaining')
  if timeLabel then
    local remaining = instanceData.timeRemaining or 0
    if remaining > 0 then
      local minutes = math.floor(remaining / 60)
      local seconds = remaining % 60
      timeLabel:setText(string.format('Time left: %02d:%02d', minutes, seconds))
      if remaining < 60 then
        timeLabel:setColor('#FF3333')
      elseif remaining < 180 then
        timeLabel:setColor('#FF8800')
      else
        timeLabel:setColor('#FF8800')
      end
    else
      timeLabel:setText('Time left: --:--')
    end
  end
end

function shortenVocation(vocation)
  local map = {
    ['Elite Knight'] = 'EK',
    ['Royal Paladin'] = 'RP',
    ['Elder Druid'] = 'ED',
    ['Master Sorcerer'] = 'MS',
    ['Knight'] = 'K',
    ['Paladin'] = 'P',
    ['Druid'] = 'D',
    ['Sorcerer'] = 'S',
  }
  return map[vocation] or vocation
end

-- ============================================================================
-- Server communication
-- ============================================================================

function fetchData()
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(INSTANCE_OPCODE, json.encode({action = "fetch"}))
  end
end
