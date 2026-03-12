conditionHudPanel = nil
local stateConnection = nil
local gameConnection = nil
local editModeListenerUnregister = nil
local editModeLabelHandle = nil
local editActionStripHandle = nil
local mapResizeHooked = false
local mapResizeHandler = nil
local rootResizeHandler = nil
-- When true, onGeometryChange must not save (we are programmatically repositioning)
local programmaticRepositioning = false

local SETTINGS_KEY = 'CharConditionHUD'
local CONDITIONS_KEY = 'specialConditionHUDConditions'
local POSITION_MODEL_VERSION = 2
local ICON_SIZE = 20
local ICON_SPACING = 6
local PANEL_MARGIN = 3
local BUTTON_SIZE = 18
local DEFAULT_X = 50
local DEFAULT_Y = 50
local DEFAULT_OPACITY = 87
-- Min dimensions: vertical = width only icon+margin (button below icons); horizontal = height 24, width 42
local MIN_WIDTH_V = ICON_SIZE + PANEL_MARGIN * 2
local MIN_HEIGHT_H = ICON_SIZE + PANEL_MARGIN * 2
-- Vertical: content for 1 icon = 30; +10 gives ~5px respiro top/bottom
local MIN_HEIGHT_V = 36
local MIN_WIDTH_H = 42
local SIZE_TRANSITION_MS = 220
local SIZE_TRANSITION_STEP_MS = 30
local MARGIN_VERTICAL_FLOW = 3   -- top/bottom when vertical (reduced from 10 - was too large)
local MARGIN_HORIZONTAL_FLOW = 10  -- left/right when horizontal
local MARGIN_VERTICAL_PERP = 3   -- left/right when vertical
local MARGIN_HORIZONTAL_PERP = 3  -- top/bottom when horizontal (6 caused icon overflow/offset)
local RESIZE_HANDLE_SIZE = 4
local RESIZE_HANDLE_COLOR = '#b3b3b3ff'
local RESIZE_HANDLE_HOVER_COLOR = '#f2f2f2ff'
local RESIZE_HANDLE_OPACITY = 1.0
local RESIZE_HANDLE_HOVER_OPACITY = 1.0
local RESIZE_HANDLE_HINT = tr('Drag to resize')
local LABEL_TEXT_HORIZONTAL = tr('special conditions')
local HUD_ID = 'condition'

local function toVerticalLabelText(text)
    if not text or #text == 0 then
        return ''
    end
    local words = {}
    -- Split by spaces to get words
    for word in text:gmatch('%S+') do
        local chars = {}
        for i = 1, #word do
            table.insert(chars, word:sub(i, i))
        end
        table.insert(words, table.concat(chars, '\n'))
    end
    -- Join words with extra spacing (empty lines between words)
    return table.concat(words, '\n\n')
end

local function isEditMode()
    if modules.game_ui_edit then
        return modules.game_ui_edit.isEditMode()
    end
    return false
end

local function applyEditModeToPanel(editMode)
    if not conditionHudPanel then
        return
    end
    local box = conditionHudPanel:getChildById('conditionHUDBox')
    conditionHudPanel:setDraggable(editMode)
    conditionHudPanel:setPhantom(not editMode)
    if box then
        box:setDraggable(editMode)
        box:setPhantom(not editMode)
    end
    -- Call via module to avoid nil when callback runs from game_ui_edit context
    if modules.game_specialconditionhud and modules.game_specialconditionhud.updatePanelSize then
        modules.game_specialconditionhud.updatePanelSize()
    end
end

local function applyContainerMarginsForOrientation(container, vertical)
    if not container then return end
    if vertical then
        container:setMarginTop(MARGIN_VERTICAL_FLOW)
        container:setMarginBottom(MARGIN_VERTICAL_FLOW)
        container:setMarginLeft(MARGIN_VERTICAL_PERP)
        container:setMarginRight(MARGIN_VERTICAL_PERP)
    else
        container:setMarginTop(MARGIN_HORIZONTAL_PERP)
        container:setMarginBottom(MARGIN_HORIZONTAL_PERP)
        container:setMarginLeft(MARGIN_HORIZONTAL_FLOW)
        container:setMarginRight(MARGIN_HORIZONTAL_FLOW)
    end
end

local function applyCenteringPadding(container, vertical)
    if not container then return end
    local count = #container:getChildren()
    if count == 0 then
        container:setPaddingTop(0)
        container:setPaddingBottom(0)
        container:setPaddingLeft(0)
        container:setPaddingRight(0)
        return
    end
    local contentH = count * (ICON_SIZE + ICON_SPACING) - ICON_SPACING
    local contentW = contentH
    local containerH = container:getHeight()
    local containerW = container:getWidth()
    if containerH <= 0 or containerW <= 0 then return end
    if vertical then
        local extra = math.max(0, containerH - contentH)
        local padBottom = math.floor(extra / 2)
        local padTop = extra - padBottom
        container:setPaddingTop(padTop)
        container:setPaddingBottom(padBottom)
        container:setPaddingLeft(0)
        container:setPaddingRight(0)
    else
        local extra = math.max(0, containerW - contentW)
        local padRight = math.floor(extra / 2)
        local padLeft = extra - padRight
        container:setPaddingLeft(padLeft)
        container:setPaddingRight(padRight)
        container:setPaddingTop(0)
        container:setPaddingBottom(0)
    end
end

local function updateEditModeLabelLayout(vertical)
    if not editModeLabelHandle or not editModeLabelHandle.widget then
        return
    end
    local label = editModeLabelHandle.widget
    if label:isDestroyed() then
        return
    end
    label:setVisible(isEditMode())
    label:breakAnchors()
    if vertical then
        -- Use vertical text (one character per line) instead of rotation
        label:setText(toVerticalLabelText(LABEL_TEXT_HORIZONTAL))
        label:setRotation(0)
        -- Vertical text: narrow width, tall height
        label:setWidth(18)
        -- Count total chars (no spaces) + word breaks
        -- "special conditions" = 7 chars + 10 chars + 1 word break (2 empty lines)
        local charCount = 0
        local wordCount = 0
        for word in LABEL_TEXT_HORIZONTAL:gmatch('%S+') do
            charCount = charCount + #word
            wordCount = wordCount + 1
        end
        -- Height = chars * 11px + (words-1) * 22px (2 empty lines between words) + padding
        label:setHeight(charCount * 11 + (wordCount - 1) * 22 + 10)
        -- Position label to the RIGHT of parent, aligned with top
        label:addAnchor(AnchorLeft, 'parent', AnchorRight)
        label:addAnchor(AnchorTop, 'parent', AnchorTop)
        label:setMarginLeft(4)
        label:setMarginTop(0)
        label:setMarginBottom(0)
    else
        label:setText(LABEL_TEXT_HORIZONTAL)
        label:setRotation(0)
        label:setHeight(16)
        label:setWidth(math.max(80, #LABEL_TEXT_HORIZONTAL * 6 + 12))
        label:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        label:addAnchor(AnchorBottom, 'parent', AnchorTop)
        label:setMarginLeft(0)
        label:setMarginBottom(2)
        label:setMarginTop(0)
    end
    label:raise()
end

local function updateEditActionStripLayout(vertical)
    if not editActionStripHandle or not editActionStripHandle.widget then
        return
    end
    local strip = editActionStripHandle.widget
    if strip:isDestroyed() then
        return
    end
    strip:setVisible(isEditMode())
    strip:breakAnchors()
    -- Strip is on game root panel (sibling of condition HUD), anchor to HUD panel so it draws in same layer as lock/HUD manager buttons
    if vertical then
        -- Position strip to the left of the HUD, with more breathing room
        strip:addAnchor(AnchorRight, 'conditionHUDPanel', AnchorLeft)
        strip:addAnchor(AnchorTop, 'conditionHUDPanel', AnchorTop)
        strip:setMarginRight(6)
        strip:setMarginTop(0)
    else
        strip:addAnchor(AnchorLeft, 'conditionHUDPanel', AnchorRight)
        strip:addAnchor(AnchorBottom, 'conditionHUDPanel', AnchorBottom)
        strip:setMarginLeft(4)
        strip:setMarginBottom(0)
    end
    strip:raise()
end

local function recreateEditActionStrip(vertical)
    -- Destroy existing strip
    if editActionStripHandle and editActionStripHandle.destroy then
        editActionStripHandle.destroy()
        editActionStripHandle = nil
    end
    
    -- Recreate with correct orientation
    if modules.game_ui_edit and modules.game_ui_edit.createHudActionStrip and conditionHudPanel then
        local rootPanel = modules.game_interface and modules.game_interface.getRootPanel and modules.game_interface.getRootPanel()
        editActionStripHandle = modules.game_ui_edit.createHudActionStrip(conditionHudPanel, {
            rootPanel = rootPanel,
            vertical = vertical,
            actions = {
                {
                    id = 'orientation',
                    tooltip = tr('Toggle orientation (horizontal/vertical)'),
                    icon = '/game_cyclopedia/images/icon-refresh',
                    onClick = function()
                        if modules.game_specialconditionhud and modules.game_specialconditionhud.toggleOrientation then
                            modules.game_specialconditionhud.toggleOrientation()
                        end
                    end
                },
                {
                    id = 'edit',
                    tooltip = tr('Open HUD manager'),
                    icon = '/images/ui/icon-edit',
                    onClick = function()
                        if modules.game_ui_edit and modules.game_ui_edit.openHudManager then
                            modules.game_ui_edit.openHudManager(HUD_ID)
                        end
                    end
                }
            }
        })
        
        if editActionStripHandle then
            updateEditActionStripLayout(vertical)
            if editActionStripHandle.refresh then
                editActionStripHandle.refresh()
            end
        end
    end
end

local function getCharacterSettings()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return nil
    end
    local node = g_settings.getNode(SETTINGS_KEY)
    if not node then
        node = {}
        g_settings.setNode(SETTINGS_KEY, node)
    end
    local mustPersist = false
    if node.__positionModelVersion ~= POSITION_MODEL_VERSION then
        -- Not in production yet: force-reset all existing characters to new center-offset model.
        for _, data in pairs(node) do
            if type(data) == 'table' then
                data.offsetFromCenterX = 0
                data.offsetFromCenterY = 0
                data.relCenterX = nil
                data.relCenterY = nil
            end
        end
        node.__positionModelVersion = POSITION_MODEL_VERSION
        mustPersist = true
    end
    if not node[char] then
        node[char] = {
            x = DEFAULT_X,
            y = DEFAULT_Y,
            width = MIN_WIDTH_V,
            height = MIN_HEIGHT_V,
            vertical = true,
            verticalHeight = MIN_HEIGHT_V,
            horizontalWidth = MIN_WIDTH_H,
            offsetFromCenterX = 0,
            offsetFromCenterY = 0
        }
        mustPersist = true
    end
    if mustPersist then
        g_settings.setNode(SETTINGS_KEY, node)
        g_settings.save()
    end
    return node[char]
end

-- We are child of root; map rect is used only to compute position (root coords) from map center + offset.
local function getMapPanel()
    return modules.game_interface and modules.game_interface.getMapPanel()
end

local function getRootPanel()
    return modules.game_interface and modules.game_interface.getRootPanel and modules.game_interface.getRootPanel()
end

local function getMapPanelBounds()
    local mapPanel = getMapPanel()
    if not mapPanel or not mapPanel:isVisible() then return nil end
    local mapW, mapH = mapPanel:getWidth(), mapPanel:getHeight()
    if mapW <= 0 or mapH <= 0 then return nil end
    return mapPanel:getX(), mapPanel:getY(), mapW, mapH
end

-- Position in root coordinates from pixel offset from map center (like health circles).
-- Returns xRoot, yRoot.
local function positionFromMapCenter(w, h)
    local settings = getCharacterSettings()
    if not settings then return nil, nil end
    local mapPanel = getMapPanel()
    if not mapPanel then return nil, nil end
    local mapX, mapY = mapPanel:getX(), mapPanel:getY()
    local mapW, mapH = mapPanel:getWidth(), mapPanel:getHeight()
    if mapW <= 0 or mapH <= 0 then return nil, nil end
    local centerX = mapX + mapW / 2
    local centerY = mapY + mapH / 2
    local offX = settings.offsetFromCenterX or 0
    local offY = settings.offsetFromCenterY or 0
    local xRoot = math.floor(centerX + offX - w / 2 + 0.5)
    local yRoot = math.floor(centerY + offY - h / 2 + 0.5)
    -- Clamp to keep HUD within map bounds
    xRoot = math.max(mapX, math.min(mapX + mapW - w, xRoot))
    yRoot = math.max(mapY, math.min(mapY + mapH - h, yRoot))
    return xRoot, yRoot
end

-- Reposition HUD in root coords from map center + saved pixel offset. Do not re-save (avoids drift).
local function whenMapResizeChange()
    if not conditionHudPanel or not conditionHudPanel:getParent() then
        return
    end
    if not conditionHudPanel:isVisible() then
        return
    end
    if conditionHudPanel.sizeAnimating then
        return
    end
    local mapPanel = getMapPanel()
    if not mapPanel then return end
    local mapW, mapH = mapPanel:getWidth(), mapPanel:getHeight()
    if mapW <= 0 or mapH <= 0 then return end
    local w, h = conditionHudPanel:getWidth(), conditionHudPanel:getHeight()
    programmaticRepositioning = true
    local xRoot, yRoot = positionFromMapCenter(w, h)
    if xRoot and yRoot then
        conditionHudPanel:setX(xRoot)
        conditionHudPanel:setY(yRoot)
    end
    -- Clear flag next tick so deferred setRect/onGeometryChange does not trigger save
    scheduleEvent(function() programmaticRepositioning = false end, 0)
end

local function savePositionAndSize()
    if not conditionHudPanel or not conditionHudPanel:getParent() then
        return
    end
    if not isEditMode() then
        return
    end
    if conditionHudPanel.sizeAnimating then
        return
    end
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    local node = g_settings.getNode(SETTINGS_KEY)
    if not node or not node[char] then
        return
    end
    local settings = node[char]
    local pos = conditionHudPanel:getPosition()
    local size = conditionHudPanel:getSize()
    settings.x = pos.x
    settings.y = pos.y
    settings.width = size.width
    settings.height = size.height
    if settings.vertical then
        settings.verticalHeight = size.height
    else
        settings.horizontalWidth = size.width
    end
    -- Pixel offset from map center (HUD center minus map center)
    local mapX, mapY, mapW, mapH = getMapPanelBounds()
    if mapX and mapW > 0 and mapH > 0 then
        local centerX = mapX + mapW / 2
        local centerY = mapY + mapH / 2
        local hudCenterX = pos.x + size.width / 2
        local hudCenterY = pos.y + size.height / 2
        settings.offsetFromCenterX = hudCenterX - centerX
        settings.offsetFromCenterY = hudCenterY - centerY
    end
    g_settings.setNode(SETTINGS_KEY, node)
    g_settings.save()
end

local function getEnabledConditions()
    local node = g_settings.getNode(CONDITIONS_KEY)
    if not node then
        node = {}
        for stateBit, iconData in pairs(Icons) do
            if type(stateBit) == 'number' and type(iconData) == 'table' and iconData.id then
                node[iconData.id] = true
            end
        end
        g_settings.setNode(CONDITIONS_KEY, node)
    end
    return node
end

local function isConditionEnabled(iconId)
    local enabled = getEnabledConditions()
    return enabled[iconId] ~= false
end

local function getHudEnabled()
    if modules.client_options and modules.client_options.getOption then
        return modules.client_options.getOption('showSpecialConditionHUD') == true
    end
    return conditionHudPanel and conditionHudPanel:isVisible() or false
end

local function setHudEnabled(enabled)
    local value = enabled == true
    if modules.client_options and modules.client_options.setOption then
        modules.client_options.setOption('showSpecialConditionHUD', value)
    else
        setVisible(value)
    end
end

local function loadIcon(stateBit, parent)
    local iconData = Icons[stateBit]
    if not iconData then
        return nil
    end
    local icon = g_ui.createWidget('ConditionHUDIcon', parent)
    icon:setId(iconData.id)
    icon:setFocusable(false)
    icon:setPhantom(true)
    icon:setImageSource('/images/game/states/player-state-flags')
    icon:setImageClip(((iconData.clip - 1) * 9) .. ' 0 9 9')
    icon:setTooltip(iconData.tooltip)
    return icon
end

local function cancelSizeTransition()
    if conditionHudPanel and conditionHudPanel.sizeTransitionEvent then
        removeEvent(conditionHudPanel.sizeTransitionEvent)
        conditionHudPanel.sizeTransitionEvent = nil
    end
    if conditionHudPanel then
        conditionHudPanel.sizeAnimating = false
    end
end

local function applyPanelSizeAndPosition(w, h, x, y)
    if not conditionHudPanel then
        return
    end
    conditionHudPanel:setWidth(w)
    conditionHudPanel:setHeight(h)
    if x and y then
        conditionHudPanel:setPosition({ x = x, y = y })
    end
end

local function ensurePersistentResizeHandleBehavior(border)
    if not border or border.__persistentHandleBehavior then
        return
    end
    border.__persistentHandleBehavior = true

    border.onHoverChange = function(self, hovered)
        if hovered then
            if g_mouse.isCursorChanged() or g_mouse.isPressed() then
                return
            end
            if self:getWidth() > self:getHeight() then
                self.vertical = true
                self.cursortype = 'vertical'
            else
                self.vertical = false
                self.cursortype = 'horizontal'
            end
            g_mouse.pushCursor(self.cursortype)
            self.hovering = true
            if self:isEnabled() and self:isVisible() then
                self:setBackgroundColor(RESIZE_HANDLE_HOVER_COLOR)
                self:setOpacity(RESIZE_HANDLE_HOVER_OPACITY)
            end
        else
            if not self:isPressed() and self.hovering then
                g_mouse.popCursor(self.cursortype)
                self.hovering = false
            end
            if self:isEnabled() and self:isVisible() then
                self:setBackgroundColor(RESIZE_HANDLE_COLOR)
                self:setOpacity(RESIZE_HANDLE_OPACITY)
            end
        end
    end

    border.onMouseRelease = function(self, mousePos, mouseButton)
        if not self:isHovered() and self.hovering then
            g_mouse.popCursor(self.cursortype)
            self.hovering = false
        end
        if self:isEnabled() and self:isVisible() then
            self:setBackgroundColor(RESIZE_HANDLE_COLOR)
            self:setOpacity(RESIZE_HANDLE_OPACITY)
        end
    end
end

local function animatePanelSizeTo(targetW, targetH, vertical, symmetricResize)
    if not conditionHudPanel then
        return
    end
    cancelSizeTransition()
    local startW = conditionHudPanel:getWidth()
    local startH = conditionHudPanel:getHeight()
    local startX = conditionHudPanel:getX()
    local startY = conditionHudPanel:getY()
    if startW == targetW and startH == targetH then
        return
    end
    conditionHudPanel.sizeAnimating = true
    local startTime = g_clock.millis()
    -- Always use current panel center - guarantees lock/unlock returns to same place
    local targetX = startX
    local targetY = startY
    if symmetricResize then
        local centerX = math.floor(startX + startW / 2 + 0.5)
        local centerY = math.floor(startY + startH / 2 + 0.5)
        targetX = centerX - math.floor(targetW / 2 + 0.5)
        targetY = centerY - math.floor(targetH / 2 + 0.5)
    end
    local function step()
        if not conditionHudPanel or not conditionHudPanel:getParent() then
            cancelSizeTransition()
            return
        end
        local elapsed = g_clock.millis() - startTime
        local t = math.min(1, elapsed / SIZE_TRANSITION_MS)
        local ease = t * t * (3 - 2 * t)
        local curW = math.floor(startW + (targetW - startW) * ease + 0.5)
        local curH = math.floor(startH + (targetH - startH) * ease + 0.5)
        local curX, curY
        if symmetricResize then
            curX = math.floor(startX + (targetX - startX) * ease + 0.5)
            curY = math.floor(startY + (targetY - startY) * ease + 0.5)
        end
        applyPanelSizeAndPosition(curW, curH, curX, curY)
        scheduleEvent(function()
            if not conditionHudPanel then return end
            local box = conditionHudPanel:recursiveGetChildById('conditionHUDBox')
            local container = box and box:recursiveGetChildById('iconsContainer')
            local settings = getCharacterSettings()
            if container and settings then
                applyCenteringPadding(container, settings.vertical)
            end
        end, 0)
        if t >= 1 then
            conditionHudPanel.sizeAnimating = false
            conditionHudPanel.sizeTransitionEvent = nil
            whenMapResizeChange()
            savePositionAndSize()
            scheduleEvent(function()
                if modules.game_specialconditionhud and modules.game_specialconditionhud.refresh then
                    modules.game_specialconditionhud.refresh()
                end
            end, 0)
            return
        end
        conditionHudPanel.sizeTransitionEvent = scheduleEvent(step, SIZE_TRANSITION_STEP_MS)
    end
    conditionHudPanel.sizeTransitionEvent = scheduleEvent(step, SIZE_TRANSITION_STEP_MS)
end

function updatePanelSize()
    if not conditionHudPanel then
        return
    end
    whenMapResizeChange()
    local settings = getCharacterSettings()
    if not settings then
        return
    end
    local box = conditionHudPanel:recursiveGetChildById('conditionHUDBox')
    local container = box and box:recursiveGetChildById('iconsContainer')
    local orientBtn = conditionHudPanel:recursiveGetChildById('orientationButton')
    local bottomBorder = conditionHudPanel:recursiveGetChildById('bottomResizeBorder')
    local rightBorder = conditionHudPanel:recursiveGetChildById('rightResizeBorder')
    if not container or not orientBtn or not bottomBorder or not rightBorder then
        return
    end
    local count = #container:getChildren()
    local vertical = settings.vertical
    local editMode = isEditMode()
    ensurePersistentResizeHandleBehavior(bottomBorder)
    ensurePersistentResizeHandleBehavior(rightBorder)
    box:setVisible(editMode or count > 0)
    updateEditModeLabelLayout(vertical)
    updateEditActionStripLayout(vertical)
    if editActionStripHandle and editActionStripHandle.refresh then
        editActionStripHandle.refresh()
    end

    if editMode then
        orientBtn:setVisible(false)
        if vertical then
        -- Vertical: box above resize border
        bottomBorder:breakAnchors()
        bottomBorder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        bottomBorder:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        bottomBorder:addAnchor(AnchorRight, 'parent', AnchorRight)
        bottomBorder:setHeight(RESIZE_HANDLE_SIZE)
        bottomBorder:setMinimum(MIN_HEIGHT_V)
        bottomBorder:setMaximum(400)
        bottomBorder:setBackgroundColor(RESIZE_HANDLE_COLOR)
        bottomBorder:setOpacity(RESIZE_HANDLE_OPACITY)
        bottomBorder:setTooltip(RESIZE_HANDLE_HINT)
        bottomBorder:setVisible(true)
        bottomBorder:enable()
        bottomBorder:raise()
        box:breakAnchors()
        box:addAnchor(AnchorTop, 'parent', AnchorTop)
        box:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        box:addAnchor(AnchorRight, 'parent', AnchorRight)
        box:addAnchor(AnchorBottom, bottomBorder:getId(), AnchorTop)
        local savedH = settings.verticalHeight or settings.height or MIN_HEIGHT_V
        local h = math.max(MIN_HEIGHT_V, savedH)
        rightBorder:setWidth(0)
        rightBorder:setBackgroundColor('#00000000')
        rightBorder:setOpacity(0)
        rightBorder:setTooltip('')
        rightBorder:setVisible(false)
        rightBorder:disable()
        animatePanelSizeTo(MIN_WIDTH_V, h, true, true)
    else
        -- Horizontal: box left and resize border at right
        box:breakAnchors()
        box:addAnchor(AnchorTop, 'parent', AnchorTop)
        box:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        box:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        box:addAnchor(AnchorRight, rightBorder:getId(), AnchorLeft)
        local h = MIN_HEIGHT_H
        local savedW = settings.horizontalWidth or settings.width or MIN_WIDTH_H
        local w = math.max(MIN_WIDTH_H, savedW)
        rightBorder:breakAnchors()
        rightBorder:addAnchor(AnchorRight, 'parent', AnchorRight)
        rightBorder:addAnchor(AnchorTop, 'parent', AnchorTop)
        rightBorder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        rightBorder:setWidth(RESIZE_HANDLE_SIZE)
        rightBorder:setMinimum(MIN_WIDTH_H)
        rightBorder:setMaximum(400)
        rightBorder:setBackgroundColor(RESIZE_HANDLE_COLOR)
        rightBorder:setOpacity(RESIZE_HANDLE_OPACITY)
        rightBorder:setTooltip(RESIZE_HANDLE_HINT)
        rightBorder:setVisible(true)
        rightBorder:enable()
        rightBorder:raise()
        bottomBorder:setHeight(0)
        bottomBorder:setBackgroundColor('#00000000')
        bottomBorder:setOpacity(0)
        bottomBorder:setTooltip('')
        bottomBorder:setVisible(false)
        bottomBorder:disable()
        animatePanelSizeTo(w, MIN_HEIGHT_H, false, true)
        end
    else
        -- Lock mode: hide H/V and resize borders, size = min(content, savedMax)
        -- Content is icons only - no button/resize space (they're hidden)
        orientBtn:setVisible(false)
        bottomBorder:setBackgroundColor('#00000000')
        bottomBorder:setOpacity(0)
        bottomBorder:setTooltip('')
        bottomBorder:setVisible(false)
        bottomBorder:disable()
        rightBorder:setBackgroundColor('#00000000')
        rightBorder:setOpacity(0)
        rightBorder:setTooltip('')
        rightBorder:setVisible(false)
        rightBorder:disable()
        if vertical then
            box:breakAnchors()
            box:addAnchor(AnchorTop, 'parent', AnchorTop)
            box:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            box:addAnchor(AnchorRight, 'parent', AnchorRight)
            box:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            local contentH = MARGIN_VERTICAL_FLOW * 2 + count * (ICON_SIZE + ICON_SPACING) - (count > 0 and ICON_SPACING or 0) + 4
            local savedH = settings.verticalHeight or settings.height or MIN_HEIGHT_V
            local h = math.max(MIN_HEIGHT_V, math.min(contentH, savedH))
            animatePanelSizeTo(MIN_WIDTH_V, h, true, true)
        else
            box:breakAnchors()
            box:addAnchor(AnchorTop, 'parent', AnchorTop)
            box:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            box:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            box:addAnchor(AnchorRight, 'parent', AnchorRight)
            local contentW = MARGIN_HORIZONTAL_FLOW * 2 + count * (ICON_SIZE + ICON_SPACING) - (count > 0 and ICON_SPACING or 0) + 4
            local savedW = settings.horizontalWidth or settings.width or MIN_WIDTH_H
            local w = math.max(MIN_WIDTH_H, math.min(contentW, savedW))
            animatePanelSizeTo(w, MIN_HEIGHT_H, false, true)
        end
    end
    scheduleEvent(function()
        if not conditionHudPanel then return end
        local box = conditionHudPanel:recursiveGetChildById('conditionHUDBox')
        local container = box and box:recursiveGetChildById('iconsContainer')
        if container and settings then
            applyCenteringPadding(container, settings.vertical)
        end
    end, 0)
end

local function refreshIcons()
    if not conditionHudPanel then
        return
    end
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end
    local container = conditionHudPanel:getChildById('conditionHUDBox')
    if container then
        container = container:getChildById('iconsContainer')
    end
    if not container then
        return
    end
    container:destroyChildren()
    local states = player:getStates()
    if not states or states == 0 then
        local box = conditionHudPanel:getChildById('conditionHUDBox')
        if box and not isEditMode() then
            box:setVisible(false)
        end
        updatePanelSize()
        return
    end
    for stateBit, iconData in pairs(Icons) do
        if type(stateBit) == 'number' and type(iconData) == 'table' and iconData.id and
            Player.isStateActive(states, stateBit) and isConditionEnabled(iconData.id) then
            loadIcon(stateBit, container)
        end
    end
    updatePanelSize()
end

local function onStatesChange(localPlayer, now, old)
    refreshIcons()
end

function toggleOrientation()
    if not conditionHudPanel then
        return
    end
    local container = conditionHudPanel:getChildById('conditionHUDBox')
    if container then
        container = container:getChildById('iconsContainer')
    end
    if not container then
        return
    end
    savePositionAndSize()
    local node = g_settings.getNode(SETTINGS_KEY)
    if not node then
        return
    end
    local char = g_game.getCharacterName()
    if not char or not node[char] then
        return
    end
    local settings = node[char]
    local wasVertical = settings.vertical
    settings.vertical = not settings.vertical
    -- Keep same size on the resizable axis when switching orientation
    if settings.vertical then
        settings.verticalHeight = math.max(MIN_HEIGHT_V, conditionHudPanel:getWidth())
    else
        settings.horizontalWidth = math.max(MIN_WIDTH_H, conditionHudPanel:getHeight())
    end
    g_settings.setNode(SETTINGS_KEY, node)
    g_settings.save()
    if settings.vertical then
        container:setLayout(UIVerticalLayout.create(container))
    else
        container:setLayout(UIHorizontalLayout.create(container))
    end
    applyContainerMarginsForOrientation(container, settings.vertical)
    refreshIcons()
    updatePanelSize()
    recreateEditActionStrip(settings.vertical)
end

local function setupPanel()
    if not conditionHudPanel then
        return
    end
    local settings = getCharacterSettings()
    local editMode = isEditMode()
    local vertical = settings and settings.vertical ~= false
    conditionHudPanel:setDraggable(editMode)
    conditionHudPanel:setPhantom(not editMode)
    conditionHudPanel:setVisible(false)
    if editModeLabelHandle and (not editModeLabelHandle.widget or editModeLabelHandle.widget:isDestroyed()) then
        editModeLabelHandle = nil
    end
    if editActionStripHandle and (not editActionStripHandle.widget or editActionStripHandle.widget:isDestroyed()) then
        editActionStripHandle = nil
    end
    if modules.game_ui_edit and modules.game_ui_edit.createEditModeLabel and not editModeLabelHandle then
        editModeLabelHandle = modules.game_ui_edit.createEditModeLabel(conditionHudPanel, LABEL_TEXT_HORIZONTAL)
    end
    if modules.game_ui_edit and modules.game_ui_edit.createHudActionStrip and not editActionStripHandle then
        recreateEditActionStrip(vertical)
    end
    if editModeLabelHandle then
        updateEditModeLabelLayout(vertical)
    end
    conditionHudPanel:breakAnchors()
    local xRoot, yRoot = positionFromMapCenter(MIN_WIDTH_V, MIN_HEIGHT_V)
    if not xRoot or not yRoot then
        local mapX, mapY, mapW, mapH = getMapPanelBounds()
        if settings and mapX and mapW > 0 and mapH > 0 then
            local oldX = (settings.x or DEFAULT_X)
            local oldY = (settings.y or DEFAULT_Y)
            local w = settings.width or MIN_WIDTH_V
            local h = settings.height or MIN_HEIGHT_V
            local centerX = mapX + mapW / 2
            local centerY = mapY + mapH / 2
            settings.offsetFromCenterX = (oldX + w / 2) - centerX
            settings.offsetFromCenterY = (oldY + h / 2) - centerY
            local node = g_settings.getNode(SETTINGS_KEY)
            if node then
                g_settings.setNode(SETTINGS_KEY, node)
                g_settings.save()
            end
            xRoot, yRoot = positionFromMapCenter(w, h)
        end
        if not xRoot or not yRoot then
            local mx, my, mw, mh = getMapPanelBounds()
            if mx and mw and mh and mw > 0 and mh > 0 then
                xRoot = (settings and settings.x) or (mx + mw / 2 - MIN_WIDTH_V / 2)
                yRoot = (settings and settings.y) or (my + mh / 2 - MIN_HEIGHT_V / 2)
            else
                xRoot = (settings and settings.x) or DEFAULT_X
                yRoot = (settings and settings.y) or DEFAULT_Y
            end
        end
    end
    conditionHudPanel:setPosition({ x = xRoot or DEFAULT_X, y = yRoot or DEFAULT_Y })
    updatePanelSize()
    -- Reposition after size is set (updatePanelSize may animate; use actual size)
    scheduleEvent(function()
        whenMapResizeChange()
    end, 0)
    scheduleEvent(function()
        whenMapResizeChange()
    end, SIZE_TRANSITION_MS + 50)
    local opacity = DEFAULT_OPACITY
    if modules.client_options then
        opacity = modules.client_options.getOption('conditionHUDBackgroundOpacity') or opacity
    end
    local box = conditionHudPanel:getChildById('conditionHUDBox')
    if box then
        box:setBackgroundColor(string.format('#000000%02x', math.floor((opacity / 100) * 255)))
        box:setClipping(true)
        box:setDraggable(editMode)
        box:setPhantom(not editMode)
    end
    -- Drag: we are child of root, mousePos is root-relative
    conditionHudPanel.onDragEnter = function(panel, mousePos)
        panel:breakAnchors()
        panel.movingReference = { x = mousePos.x - panel:getX(), y = mousePos.y - panel:getY() }
        return true
    end
    conditionHudPanel.onDragMove = function(panel, mousePos, mouseMoved)
        panel:setPosition({ x = mousePos.x - panel.movingReference.x, y = mousePos.y - panel.movingReference.y })
        savePositionAndSize()
        return true
    end
    if box then
        box:setDraggable(true)
        box.onDragEnter = function(_, mousePos)
            conditionHudPanel:breakAnchors()
            conditionHudPanel.movingReference = { x = mousePos.x - conditionHudPanel:getX(), y = mousePos.y - conditionHudPanel:getY() }
            return true
        end
        box.onDragMove = function(_, mousePos)
            if conditionHudPanel.movingReference then
                conditionHudPanel:setPosition({ x = mousePos.x - conditionHudPanel.movingReference.x, y = mousePos.y - conditionHudPanel.movingReference.y })
                savePositionAndSize()
            end
            return true
        end
    end
    local container = conditionHudPanel:getChildById('conditionHUDBox')
    if container then
        container = container:getChildById('iconsContainer')
    end
    if container then
        if settings and settings.vertical == false then
            container:setLayout(UIHorizontalLayout.create(container))
        else
            container:setLayout(UIVerticalLayout.create(container))
        end
        applyContainerMarginsForOrientation(container, not (settings and settings.vertical == false))
    end
    conditionHudPanel.onGeometryChange = function()
        local settings = getCharacterSettings()
        local box = conditionHudPanel and conditionHudPanel:recursiveGetChildById('conditionHUDBox')
        local container = box and box:recursiveGetChildById('iconsContainer')
        if container and settings then
            applyCenteringPadding(container, settings.vertical)
        end
        if not programmaticRepositioning then
            savePositionAndSize()
        end
    end
    -- We are child of root; map/root onGeometryChange just recalc position (no bindRectToParent on us)
    if not mapResizeHooked and modules.game_interface then
        local mapPanel = modules.game_interface.getMapPanel()
        local rootPanel = getRootPanel()
        if mapPanel then
            mapResizeHooked = true
            mapResizeHandler = whenMapResizeChange
            connect(mapPanel, { onGeometryChange = mapResizeHandler })
        end
        if rootPanel then
            rootResizeHandler = function()
                addEvent(whenMapResizeChange)
            end
            connect(rootPanel, { onGeometryChange = rootResizeHandler })
        end
    end
end

function init()
    if not modules.game_interface then
        return
    end
    g_ui.importStyle('conditionhud')
    local rootPanel = getRootPanel()
    if not rootPanel then
        return
    end
    -- Child of root so map's bindRectToParent/layout never move us; position = root coords from map rect
    conditionHudPanel = g_ui.createWidget('ConditionHUDPanel', rootPanel)
    conditionHudPanel:setId('conditionHUDPanel')
    setupPanel()
    whenMapResizeChange()
    if modules.game_ui_edit then
        editModeListenerUnregister = modules.game_ui_edit.addEditModeListener(applyEditModeToPanel)
    end
    stateConnection = connect(LocalPlayer, {
        onStatesChange = onStatesChange
    })
    gameConnection = connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
    if g_game.isOnline() then
        refreshIcons()
        if modules.client_options and modules.client_options.getOption('showSpecialConditionHUD') then
            conditionHudPanel:setVisible(true)
            conditionHudPanel:raise()
        end
    end
end

function onGameStart()
    setupPanel()
    refreshIcons()
    if modules.client_options and modules.client_options.getOption('showSpecialConditionHUD') then
        conditionHudPanel:setVisible(true)
        conditionHudPanel:raise()
    end
    -- Same as ARC initOnLoginChange: reposition when game starts
    whenMapResizeChange()
end

function onGameEnd()
    if editActionStripHandle and editActionStripHandle.destroy then
        editActionStripHandle.destroy()
        editActionStripHandle = nil
    end
    if editModeLabelHandle and editModeLabelHandle.destroy then
        editModeLabelHandle.destroy()
        editModeLabelHandle = nil
    end
    if conditionHudPanel then
        conditionHudPanel:setVisible(false)
    end
end

function terminate()
    if editActionStripHandle and editActionStripHandle.destroy then
        editActionStripHandle.destroy()
        editActionStripHandle = nil
    end
    if editModeLabelHandle and editModeLabelHandle.destroy then
        editModeLabelHandle.destroy()
        editModeLabelHandle = nil
    end
    if editModeListenerUnregister then
        editModeListenerUnregister()
        editModeListenerUnregister = nil
    end
    if modules.game_interface then
        local mapPanel = modules.game_interface.getMapPanel()
        local rootPanel = modules.game_interface.getRootPanel and modules.game_interface.getRootPanel()
        if mapPanel and mapResizeHandler then
            disconnect(mapPanel, { onGeometryChange = mapResizeHandler })
        end
        if rootPanel and rootResizeHandler then
            disconnect(rootPanel, { onGeometryChange = rootResizeHandler })
        end
        mapResizeHandler = nil
        rootResizeHandler = nil
    end
    cancelSizeTransition()
    if gameConnection then
        disconnect(g_game, gameConnection)
        gameConnection = nil
    end
    if stateConnection then
        disconnect(LocalPlayer, stateConnection)
        stateConnection = nil
    end
    if conditionHudPanel then
        conditionHudPanel:destroy()
        conditionHudPanel = nil
    end
end

function setVisible(visible)
    if conditionHudPanel then
        conditionHudPanel:setVisible(visible)
        if visible then
            conditionHudPanel:raise()
            refreshIcons()
        end
    end
end

function refresh()
    refreshIcons()
end

function getBackgroundOpacity()
    if modules.client_options and modules.client_options.getOption then
        return modules.client_options.getOption('conditionHUDBackgroundOpacity') or DEFAULT_OPACITY
    end
    return DEFAULT_OPACITY
end

function setBackgroundOpacity(percent)
    if conditionHudPanel then
        local p = math.max(0, math.min(100, percent))
        local hex = string.format('#000000%02x', math.floor((p / 100) * 255))
        local box = conditionHudPanel:getChildById('conditionHUDBox')
        if box then
            box:setBackgroundColor(hex)
        end
    end
end

function getConditionEntries()
    local entries = {}
    for stateBit, iconData in pairs(Icons) do
        if type(stateBit) == 'number' and type(iconData) == 'table' and iconData.id then
            local label = iconData.tooltip or iconData.id
            table.insert(entries, {
                id      = iconData.id,
                label   = tostring(label),
                enabled = isConditionEnabled(iconData.id),
                icon    = {
                    source = '/images/game/states/player-state-flags',
                    clip   = string.format('%d 0 9 9', (iconData.clip - 1) * 9)
                }
            })
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return entries
end

function setConditionEnabled(iconId, enabled)
    if not iconId then
        return
    end
    local node = getEnabledConditions()
    node[iconId] = enabled == true
    g_settings.setNode(CONDITIONS_KEY, node)
    g_settings.save()
    refreshIcons()
end

function getHudManagerDefinition()
    return {
        id = HUD_ID,
        title = tr('Show Conditions'),
        getEnabled = function()
            return getHudEnabled()
        end,
        setEnabled = function(value)
            setHudEnabled(value == true)
        end,
        getConditions = function()
            return getConditionEntries()
        end,
        setConditionEnabled = function(iconId, enabled)
            setConditionEnabled(iconId, enabled)
        end,
        getOpacity = function()
            return getBackgroundOpacity()
        end,
        setOpacity = function(value)
            if modules.client_options and modules.client_options.setOption then
                modules.client_options.setOption('conditionHUDBackgroundOpacity', value)
            else
                setBackgroundOpacity(value)
            end
        end
    }
end
