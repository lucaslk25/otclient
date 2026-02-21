-- Instance Info Panel
-- Shows information about the current instance (players, type, time remaining)

local INSTANCE_OPCODE = 210

local instanceWindow = nil
local instanceButton = nil
local instanceData = nil
local timerEvent = nil
local totalTime = nil
local highlightedCreature = nil

-- ============================================================================
-- Vocation helpers
-- ============================================================================

local VOCATION_SHORT = {
  ['Elite Knight']    = 'EK',
  ['Royal Paladin']   = 'RP',
  ['Elder Druid']     = 'ED',
  ['Master Sorcerer'] = 'MS',
  ['Knight']          = 'K',
  ['Paladin']         = 'P',
  ['Druid']           = 'D',
  ['Sorcerer']        = 'S',
  ['None']            = '--',
  ['No Vocation']     = '--',
  ['Unknown']         = '--',
}

local VOCATION_COLOR = {
  ['EK'] = '#E05050',  -- red
  ['K']  = '#E05050',
  ['RP'] = '#50C878',  -- green
  ['P']  = '#50C878',
  ['ED'] = '#5098E0',  -- blue
  ['D']  = '#5098E0',
  ['MS'] = '#B06DE0',  -- purple
  ['S']  = '#B06DE0',
}

local TYPE_INFO = {
  raid = { label = 'Raid Instance',  color = '#E05050' },
  boss = { label = 'Boss Instance',  color = '#B06DE0' },
  hunt = { label = 'Hunt Instance',  color = '#50C878' },
}

local function shortenVocation(vocation)
  if not vocation or vocation == '' then return '--' end
  return VOCATION_SHORT[vocation] or string.sub(vocation, 1, 2)
end

local function getVocationColor(vocShort)
  return VOCATION_COLOR[vocShort] or '#AAAAAA'
end

-- ============================================================================
-- Time formatting
-- ============================================================================

local function formatTime(seconds)
  if not seconds or seconds <= 0 then
    return '--:--'
  end

  if seconds >= 3600 then
    local hours = math.floor(seconds / 3600)
    local mins  = math.floor((seconds % 3600) / 60)
    local secs  = seconds % 60
    return string.format('%d:%02d:%02d', hours, mins, secs)
  else
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%02d:%02d', mins, secs)
  end
end

-- ============================================================================
-- Creature highlight (hover on player name -> highlight on map)
-- ============================================================================

local function findCreatureByName(name)
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  local spectators = g_map.getSpectators(player:getPosition(), false)
  for _, creature in ipairs(spectators) do
    if creature:getName():lower() == name:lower() then
      return creature
    end
  end
  return nil
end

local function clearCreatureHighlight()
  if highlightedCreature then
    highlightedCreature:setHighlight('#FFFFFF')
    highlightedCreature = nil
  end
end

-- ============================================================================
-- UI button setup (hide unused header buttons, wire context menu)
-- ============================================================================

local function setupUIButtons()
  -- Hide toggleFilterButton
  local toggleFilterButton = instanceWindow:recursiveGetChildById('toggleFilterButton')
  if toggleFilterButton then
    toggleFilterButton:setVisible(false)
    toggleFilterButton:setOn(false)
  end

  -- Re-anchor contextMenuButton next to minimizeButton and wire it
  local contextMenuButton = instanceWindow:recursiveGetChildById('contextMenuButton')
  local minimizeButton = instanceWindow:recursiveGetChildById('minimizeButton')
  if contextMenuButton and minimizeButton then
    contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
    contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
    contextMenuButton:setMarginRight(7)
    contextMenuButton.onClick = function(widget, mousePos, mouseButton)
      return showWindowContextMenu(mousePos or widget:getPosition())
    end
  end

  -- Re-anchor lockButton next to contextMenuButton
  local lockButton = instanceWindow:recursiveGetChildById('lockButton')
  if lockButton and contextMenuButton then
    lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
    lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
    lockButton:setMarginRight(2)
  end

  -- Hide newWindowButton
  local newWindowButton = instanceWindow:recursiveGetChildById('newWindowButton')
  if newWindowButton then
    newWindowButton:setVisible(false)
  end
end

-- ============================================================================
-- Context menus
-- ============================================================================

function showWindowContextMenu(mousePos)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)

  menu:addOption(tr('Refresh'), function()
    fetchData()
  end)

  if instanceData and instanceData.name then
    menu:addSeparator()
    menu:addOption(tr('Copy Instance Name'), function()
      g_window.setClipboardText(instanceData.name)
    end)
  end

  menu:display(mousePos)
  return true
end

local function showPlayerContextMenu(playerName, mousePos)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)

  menu:addOption(tr('Message to %s', playerName), function()
    g_game.openPrivateChannel(playerName)
  end)

  menu:addOption(tr('Add to VIP'), function()
    g_game.addVip(playerName)
  end)

  menu:addSeparator()

  menu:addOption(tr('Copy Name'), function()
    g_window.setClipboardText(playerName)
  end)

  menu:display(mousePos)
  return true
end

-- ============================================================================
-- Module lifecycle
-- ============================================================================

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd   = onGameEnd
  })

  ProtocolGame.registerExtendedOpcode(INSTANCE_OPCODE, onExtendedOpcode)

  -- Create button in main panel
  instanceButton = modules.game_mainpanel.addToggleButton(
    'instanceButton',
    tr('Instance') .. ' (Alt+I)',
    '/images/options/button_instance',
    toggle,
    false,
    8
  )
  instanceButton:setOn(false)

  -- Load and set up window
  instanceWindow = g_ui.loadUI('instance')
  instanceWindow:setContentMinimumHeight(80)

  -- Keybind
  Keybind.new('Windows', 'Show/hide instance window', 'Alt+I', '')
  Keybind.bind('Windows', 'Show/hide instance window', {
    {
      type = KEY_DOWN,
      callback = toggle,
    }
  })

  instanceWindow:setup()
  setupUIButtons()

  -- Start hidden (will show when server sends data)
  instanceButton:hide()

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd   = onGameEnd
  })

  ProtocolGame.unregisterExtendedOpcode(INSTANCE_OPCODE)
  Keybind.delete('Windows', 'Show/hide instance window')

  stopTimer()
  stopBlink()
  clearCreatureHighlight()

  if instanceWindow then
    instanceWindow:destroy()
    instanceWindow = nil
  end
  if instanceButton then
    instanceButton:destroy()
    instanceButton = nil
  end
end

-- ============================================================================
-- Game events
-- ============================================================================

function onGameStart()
  instanceWindow:setupOnStart()
  fetchData()
end

function onGameEnd()
  stopTimer()
  stopBlink()
  clearCreatureHighlight()
  instanceData = nil
  totalTime = nil

  if instanceWindow then
    instanceWindow:setParent(nil, true)
  end
  if instanceButton then
    instanceButton:setOn(false)
    instanceButton:hide()
  end
end

-- ============================================================================
-- ExtendedOpcode handler
-- ============================================================================

function onExtendedOpcode(protocol, code, buffer)
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)

  if not json_status then
    g_logger.error('[game_instance] JSON decode error: ' .. tostring(json_data))
    return false
  end

  local action = json_data['action']
  if not action then
    return false
  end

  if action == 'update' then
    local data = json_data['data']
    if data then
      onInstanceUpdate(data)
    end
  elseif action == 'clear' then
    onInstanceClear()
  end
end

-- ============================================================================
-- Data handling
-- ============================================================================

function onInstanceUpdate(data)
  instanceData = data

  -- Use server-sent totalTime if available, otherwise fall back to heuristic
  if data.totalTime and data.totalTime > 0 then
    totalTime = data.totalTime
  elseif data.timeRemaining and (not totalTime or data.timeRemaining > (totalTime or 0)) then
    totalTime = data.timeRemaining
  end

  updateUI()
  showWindow()
  startTimer()
end

function onInstanceClear()
  instanceData = nil
  totalTime = nil
  stopTimer()
  stopBlink()
  clearCreatureHighlight()

  if instanceWindow then
    -- Collapse creature sprite
    local creatureSprite = instanceWindow:recursiveGetChildById('creatureSprite')
    if creatureSprite then
      creatureSprite:setSize({ width = 0, height = 0 })
      creatureSprite:setVisible(false)
    end
  end

  hideWindow()
end

-- ============================================================================
-- Window show/hide/toggle
-- ============================================================================

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
    instanceButton:setOn(false)
  else
    if not instanceWindow:getParent() then
      local panel = modules.game_interface.findContentPanelAvailable(
        instanceWindow,
        instanceWindow:getMinimumHeight()
      )
      if not panel then
        return
      end
      panel:addChild(instanceWindow)
    end
    instanceWindow:open()
    instanceButton:setOn(true)
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

  if instanceData.timeRemaining and instanceData.timeRemaining > 0 then
    instanceData.timeRemaining = instanceData.timeRemaining - 1
    updateTimeDisplay()
  end

  timerEvent = scheduleEvent(updateTimer, 1000)
end

-- ============================================================================
-- Blink effect for critical time
-- ============================================================================

function stopBlink()
  if not instanceWindow then return end
  local timeLabel = instanceWindow:recursiveGetChildById('timeRemaining')
  if timeLabel and timeLabel.isBlinking then
    g_effects.stopBlink(timeLabel)
    timeLabel.isBlinking = false
  end
end

-- ============================================================================
-- Creature sprite (stacked layout - toggle size to show/hide)
-- ============================================================================

local function updateCreatureSprite()
  if not instanceWindow or not instanceData then return end

  local creatureSprite = instanceWindow:recursiveGetChildById('creatureSprite')
  if not creatureSprite then return end

  local nameLabel = instanceWindow:recursiveGetChildById('instanceName')

  local outfitData = instanceData.outfit
  if outfitData and outfitData.type and outfitData.type > 0 then
    local outfit = {
      type   = outfitData.type,
      head   = outfitData.head or 0,
      body   = outfitData.body or 0,
      legs   = outfitData.legs or 0,
      feet   = outfitData.feet or 0,
      addons = outfitData.addons or 0,
    }
    creatureSprite:setOutfit(outfit)
    creatureSprite:getCreature():setStaticWalking(1000)
    creatureSprite:setSize({ width = 40, height = 40 })
    creatureSprite:setVisible(true)
    creatureSprite:setTooltip(instanceData.name or '')
    if nameLabel then
      nameLabel:setMarginTop(4)
    end
  else
    -- Collapse to 0x0 so instanceName anchors flush to top
    creatureSprite:setSize({ width = 0, height = 0 })
    creatureSprite:setVisible(false)
    if nameLabel then
      nameLabel:setMarginTop(0)
    end
  end
end

-- ============================================================================
-- UI update
-- ============================================================================

function updateUI()
  if not instanceWindow or not instanceData then
    return
  end

  -- Creature sprite
  updateCreatureSprite()

  -- Instance name (centered, full width)
  local nameLabel = instanceWindow:recursiveGetChildById('instanceName')
  if nameLabel then
    local name = instanceData.name or '--'
    nameLabel:setText(name)
    nameLabel:setTooltip(name)
  end

  -- Instance type (centered, no prefix, colored by type)
  local typeLabel = instanceWindow:recursiveGetChildById('instanceType')
  if typeLabel then
    local typeStr = instanceData.type or 'unknown'
    local typeInfo = TYPE_INFO[typeStr]
    if typeInfo then
      typeLabel:setText(typeInfo.label)
      typeLabel:setColor(typeInfo.color)
    else
      typeLabel:setText(typeStr)
      typeLabel:setColor('#AAAAAA')
    end
  end

  -- Time (inside progress bar)
  updateTimeDisplay()

  -- Players header
  local playersHeader = instanceWindow:recursiveGetChildById('playersHeader')
  if playersHeader then
    local count = 0
    if instanceData.players then
      count = #instanceData.players
    end
    playersHeader:setText('Players (' .. count .. ')')
  end

  -- Players list
  local playerList = instanceWindow:recursiveGetChildById('playerList')
  if playerList then
    playerList:destroyChildren()

    if not instanceData.players or #instanceData.players == 0 then
      -- Empty state
      local emptyLabel = g_ui.createWidget('Label', playerList)
      emptyLabel:setText(tr('No players'))
      emptyLabel:setColor('#555555')
      emptyLabel:setTextAlign(AlignCenter)
      emptyLabel:setFont('verdana-11px-rounded')
      emptyLabel:setHeight(18)
    else
      for _, p in ipairs(instanceData.players) do
        local entry = g_ui.createWidget('PlayerEntry', playerList)
        local playerName = p.name or '???'
        local playerLevel = p.level or 0
        local playerVocation = p.vocation or 'Unknown'
        local vocShort = shortenVocation(playerVocation)

        -- Vocation label
        local vocLabel = entry:getChildById('vocLabel')
        if vocLabel then
          vocLabel:setText(vocShort)
          vocLabel:setColor(getVocationColor(vocShort))
        end

        -- Name label
        local entryNameLabel = entry:getChildById('nameLabel')
        if entryNameLabel then
          entryNameLabel:setText(playerName)
        end

        -- Level label
        local levelLabel = entry:getChildById('levelLabel')
        if levelLabel then
          levelLabel:setText(tostring(playerLevel))
        end

        -- Tooltip on the whole entry
        local tooltipVoc = playerVocation
        if tooltipVoc == 'None' or tooltipVoc == 'No Vocation' then
          tooltipVoc = 'No Vocation'
        end
        entry:setTooltip(tooltipVoc .. ' - Level ' .. tostring(playerLevel))

        -- Right-click context menu
        entry.onMousePress = function(widget, mousePos, button)
          if button == MouseRightButton then
            return showPlayerContextMenu(playerName, mousePos)
          end
          return false
        end

        -- Highlight creature on map when hovering
        entry.onHoverChange = function(widget, hovered)
          if hovered then
            local creature = findCreatureByName(playerName)
            if creature then
              clearCreatureHighlight()
              creature:setHighlight('#00FF00')
              highlightedCreature = creature
            end
          else
            clearCreatureHighlight()
          end
        end
      end
    end
  end
end

function updateTimeDisplay()
  if not instanceWindow or not instanceData then
    return
  end

  local remaining = instanceData.timeRemaining or 0

  -- Update time label (inside the progress bar)
  local timeLabel = instanceWindow:recursiveGetChildById('timeRemaining')
  if timeLabel then
    if remaining > 0 then
      timeLabel:setText(formatTime(remaining))

      -- Blink when critically low (< 30s)
      if remaining < 30 then
        if not timeLabel.isBlinking then
          g_effects.startBlink(timeLabel, 0, 500, false)
          timeLabel.isBlinking = true
        end
      else
        if timeLabel.isBlinking then
          g_effects.stopBlink(timeLabel)
          timeLabel.isBlinking = false
        end
      end
    else
      timeLabel:setText('--:--')

      if timeLabel.isBlinking then
        g_effects.stopBlink(timeLabel)
        timeLabel.isBlinking = false
      end
    end
  end

  -- Update progress bar
  local timeBar = instanceWindow:recursiveGetChildById('timeBar')
  if timeBar then
    if totalTime and totalTime > 0 and remaining > 0 then
      local percent = math.floor((remaining / totalTime) * 100)
      percent = math.max(0, math.min(100, percent))
      timeBar:setPercent(percent)

      if remaining < 60 then
        timeBar:setBackgroundColor('#FF3333')
      elseif remaining < 180 then
        timeBar:setBackgroundColor('#FF8800')
      else
        timeBar:setBackgroundColor('#44DD44')
      end

      timeBar:setVisible(true)
    else
      timeBar:setPercent(0)
      timeBar:setVisible(false)
    end

    -- Tooltip with exact seconds
    local timeBarContainer = instanceWindow:recursiveGetChildById('timeBarContainer')
    if timeBarContainer then
      if remaining > 0 then
        timeBarContainer:setTooltip(tostring(remaining) .. ' seconds remaining')
      else
        timeBarContainer:removeTooltip()
      end
    end
  end
end

-- ============================================================================
-- Server communication
-- ============================================================================

function fetchData()
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(INSTANCE_OPCODE, json.encode({ action = 'fetch' }))
  end
end
