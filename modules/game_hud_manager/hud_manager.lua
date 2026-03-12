local window = nil
local hudDefinitions = {}
local selectedHudId = nil
local styleLoaded = false
local rebuildHudList = nil

local function ensureWindow()
    if window and not window:isDestroyed() then
        return true
    end
    if not styleLoaded then
        g_ui.importStyle('glass_styles')
        g_ui.importStyle('hud_manager')
        styleLoaded = true
    end
    window = g_ui.createWidget('HudManagerWindow', rootWidget)
    if not window or window:isDestroyed() then
        return false
    end
    window.onEscape = function() close() end
    return true
end

local function getSortedDefinitions()
    local defs = {}
    for _, def in pairs(hudDefinitions) do
        table.insert(defs, def)
    end
    table.sort(defs, function(a, b)
        return (a.title or a.id) < (b.title or b.id)
    end)
    return defs
end

local function buildDetails()
    if not window or window:isDestroyed() then return end
    local content = window:recursiveGetChildById('hudDetailsContent')
    if not content then return end
    content:destroyChildren()

    local def = selectedHudId and hudDefinitions[selectedHudId] or nil
    if not def then
        Glass.sectionTitle(content, tr('Select a HUD'))
        return
    end

    Glass.sectionTitle(content, def.title or def.id)

    if def.getConditions and def.setConditionEnabled then
        local COLS = 10
        local CELL = 42
        local GAP  = 4
        local PAD  = 5

        Glass.separator(content)

        local ok, conditions = pcall(def.getConditions)
        if not ok or type(conditions) ~= 'table' then conditions = {} end

        -- Local enabled state (avoids calling def.getConditions on every toggle)
        local enabledMap = {}
        for _, c in ipairs(conditions) do
            enabledMap[c.id] = c.enabled ~= false
        end

        -- Forward-declare so closures can reference before definition
        local updateCount
        local cells = {}

        -- Header row: [Conditions title] ... [count] [+] [-]
        local condRow = g_ui.createWidget('UIWidget', content)
        condRow:setHeight(22)

        local condTitle = g_ui.createWidget('Label', condRow)
        condTitle:setId('condTitle')
        condTitle:setText(tr('Conditions'))
        condTitle:setColor('#c8c8e0ff')
        condTitle:setFont('Verdana Bold-11px')
        condTitle:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        condTitle:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        condTitle:setWidth(80)
        condTitle:setHeight(18)

        local noneBtn = g_ui.createWidget('GlassButtonSmall', condRow)
        noneBtn:setId('condNoneBtn')
        noneBtn:setText('-')
        noneBtn:setTooltip(tr('Disable all conditions'))
        noneBtn:addAnchor(AnchorRight, 'parent', AnchorRight)
        noneBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)

        local allBtn = g_ui.createWidget('GlassButtonSmall', condRow)
        allBtn:setId('condAllBtn')
        allBtn:setText('+')
        allBtn:setTooltip(tr('Enable all conditions'))
        allBtn:addAnchor(AnchorRight, 'condNoneBtn', AnchorLeft)
        allBtn:setMarginRight(4)
        allBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)

        local countLabel = g_ui.createWidget('Label', condRow)
        countLabel:setColor('#606078ff')
        countLabel:setFont('Verdana Bold-11px')
        countLabel:setWidth(52)
        countLabel:setHeight(18)
        countLabel:setTextAlign(AlignRight)
        countLabel:addAnchor(AnchorRight, 'condAllBtn', AnchorLeft)
        countLabel:setMarginRight(8)
        countLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)

        allBtn.onClick = function()
            for _, c in ipairs(conditions) do
                enabledMap[c.id] = true
                if cells[c.id] then cells[c.id]:setOn(true) end
                def.setConditionEnabled(c.id, true)
            end
            if updateCount then updateCount() end
            return true
        end

        noneBtn.onClick = function()
            for _, c in ipairs(conditions) do
                enabledMap[c.id] = false
                if cells[c.id] then cells[c.id]:setOn(false) end
                def.setConditionEnabled(c.id, false)
            end
            if updateCount then updateCount() end
            return true
        end

        -- Icon grid
        local effectiveCols = math.min(COLS, math.max(1, #conditions))
        local nRows = math.ceil(math.max(1, #conditions) / effectiveCols)
        local gridH = PAD + nRows * CELL + math.max(0, nRows - 1) * GAP + PAD

        local gridPanel = g_ui.createWidget('GlassPanel', content)
        gridPanel:setHeight(gridH)

        for i, condition in ipairs(conditions) do
            local col = (i - 1) % effectiveCols
            local row = math.floor((i - 1) / effectiveCols)

            local cell = g_ui.createWidget('GlassConditionCell', gridPanel)
            cell:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            cell:addAnchor(AnchorTop, 'parent', AnchorTop)
            cell:setMarginLeft(PAD + col * (CELL + GAP))
            cell:setMarginTop(PAD + row * (CELL + GAP))
            cell:setWidth(CELL)
            cell:setHeight(CELL)
            cell:setTooltip(condition.label or condition.id)
            cell:setOn(enabledMap[condition.id])

            if condition.icon then
                cell:setImageSource(condition.icon.source)
                cell:setImageClip(condition.icon.clip)
            end

            cells[condition.id] = cell

            cell.onClick = function()
                local newState = not cell:isOn()
                enabledMap[condition.id] = newState
                cell:setOn(newState)
                def.setConditionEnabled(condition.id, newState)
                if updateCount then updateCount() end
                return true
            end
        end

        updateCount = function()
            if not countLabel or countLabel:isDestroyed() then return end
            local n = 0
            for _, c in ipairs(conditions) do
                if enabledMap[c.id] then n = n + 1 end
            end
            countLabel:setText(n .. ' / ' .. #conditions)
        end

        updateCount()
    end

    if def.getOpacity and def.setOpacity then
        Glass.separator(content)
        Glass.opacityControl(content, def.getOpacity() or 0, function(value)
            def.setOpacity(value)
        end)
    end
end

local function selectHud(hudId)
    selectedHudId = hudId
    buildDetails()
    if not window or window:isDestroyed() then return end
    local listContainer = window:recursiveGetChildById('hudListContainer')
    if not listContainer then return end
    for i = 1, listContainer:getChildCount() do
        local row = listContainer:getChildByIndex(i)
        if row and row:getId() then
            row:setOn(row:getId() == selectedHudId)
        end
    end
end

rebuildHudList = function()
    if not window or window:isDestroyed() then return end
    local container = window:recursiveGetChildById('hudListContainer')
    if not container then return end
    container:destroyChildren()

    local defs = getSortedDefinitions()
    for _, def in ipairs(defs) do
        local row = g_ui.createWidget('HudManagerListRow', container)
        row:setId(def.id)
        local enabled = def.getEnabled and def.getEnabled() == true
        row:setText(def.title or def.id)

        local indicator = row:recursiveGetChildById('statusIndicator')

        if def.setEnabled then
            Glass.toggle(row, enabled, function(newState)
                def.setEnabled(newState)
                if indicator then
                    indicator:setBackgroundColor(newState and '#60c060ff' or '#606080ff')
                end
                buildDetails()
            end)
        end

        if indicator then
            indicator:setBackgroundColor(enabled and '#60c060ff' or '#606080ff')
        end

        row.onClick = function() selectHud(def.id) end
    end

    if not selectedHudId or not hudDefinitions[selectedHudId] then
        selectedHudId = defs[1] and defs[1].id or nil
    end
    if selectedHudId then selectHud(selectedHudId) else buildDetails() end
end

local function registerBuiltInHuds()
    if modules.game_specialconditionhud and modules.game_specialconditionhud.getHudManagerDefinition then
        local def = modules.game_specialconditionhud.getHudManagerDefinition()
        if def and def.id then
            hudDefinitions[def.id] = def
        end
    end
end

function registerHudDefinition(def)
    if not def or not def.id then return end
    hudDefinitions[def.id] = def
    rebuildHudList()
end

function unregisterHudDefinition(hudId)
    if not hudId then return end
    hudDefinitions[hudId] = nil
    if selectedHudId == hudId then selectedHudId = nil end
    rebuildHudList()
end

function open(initialHudId)
    registerBuiltInHuds()
    if not ensureWindow() then return end
    if initialHudId and hudDefinitions[initialHudId] then
        selectedHudId = initialHudId
    end
    rebuildHudList()
    window:show()
    window:raise()
    window:focus()
end

function close()
    if window and not window:isDestroyed() then
        window:hide()
    end
end

function init() end

function terminate()
    hudDefinitions = {}
    selectedHudId = nil
    if window and not window:isDestroyed() then
        window:destroy()
    end
    window = nil
end
