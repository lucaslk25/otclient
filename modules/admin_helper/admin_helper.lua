-- Admin Helper Panel
-- Stack-based navigation with server-fetched data via opcode 211

local ADMIN_OPCODE = 211
local PAGE_SIZE = 8

local adminHelperWindow = nil
local adminHelperButton = nil

local allPlayers = {}
local currentPage = 1
local selectedPlayerName = nil

local raidList = {}
local selectedRaid = nil

local teleportData = nil
local currentTpCategory = nil
local tpFilteredList = {}
local tpCurrentPage = 1
local TP_PAGE_SIZE = 8

local screenStack = {}

local SCREENS = {
  'screenMain', 'screenPlayers', 'screenPlayerActions',
  'screenRaids', 'screenRaidActions', 'screenTeleports', 'screenTpList', 'screenInstance'
}

local SCREEN_TITLES = {
  screenMain          = 'Admin Helper',
  screenPlayers       = 'Players',
  screenPlayerActions = 'Player Actions',
  screenRaids         = 'Raids',
  screenRaidActions   = 'Raid Actions',
  screenTeleports     = 'Teleports',
  screenTpList        = 'Teleports',
  screenInstance      = 'Instance',
}

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
  ['EK'] = '#E05050',
  ['K']  = '#E05050',
  ['RP'] = '#50C878',
  ['P']  = '#50C878',
  ['ED'] = '#5098E0',
  ['D']  = '#5098E0',
  ['MS'] = '#B06DE0',
  ['S']  = '#B06DE0',
}

local function shortenVocation(vocation)
  if not vocation or vocation == '' then return '--' end
  return VOCATION_SHORT[vocation] or string.sub(vocation, 1, 2)
end

local function getVocationColor(vocShort)
  return VOCATION_COLOR[vocShort] or '#AAAAAA'
end

-- ============================================================================
-- Screen navigation
-- ============================================================================

local function displayScreen(name)
  if not adminHelperWindow then return end

  for _, id in ipairs(SCREENS) do
    local panel = adminHelperWindow:recursiveGetChildById(id)
    if panel then panel:setVisible(id == name) end
  end

  local title = adminHelperWindow:recursiveGetChildById('screenTitle')
  if title then title:setText(SCREEN_TITLES[name] or name) end

  local backBtn = adminHelperWindow:recursiveGetChildById('backButton')
  if backBtn then backBtn:setVisible(name ~= 'screenMain') end
end

local function navigateTo(name)
  table.insert(screenStack, name)
  displayScreen(name)
end

local function goBack()
  if #screenStack <= 1 then return end
  table.remove(screenStack)
  local prev = screenStack[#screenStack]
  if prev then
    displayScreen(prev)
  end
end

local function resetNavigation()
  screenStack = {}
  navigateTo('screenMain')
end

-- ============================================================================
-- UI header buttons (hide unused)
-- ============================================================================

local function setupUIButtons()
  local toggleFilterButton = adminHelperWindow:recursiveGetChildById('toggleFilterButton')
  if toggleFilterButton then
    toggleFilterButton:setVisible(false)
    toggleFilterButton:setOn(false)
  end
  local newWindowButton = adminHelperWindow:recursiveGetChildById('newWindowButton')
  if newWindowButton then
    newWindowButton:setVisible(false)
  end
end

-- ============================================================================
-- Server communication
-- ============================================================================

local function sendRequest(action)
  local proto = g_game.getProtocolGame()
  if proto then
    proto:sendExtendedOpcode(ADMIN_OPCODE, json.encode({ action = action }))
  end
end

local function sendCommand(cmd)
  if not g_game.isOnline() then return end
  g_game.talk(cmd)
end

-- ============================================================================
-- Player list (server-fetched, paginated)
-- ============================================================================

local function getTotalPages()
  if #allPlayers == 0 then return 1 end
  return math.ceil(#allPlayers / PAGE_SIZE)
end

local function getPageSlice()
  local total = getTotalPages()
  currentPage = math.max(1, math.min(currentPage, total))
  local startIdx = (currentPage - 1) * PAGE_SIZE + 1
  local endIdx = math.min(startIdx + PAGE_SIZE - 1, #allPlayers)
  local slice = {}
  for i = startIdx, endIdx do
    table.insert(slice, allPlayers[i])
  end
  return slice
end

local function selectPlayer(name)
  selectedPlayerName = name
  local label = adminHelperWindow:recursiveGetChildById('selectedPlayerLabel')
  if label then label:setText(name) end
  navigateTo('screenPlayerActions')
end

local function refreshPlayerListUI()
  local listContainer = adminHelperWindow:recursiveGetChildById('playerListContainer')
  if not listContainer then return end

  listContainer:destroyChildren()

  local slice = getPageSlice()

  if #slice == 0 then
    local hint = g_ui.createWidget('Label', listContainer)
    if #allPlayers == 0 then
      hint:setText(tr('Click "Refresh Players" to load'))
    else
      hint:setText(tr('No players on this page'))
    end
    hint:setTextAlign(AlignCenter)
    hint:setHeight(30)
    hint:setColor('#888888')
    hint:setFont('Verdana Bold-11px')
  else
    for _, player in ipairs(slice) do
      local row = g_ui.createWidget('PlayerEntryRow', listContainer)
      local playerName = player.name or '???'
      local playerLevel = player.level or 0
      local playerVocation = player.vocation or 'Unknown'
      local vocShort = shortenVocation(playerVocation)

      local vocLabel = row:getChildById('vocLabel')
      if vocLabel then
        vocLabel:setText(vocShort)
        vocLabel:setColor(getVocationColor(vocShort))
      end

      local nameLabel = row:getChildById('nameLabel')
      if nameLabel then nameLabel:setText(playerName) end

      local levelLabel = row:getChildById('levelLabel')
      if levelLabel then levelLabel:setText(tostring(playerLevel)) end

      row:setTooltip(playerVocation .. ' - Level ' .. tostring(playerLevel))

      row.onMousePress = function(widget, mousePos, button)
        if button == MouseLeftButton then
          selectPlayer(playerName)
          return true
        end
      end
    end
  end

  local pageLabel = adminHelperWindow:recursiveGetChildById('pageLabel')
  if pageLabel then
    pageLabel:setText(tr('%d / %d', currentPage, getTotalPages()))
  end

  local paginationBar = adminHelperWindow:recursiveGetChildById('paginationBar')
  if paginationBar then
    paginationBar:setVisible(getTotalPages() > 1)
  end

  local prevBtn = adminHelperWindow:recursiveGetChildById('prevPageButton')
  local nextBtn = adminHelperWindow:recursiveGetChildById('nextPageButton')
  if prevBtn then prevBtn:setEnabled(currentPage > 1) end
  if nextBtn then nextBtn:setEnabled(currentPage < getTotalPages()) end
end

local function onPrevPage()
  if currentPage <= 1 then return end
  currentPage = currentPage - 1
  refreshPlayerListUI()
end

local function onNextPage()
  if currentPage >= getTotalPages() then return end
  currentPage = currentPage + 1
  refreshPlayerListUI()
end

-- ============================================================================
-- Loading hint
-- ============================================================================

local function showLoadingHint(containerId)
  local container = adminHelperWindow:recursiveGetChildById(containerId)
  if not container then return end
  container:destroyChildren()
  local hint = g_ui.createWidget('Label', container)
  hint:setText(tr('Loading...'))
  hint:setTextAlign(AlignCenter)
  hint:setHeight(30)
  hint:setColor('#AAAAAA')
  hint:setFont('Verdana Bold-11px')
end

-- ============================================================================
-- Render functions (called from opcode handler)
-- ============================================================================

local function renderPlayers(list)
  allPlayers = list or {}
  currentPage = 1
  refreshPlayerListUI()
end

local function selectRaid(raid)
  selectedRaid = raid

  local nameLabel = adminHelperWindow:recursiveGetChildById('selectedRaidNameLabel')
  if nameLabel then nameLabel:setText(raid.name or '--') end

  local typeLabel = adminHelperWindow:recursiveGetChildById('raidTypeLabel')
  if typeLabel then
    local typeMap = {
      raidInstance = 'Raid Instance',
      bossLever   = 'Boss Lever',
    }
    typeLabel:setText(typeMap[raid.type] or raid.type or '--')
  end

  local bossSprite = adminHelperWindow:recursiveGetChildById('raidBossSprite')
  if bossSprite and raid.outfit and raid.outfit.type and raid.outfit.type > 0 then
    bossSprite:setOutfit({
      type   = raid.outfit.type,
      head   = raid.outfit.head or 0,
      body   = raid.outfit.body or 0,
      legs   = raid.outfit.legs or 0,
      feet   = raid.outfit.feet or 0,
      addons = raid.outfit.addons or 0,
    })
    bossSprite:getCreature():setStaticWalking(1000)
    bossSprite:setVisible(true)
  else
    bossSprite:setVisible(false)
  end

  local startBtn = adminHelperWindow:recursiveGetChildById('startRaidBtn')
  if startBtn then
    startBtn:setVisible(raid.raidCommand ~= nil and raid.raidCommand ~= json.null)
  end

  navigateTo('screenRaidActions')
end

local function renderRaids(list)
  raidList = list or {}

  local container = adminHelperWindow:recursiveGetChildById('raidListContainer')
  if not container then return end

  container:destroyChildren()

  if #raidList == 0 then
    local hint = g_ui.createWidget('Label', container)
    hint:setText(tr('No raids available'))
    hint:setTextAlign(AlignCenter)
    hint:setHeight(30)
    hint:setColor('#888888')
    hint:setFont('Verdana Bold-11px')
    return
  end

  for _, raid in ipairs(raidList) do
    local row = g_ui.createWidget('RaidEntryRow', container)

    local nameLabel = row:getChildById('raidNameLabel')
    if nameLabel then nameLabel:setText(raid.name or '???') end

    local bossSprite = row:getChildById('bossSprite')
    if bossSprite and raid.outfit and raid.outfit.type and raid.outfit.type > 0 then
      bossSprite:setOutfit({
        type   = raid.outfit.type,
        head   = raid.outfit.head or 0,
        body   = raid.outfit.body or 0,
        legs   = raid.outfit.legs or 0,
        feet   = raid.outfit.feet or 0,
        addons = raid.outfit.addons or 0,
      })
      bossSprite:getCreature():setStaticWalking(1000)
    end

    if raid.requiredLevel and raid.requiredLevel > 0 then
      row:setTooltip('Level ' .. tostring(raid.requiredLevel) .. '+')
    end

    row.onMousePress = function(widget, mousePos, button)
      if button == MouseLeftButton then
        selectRaid(raid)
        return true
      end
    end
  end
end

local TP_CATEGORY_TITLES = {
  towns       = 'Towns',
  raidInstance = 'Raid Instances',
  bossLever   = 'Boss Levers',
  hunt        = 'Hunts',
}

local function renderTeleports(data)
  teleportData = data
end

local function getTpTotalPages()
  if #tpFilteredList == 0 then return 1 end
  return math.ceil(#tpFilteredList / TP_PAGE_SIZE)
end

local function refreshTpListUI()
  local container = adminHelperWindow:recursiveGetChildById('tpListContainer')
  if not container then return end
  container:destroyChildren()

  local total = getTpTotalPages()
  tpCurrentPage = math.max(1, math.min(tpCurrentPage, total))
  local startIdx = (tpCurrentPage - 1) * TP_PAGE_SIZE + 1
  local endIdx = math.min(startIdx + TP_PAGE_SIZE - 1, #tpFilteredList)

  if #tpFilteredList == 0 then
    local hint = g_ui.createWidget('Label', container)
    hint:setText(tr('No entries available'))
    hint:setTextAlign(AlignCenter)
    hint:setHeight(30)
    hint:setColor('#888888')
    hint:setFont('Verdana Bold-11px')
  else
    for i = startIdx, endIdx do
      local entry = tpFilteredList[i]
      local row = g_ui.createWidget('TeleportEntryRow', container)
      local label = row:getChildById('tpNameLabel')
      if label then label:setText(entry.name or '???') end

      local hasPos = entry.entryPos and entry.entryPos ~= json.null
      if hasPos then
        row:setTooltip(string.format('Pos: %d, %d, %d', entry.entryPos.x, entry.entryPos.y, entry.entryPos.z))
      end

      row.onMousePress = function(widget, mousePos, button)
        if button == MouseLeftButton then
          if entry.isTown then
            sendCommand('/town ' .. entry.name)
          elseif hasPos then
            sendCommand(string.format('/pos %d, %d, %d', entry.entryPos.x, entry.entryPos.y, entry.entryPos.z))
          end
          return true
        end
      end
    end
  end

  local pageLabel = adminHelperWindow:recursiveGetChildById('tpPageLabel')
  if pageLabel then
    pageLabel:setText(tr('%d / %d', tpCurrentPage, total))
  end

  local paginationBar = adminHelperWindow:recursiveGetChildById('tpPaginationBar')
  if paginationBar then
    paginationBar:setVisible(total > 1)
  end

  local prevBtn = adminHelperWindow:recursiveGetChildById('tpPrevPageBtn')
  local nextBtn = adminHelperWindow:recursiveGetChildById('tpNextPageBtn')
  if prevBtn then prevBtn:setEnabled(tpCurrentPage > 1) end
  if nextBtn then nextBtn:setEnabled(tpCurrentPage < total) end
end

local function displayTpCategory(category)
  currentTpCategory = category
  tpCurrentPage = 1
  tpFilteredList = {}

  local title = adminHelperWindow:recursiveGetChildById('screenTitle')
  if title then title:setText(TP_CATEGORY_TITLES[category] or 'Teleports') end

  if not teleportData then
    refreshTpListUI()
    return
  end

  if category == 'towns' then
    local towns = teleportData.towns or {}
    for _, town in ipairs(towns) do
      table.insert(tpFilteredList, { name = town.name, isTown = true })
    end
  else
    local hunts = teleportData.hunts or {}
    for _, h in ipairs(hunts) do
      if h.type == category then
        table.insert(tpFilteredList, h)
      end
    end
  end

  refreshTpListUI()
end

-- ============================================================================
-- Opcode handler
-- ============================================================================

function onAdminOpcode(protocol, opcode, buffer)
  local ok, data = pcall(json.decode, buffer)
  if not ok or not data or not data.action then return end

  if data.action == 'players' then
    renderPlayers(data.data)
  elseif data.action == 'raids' then
    renderRaids(data.data)
  elseif data.action == 'teleports' then
    renderTeleports(data.data)
  end
end

-- ============================================================================
-- Module lifecycle
-- ============================================================================

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd   = onGameEnd
  })

  ProtocolGame.registerExtendedOpcode(ADMIN_OPCODE, onAdminOpcode)

  if modules.game_mainpanel then
    adminHelperButton = modules.game_mainpanel.addToggleButton(
      'adminHelperButton',
      tr('Admin Helper') .. ' (Alt+H)',
      '/images/options/button_control',
      toggle,
      false,
      15
    )
    adminHelperButton:setOn(false)
  end

  adminHelperWindow = g_ui.loadUI('admin_helper')
  adminHelperWindow:setContentMinimumHeight(120)

  Keybind.new('Windows', 'Show/hide admin helper window', 'Alt+H', '')
  Keybind.bind('Windows', 'Show/hide admin helper window', {
    { type = KEY_DOWN, callback = toggle }
  })

  adminHelperWindow:setup()
  setupUIButtons()

  -- Back button
  local backBtn = adminHelperWindow:recursiveGetChildById('backButton')
  if backBtn then backBtn.onClick = goBack end

  -- Main menu buttons -> fetch from server on each click
  local btnPlayers = adminHelperWindow:recursiveGetChildById('btnPlayers')
  if btnPlayers then
    btnPlayers.onClick = function()
      navigateTo('screenPlayers')
      showLoadingHint('playerListContainer')
      sendRequest('players')
    end
  end

  local btnRaids = adminHelperWindow:recursiveGetChildById('btnRaids')
  if btnRaids then
    btnRaids.onClick = function()
      navigateTo('screenRaids')
      showLoadingHint('raidListContainer')
      sendRequest('raids')
    end
  end

  local btnTeleports = adminHelperWindow:recursiveGetChildById('btnTeleports')
  if btnTeleports then
    btnTeleports.onClick = function()
      navigateTo('screenTeleports')
      sendRequest('teleports')
    end
  end

  local btnInstance = adminHelperWindow:recursiveGetChildById('btnInstance')
  if btnInstance then btnInstance.onClick = function() navigateTo('screenInstance') end end

  -- Refresh buttons
  local refreshPlayersBtn = adminHelperWindow:recursiveGetChildById('refreshPlayersBtn')
  if refreshPlayersBtn then
    refreshPlayersBtn.onClick = function()
      showLoadingHint('playerListContainer')
      sendRequest('players')
    end
  end

  local refreshRaidsBtn = adminHelperWindow:recursiveGetChildById('refreshRaidsBtn')
  if refreshRaidsBtn then
    refreshRaidsBtn.onClick = function()
      showLoadingHint('raidListContainer')
      sendRequest('raids')
    end
  end

  -- Teleport category buttons
  local btnTpTowns = adminHelperWindow:recursiveGetChildById('btnTpTowns')
  if btnTpTowns then
    btnTpTowns.onClick = function()
      navigateTo('screenTpList')
      displayTpCategory('towns')
    end
  end

  local btnTpRaids = adminHelperWindow:recursiveGetChildById('btnTpRaids')
  if btnTpRaids then
    btnTpRaids.onClick = function()
      navigateTo('screenTpList')
      displayTpCategory('raidInstance')
    end
  end

  local btnTpBossLevers = adminHelperWindow:recursiveGetChildById('btnTpBossLevers')
  if btnTpBossLevers then
    btnTpBossLevers.onClick = function()
      navigateTo('screenTpList')
      displayTpCategory('bossLever')
    end
  end

  local btnTpHunts = adminHelperWindow:recursiveGetChildById('btnTpHunts')
  if btnTpHunts then
    btnTpHunts.onClick = function()
      navigateTo('screenTpList')
      displayTpCategory('hunt')
    end
  end

  -- Teleport pagination
  local tpPrevBtn = adminHelperWindow:recursiveGetChildById('tpPrevPageBtn')
  if tpPrevBtn then
    tpPrevBtn.onClick = function()
      if tpCurrentPage <= 1 then return end
      tpCurrentPage = tpCurrentPage - 1
      refreshTpListUI()
    end
  end

  local tpNextBtn = adminHelperWindow:recursiveGetChildById('tpNextPageBtn')
  if tpNextBtn then
    tpNextBtn.onClick = function()
      if tpCurrentPage >= getTpTotalPages() then return end
      tpCurrentPage = tpCurrentPage + 1
      refreshTpListUI()
    end
  end

  -- Pagination
  local prevBtn = adminHelperWindow:recursiveGetChildById('prevPageButton')
  if prevBtn then prevBtn.onClick = onPrevPage end

  local nextBtn = adminHelperWindow:recursiveGetChildById('nextPageButton')
  if nextBtn then nextBtn.onClick = onNextPage end

  -- Player actions
  local gotoBtn = adminHelperWindow:recursiveGetChildById('gotoButton')
  if gotoBtn then
    gotoBtn.onClick = function()
      if selectedPlayerName then
        sendCommand('/goto ' .. selectedPlayerName)
      end
    end
  end

  local pullBtn = adminHelperWindow:recursiveGetChildById('pullButton')
  if pullBtn then
    pullBtn.onClick = function()
      if selectedPlayerName then
        sendCommand('/c ' .. selectedPlayerName)
      end
    end
  end

  -- Raid actions
  local startRaidBtn = adminHelperWindow:recursiveGetChildById('startRaidBtn')
  if startRaidBtn then
    startRaidBtn.onClick = function()
      if selectedRaid and selectedRaid.raidCommand then
        sendCommand('/raid ' .. selectedRaid.raidCommand)
      end
    end
  end

  local tpToRaidBtn = adminHelperWindow:recursiveGetChildById('tpToRaidBtn')
  if tpToRaidBtn then
    tpToRaidBtn.onClick = function()
      if selectedRaid and selectedRaid.entryPos and selectedRaid.entryPos ~= json.null then
        local pos = selectedRaid.entryPos
        sendCommand(string.format('/pos %d, %d, %d', pos.x, pos.y, pos.z))
      end
    end
  end

  -- Instance actions
  local instanceInfoBtn = adminHelperWindow:recursiveGetChildById('instanceInfoBtn')
  if instanceInfoBtn then
    instanceInfoBtn.onClick = function() sendCommand('/instance info') end
  end

  local instanceLeaveBtn = adminHelperWindow:recursiveGetChildById('instanceLeaveBtn')
  if instanceLeaveBtn then
    instanceLeaveBtn.onClick = function() sendCommand('/instance leave') end
  end

  -- Start on main screen
  resetNavigation()

  if adminHelperButton then
    adminHelperButton:hide()
  end

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd   = onGameEnd
  })

  ProtocolGame.unregisterExtendedOpcode(ADMIN_OPCODE)
  Keybind.delete('Windows', 'Show/hide admin helper window')

  if adminHelperWindow then
    adminHelperWindow:destroy()
    adminHelperWindow = nil
  end
  if adminHelperButton then
    adminHelperButton:destroy()
    adminHelperButton = nil
  end
end

-- ============================================================================
-- Game events
-- ============================================================================

function onGameStart()
  adminHelperWindow:setupOnStart()
  if adminHelperButton then
    adminHelperButton:show()
  end
end

function onGameEnd()
  if adminHelperWindow then
    adminHelperWindow:setParent(nil, true)
  end
  if adminHelperButton then
    adminHelperButton:setOn(false)
    adminHelperButton:hide()
  end

  selectedPlayerName = nil
  selectedRaid = nil
  allPlayers = {}
  raidList = {}
  teleportData = nil
  currentTpCategory = nil
  tpFilteredList = {}
  tpCurrentPage = 1
  currentPage = 1
  screenStack = {}
end

-- ============================================================================
-- Window show/hide/toggle
-- ============================================================================

function showWindow()
  if not adminHelperWindow then return end
  if not adminHelperWindow:getParent() then
    local panel = modules.game_interface.findContentPanelAvailable(
      adminHelperWindow,
      adminHelperWindow:getMinimumHeight()
    )
    if panel then
      panel:addChild(adminHelperWindow)
    end
  end
  adminHelperWindow:open()
  if adminHelperButton then
    adminHelperButton:setOn(true)
    adminHelperButton:show()
  end
end

function hideWindow()
  if adminHelperWindow then
    adminHelperWindow:close()
  end
  if adminHelperButton then
    adminHelperButton:setOn(false)
  end
end

function toggle()
  if not adminHelperWindow then return end
  if adminHelperButton and adminHelperButton:isOn() then
    hideWindow()
  else
    if not adminHelperWindow:getParent() then
      local panel = modules.game_interface.findContentPanelAvailable(
        adminHelperWindow,
        adminHelperWindow:getMinimumHeight()
      )
      if not panel then return end
      panel:addChild(adminHelperWindow)
    end
    adminHelperWindow:open()
    if adminHelperButton then adminHelperButton:setOn(true) end
  end
end

function onOpen()
  if adminHelperButton then
    adminHelperButton:setOn(true)
  end
end

function onClose()
  if adminHelperButton then
    adminHelperButton:setOn(false)
  end
end
