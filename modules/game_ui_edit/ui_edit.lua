local lockButtonPanel = nil
local lockButton = nil
local hudManagerButtonPanel = nil
local hudManagerButton = nil
local editMode = false
local listeners = {}
local SETTINGS_KEY = 'UIEditMode'
local LOCK_BUTTON_SIZE = 24
local HUD_MANAGER_BUTTON_MARGIN_TOP = 6
local MARGIN_LEFT_PING = 28
local EDIT_LABEL_MARGIN_TOP = -12
local editLabelStyleLoaded = false
local actionStripStyleLoaded = false
local saveEditMode = function() end

local function notifyListeners()
    for _, cb in ipairs(listeners) do
        cb(editMode)
    end
end

local function updateLockButtonAppearance()
    if not lockButton then
        return
    end
    if lockButton:isDestroyed() then
        lockButton = nil
        return
    end

    lockButton:setOn(editMode)
    lockButton:setColor('#dfdfdfff')

    if editMode then
        lockButton:setTooltip(tr('Lock UI'))
        lockButton:setIcon('/images/game/actionbar/unlocked')
        lockButton:setText('')
    else
        lockButton:setTooltip(tr('Unlock UI'))
        lockButton:setIcon('/images/game/actionbar/locked')
        lockButton:setText('')
    end
end

local function updateHudManagerButtonAppearance()
    if not hudManagerButton then
        return
    end
    if hudManagerButton:isDestroyed() then
        hudManagerButton = nil
        return
    end

    hudManagerButton:setTooltip(tr('HUD Manager'))
    hudManagerButton:setColor('#dfdfdfff')
    hudManagerButton:setIcon('/images/ui/icon-edit')
    hudManagerButton:setText('')
end

function isEditMode()
    return editMode
end

function setEditMode(edit)
    if editMode == edit then
        return
    end
    editMode = edit
    updateLockButtonAppearance()
    saveEditMode()
    notifyListeners()
end

function addEditModeListener(callback)
    table.insert(listeners, callback)
    return function()
        for i, cb in ipairs(listeners) do
            if cb == callback then
                table.remove(listeners, i)
                break
            end
        end
    end
end

local function ensureEditLabelStyle()
    if editLabelStyleLoaded then
        return
    end
    g_ui.importStyle('edit_mode_label')
    editLabelStyleLoaded = true
end

local function ensureActionStripStyle()
    if actionStripStyleLoaded then
        return
    end
    g_ui.importStyle('edit_action_strip')
    actionStripStyleLoaded = true
end

function createEditModeLabel(parentWidget, labelText)
    if not parentWidget then
        return nil
    end
    ensureEditLabelStyle()
    -- Ensure a single label instance per HUD parent.
    local existing = parentWidget:getChildById('editModeLabel')
    if existing and not existing:isDestroyed() then
        existing:destroy()
    end
    local label = g_ui.createWidget('EditModeLabel', parentWidget)
    label:setId('editModeLabel')
    label:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    label:addAnchor(AnchorBottom, 'parent', AnchorTop)
    label:setMarginTop(EDIT_LABEL_MARGIN_TOP)
    label:setText(labelText or '')
    label:setVisible(editMode)
    label:raise()

    local unregister = addEditModeListener(function(enabled)
        if not label or label:isDestroyed() then
            return
        end
        label:setVisible(enabled)
        if enabled then
            label:raise()
        end
    end)

    return {
        widget = label,
        destroy = function()
            if unregister then
                unregister()
                unregister = nil
            end
            if label and not label:isDestroyed() then
                label:destroy()
            end
            label = nil
        end
    }
end

function openHudManager(initialHudId)
    if modules.game_hud_manager and modules.game_hud_manager.open then
        modules.game_hud_manager.open(initialHudId)
    end
end

function createHudActionStrip(parentWidget, opts)
    if not parentWidget then
        return nil
    end
    opts = opts or {}
    ensureActionStripStyle()

    -- When rootPanel is set, create strip on game root so it draws in the same layer as lock/HUD buttons (fixes strip icons not appearing when strip was inside HUD panel)
    local stripParent = (opts.rootPanel and not opts.rootPanel:isDestroyed()) and opts.rootPanel or parentWidget
    local existing = stripParent:getChildById('hudEditActionStrip')
    if existing and not existing:isDestroyed() then
        existing:destroy()
    end

    -- Use vertical style if specified
    local stripStyle = (opts.vertical == true) and 'HudEditActionStripVertical' or 'HudEditActionStrip'
    local strip = g_ui.createWidget(stripStyle, stripParent)
    strip:setId('hudEditActionStrip')
    strip:setVisible(editMode)
    strip:raise()

    local actions = opts.actions or {}
    local actionEntries = {}

    local STRIP_BUTTON_TEXT_FONT = 'verdana-7px-rounded'
    local function applyActionState(entry)
        if not entry or not entry.widget or entry.widget:isDestroyed() then
            return
        end
        local action = entry.action
        if action and action.checkable and action.getState then
            entry.widget:setOn(action.getState() == true)
        end
        if action and action.getText and type(action.getText) == 'function' then
            entry.widget:setText(action.getText())
        end
        if action and action.tooltip then
            if type(action.tooltip) == 'function' then
                entry.widget:setTooltip(action.tooltip(entry.widget:isOn()))
            else
                entry.widget:setTooltip(action.tooltip)
            end
        end
    end

    local function refresh()
        for _, entry in ipairs(actionEntries) do
            applyActionState(entry)
        end
    end

    local ACTION_BUTTON_SIZE = 18
    for i, action in ipairs(actions) do
        local className = action.checkable and 'HudEditActionToggle' or 'HudEditActionButton'
        local button = g_ui.createWidget(className, strip)
        button:setId('hudAction_' .. (action.id or tostring(i)))
        if action.icon then
            button:setIcon(action.icon)
            button:setText('')
            -- Only constrain when the action explicitly requests it (large texture); do not resize icons that are already at or below standard size (avoids distorting pencil, etc.)
            if action.forceIconSize then
                button:setIconSize({ width = ACTION_BUTTON_SIZE, height = ACTION_BUTTON_SIZE })
            end
        else
            if action.getText and type(action.getText) == 'function' then
                button:setText(action.getText())
                button:setFont(STRIP_BUTTON_TEXT_FONT)
            elseif action.text then
                button:setText(action.text)
                button:setFont(STRIP_BUTTON_TEXT_FONT)
            elseif action.id then
                button:setText(string.upper(string.sub(action.id, 1, 1)))
                button:setFont(STRIP_BUTTON_TEXT_FONT)
            end
        end

        button.onClick = function(widget)
            if action.checkable then
                local nextValue = not widget:isOn()
                widget:setOn(nextValue)
                if action.onClick then
                    action.onClick(nextValue)
                end
            else
                if action.onClick then
                    action.onClick()
                end
            end
            refresh()
        end

        local entry = { widget = button, action = action }
        table.insert(actionEntries, entry)
        applyActionState(entry)
    end

    local unregister = addEditModeListener(function(enabled)
        if not strip or strip:isDestroyed() then
            return
        end
        strip:setVisible(enabled)
        if enabled then
            refresh()
            strip:raise()
        end
    end)

    return {
        widget = strip,
        refresh = refresh,
        destroy = function()
            if unregister then
                unregister()
                unregister = nil
            end
            if strip and not strip:isDestroyed() then
                strip:destroy()
            end
            strip = nil
            actionEntries = {}
        end
    }
end

local function ensureLockButton()
    if lockButtonPanel and lockButtonPanel:isDestroyed() then
        lockButtonPanel = nil
        lockButton = nil
    end
    if hudManagerButtonPanel and hudManagerButtonPanel:isDestroyed() then
        hudManagerButtonPanel = nil
        hudManagerButton = nil
    end
    if lockButton and lockButton:isDestroyed() then
        lockButton = nil
    end
    if hudManagerButton and hudManagerButton:isDestroyed() then
        hudManagerButton = nil
    end
    if not modules.game_interface then
        return
    end
    local mapPanel = modules.game_interface.getMapPanel()
    if not mapPanel then
        return
    end
    -- Recover from hot-reload leftovers: if an old panel exists in map with same id
    -- (possibly bound to previous module instance), destroy it and recreate.
    local existingPanel = mapPanel:getChildById('uiEditLockPanel')
    if existingPanel and existingPanel ~= lockButtonPanel then
        existingPanel:destroy()
    end
    local existingHudManagerPanel = mapPanel:getChildById('uiEditHudManagerPanel')
    if existingHudManagerPanel and existingHudManagerPanel ~= hudManagerButtonPanel then
        existingHudManagerPanel:destroy()
    end
    if lockButtonPanel and lockButtonPanel:getParent() ~= mapPanel then
        if not lockButtonPanel:isDestroyed() then
            lockButtonPanel:destroy()
        end
        lockButtonPanel = nil
        lockButton = nil
    end
    if hudManagerButtonPanel and hudManagerButtonPanel:getParent() ~= mapPanel then
        if not hudManagerButtonPanel:isDestroyed() then
            hudManagerButtonPanel:destroy()
        end
        hudManagerButtonPanel = nil
        hudManagerButton = nil
    end

    if not lockButtonPanel then
        lockButtonPanel = g_ui.createWidget('UIWidget', mapPanel)
        lockButtonPanel:setId('uiEditLockPanel')
        lockButtonPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
        lockButtonPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        lockButtonPanel:setMarginTop(35)
        lockButtonPanel:setMarginLeft(4)
        lockButtonPanel:setSize({ width = LOCK_BUTTON_SIZE, height = LOCK_BUTTON_SIZE })
        lockButtonPanel:setFocusable(false)

        lockButtonPanel:setBackgroundColor('#00000066')
        lockButtonPanel:setBorderWidth(1)
        lockButtonPanel:setBorderColor('#505050')
    end

    if not lockButton then
        lockButton = lockButtonPanel:getChildById('uiEditLockButton')
    end
    if not lockButton then
        lockButton = g_ui.createWidget('MainToggleButton', lockButtonPanel)
        lockButton:setId('uiEditLockButton')
    end

    lockButton:setSize({ width = 20, height = 20 })
    lockButton:breakAnchors()
    lockButton:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    lockButton:addAnchor(AnchorTop, 'parent', AnchorTop)
    lockButton:setFocusable(false)
    lockButton.onClick = function()
        setEditMode(not editMode)
    end
    updateLockButtonAppearance()

    lockButtonPanel:show()
    lockButton:show()
    lockButtonPanel:raise()

    if not hudManagerButtonPanel then
        hudManagerButtonPanel = g_ui.createWidget('UIWidget', mapPanel)
        hudManagerButtonPanel:setId('uiEditHudManagerPanel')
        hudManagerButtonPanel:addAnchor(AnchorTop, 'uiEditLockPanel', AnchorBottom)
        hudManagerButtonPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        hudManagerButtonPanel:setMarginTop(HUD_MANAGER_BUTTON_MARGIN_TOP)
        hudManagerButtonPanel:setMarginLeft(4)
        hudManagerButtonPanel:setSize({ width = LOCK_BUTTON_SIZE, height = LOCK_BUTTON_SIZE })
        hudManagerButtonPanel:setFocusable(false)

        hudManagerButtonPanel:setBackgroundColor('#00000066')
        hudManagerButtonPanel:setBorderWidth(1)
        hudManagerButtonPanel:setBorderColor('#505050')
    end

    if not hudManagerButton then
        hudManagerButton = hudManagerButtonPanel:getChildById('uiEditHudManagerButton')
    end
    if not hudManagerButton then
        hudManagerButton = g_ui.createWidget('MainToggleButton', hudManagerButtonPanel)
        hudManagerButton:setId('uiEditHudManagerButton')
    end

    hudManagerButton:setSize({ width = 20, height = 20 })
    hudManagerButton:breakAnchors()
    hudManagerButton:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    hudManagerButton:addAnchor(AnchorTop, 'parent', AnchorTop)
    hudManagerButton:setFocusable(false)
    hudManagerButton.onClick = function()
        openHudManager(nil)
    end
    updateHudManagerButtonAppearance()

    hudManagerButtonPanel:show()
    hudManagerButton:show()
    hudManagerButtonPanel:raise()

    -- Push ping/fps widget to the right (deferred: topmenu adds PingWidget in addEvent)
    scheduleEvent(function()
        if not mapPanel or not lockButtonPanel or lockButtonPanel:isDestroyed() then
            return
        end
        for i = 1, mapPanel:getChildCount() do
            local child = mapPanel:getChildByIndex(i)
            if child ~= lockButtonPanel and (child:recursiveGetChildById('ping') or child:recursiveGetChildById('fps')) then
                child:setMarginLeft(MARGIN_LEFT_PING)
                break
            end
        end
    end, 100)
end

local function loadSavedEditMode()
    local node = g_settings.getNode(SETTINGS_KEY)
    if node and node.editMode == true then
        editMode = true
    else
        editMode = false
    end
end

saveEditMode = function()
    local node = g_settings.getNode(SETTINGS_KEY)
    if not node then
        node = {}
        g_settings.setNode(SETTINGS_KEY, node)
    end
    node.editMode = editMode
    g_settings.setNode(SETTINGS_KEY, node)
    g_settings.save()
end

local gameConnection = nil

function init()
    loadSavedEditMode()
    gameConnection = connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
    if g_game.isOnline() then
        ensureLockButton()
    end
end

function onGameStart()
    -- Always start locked after relog to avoid stale unlock state.
    setEditMode(false)
    ensureLockButton()
end

function onGameEnd()
    -- Never keep UI edit unlocked across relog.
    setEditMode(false)
    saveEditMode()
    if lockButtonPanel and not lockButtonPanel:isDestroyed() then
        lockButtonPanel:destroy()
    end
    if hudManagerButtonPanel and not hudManagerButtonPanel:isDestroyed() then
        hudManagerButtonPanel:destroy()
    end
    lockButtonPanel = nil
    lockButton = nil
    hudManagerButtonPanel = nil
    hudManagerButton = nil
end

function terminate()
    if gameConnection then
        disconnect(g_game, gameConnection)
        gameConnection = nil
    end
    listeners = {}
    if lockButtonPanel and not lockButtonPanel:isDestroyed() then
        lockButtonPanel:destroy()
    end
    if hudManagerButtonPanel and not hudManagerButtonPanel:isDestroyed() then
        hudManagerButtonPanel:destroy()
    end
    if modules.game_interface then
        local mapPanel = modules.game_interface.getMapPanel()
        if mapPanel then
            local existingPanel = mapPanel:getChildById('uiEditLockPanel')
            if existingPanel and (not lockButtonPanel or existingPanel ~= lockButtonPanel) then
                existingPanel:destroy()
            end
            local existingHudManagerPanel = mapPanel:getChildById('uiEditHudManagerPanel')
            if existingHudManagerPanel and (not hudManagerButtonPanel or existingHudManagerPanel ~= hudManagerButtonPanel) then
                existingHudManagerPanel:destroy()
            end
        end
    end
    lockButtonPanel = nil
    lockButton = nil
    hudManagerButtonPanel = nil
    hudManagerButton = nil
end
