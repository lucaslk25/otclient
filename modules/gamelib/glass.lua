-- Glass UI component library
-- Provides behavior helpers for the glass design system defined in data/styles/10-glass.otui

Glass = {}

-- Toggle animation constants
local ANIM_STEPS   = 8
local ANIM_STEP_MS = 15   -- ~120ms total

-- Toggle dimensions (must match GlassToggle in glass_styles.otui)
local TOGGLE_W     = 32
local KNOB_W       = 10
local KNOB_PAD     = 3
local KNOB_OFF     = KNOB_PAD                          -- 3
local KNOB_ON      = TOGGLE_W - KNOB_W - KNOB_PAD     -- 19

-- Colors as RGBA component tables
local BG_OFF   = { 0x40, 0x40, 0x60, 0xcc }
local BG_ON    = { 0x30, 0xa0, 0x50, 0xdd }
local KNOB_OFF_C = { 0x80, 0x80, 0x90, 0xff }
local KNOB_ON_C  = { 0xff, 0xff, 0xff, 0xee }

Glass._anims = {}

local function lerp(a, b, t)
    return math.floor(a + (b - a) * t + 0.5)
end

local function lerpColor(c1, c2, t)
    return string.format('#%02x%02x%02x%02x',
        lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t),
        lerp(c1[3], c2[3], t), lerp(c1[4], c2[4], t))
end

local function animStep(toggle, knob, toOn, step)
    local key = tostring(toggle)
    if toggle:isDestroyed() then
        Glass._anims[key] = nil
        return
    end

    local t = step / ANIM_STEPS
    local bgFrom,  bgTo  = toOn and BG_OFF    or BG_ON,    toOn and BG_ON    or BG_OFF
    local kFrom,   kTo   = toOn and KNOB_OFF_C or KNOB_ON_C, toOn and KNOB_ON_C or KNOB_OFF_C
    local mFrom,   mTo   = toOn and KNOB_OFF   or KNOB_ON,  toOn and KNOB_ON   or KNOB_OFF

    toggle:setBackgroundColor(lerpColor(bgFrom, bgTo, t))
    knob:setBackgroundColor(lerpColor(kFrom, kTo, t))
    knob:setMarginLeft(lerp(mFrom, mTo, t))

    if step < ANIM_STEPS then
        Glass._anims[key] = scheduleEvent(function()
            animStep(toggle, knob, toOn, step + 1)
        end, ANIM_STEP_MS)
    else
        Glass._anims[key] = nil
        toggle:setOn(toOn)
    end
end

-- Sets the visual state of a GlassToggle widget (on/off).
-- Pass animate=true to smoothly transition, false to snap immediately.
function Glass.setToggleState(toggle, on, animate)
    local knob = toggle:getChildById('knob')
    if not knob then return end

    -- Cancel any in-progress animation on this widget
    local key = tostring(toggle)
    if Glass._anims[key] then
        removeEvent(Glass._anims[key])
        Glass._anims[key] = nil
    end

    if animate then
        animStep(toggle, knob, on, 1)
    else
        toggle:setOn(on)
        toggle:setBackgroundColor(on and '#30a050dd' or '#404060cc')
        knob:setMarginLeft(on and KNOB_ON or KNOB_OFF)
        knob:setBackgroundColor(on and '#ffffffee' or '#808090ff')
    end
end

-- Creates a GlassToggle anchored to the right/verticalCenter of parent.
-- onChange(newState) is called when the user clicks.
-- Returns the toggle widget.
function Glass.toggle(parent, initialState, onChange)
    local toggle = g_ui.createWidget('GlassToggle', parent)
    toggle:addAnchor(AnchorRight, 'parent', AnchorRight)
    toggle:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    toggle:setMarginRight(6)

    -- Ensure knob always anchors to left (marginLeft drives position)
    local knob = toggle:getChildById('knob')
    if knob then
        knob:breakAnchors()
        knob:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        knob:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    end

    Glass.setToggleState(toggle, initialState, false)

    toggle.onClick = function(widget, mousePos, mouseButton)
        local newState = not toggle:isOn()
        Glass.setToggleState(toggle, newState, true)  -- animated
        if onChange then
            onChange(newState)
        end
        return true  -- consume event, prevent propagation to parent row
    end
    return toggle
end

-- Creates a compact opacity row + scrollbar.
-- Returns the scrollbar widget.
function Glass.opacityControl(parent, initialValue, onChange)
    local row = g_ui.createWidget('UIWidget', parent)
    row:setHeight(16)

    local titleLabel = g_ui.createWidget('Label', row)
    titleLabel:setText(tr('Opacity'))
    titleLabel:setColor('#c8c8e0ff')
    titleLabel:setFont('Verdana Bold-11px')
    titleLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    titleLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    titleLabel:setWidth(60)
    titleLabel:setHeight(16)

    local valueLabel = g_ui.createWidget('Label', row)
    valueLabel:setColor('#a0a0b8ff')
    valueLabel:setFont('Verdana Bold-11px')
    valueLabel:addAnchor(AnchorRight, 'parent', AnchorRight)
    valueLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    valueLabel:setWidth(40)
    valueLabel:setHeight(16)
    valueLabel:setTextAlign(AlignRight)
    valueLabel:setText((initialValue or 0) .. '%')

    local bar = g_ui.createWidget('HorizontalQtScrollBar', parent)
    bar:setMinimum(0)
    bar:setMaximum(100)
    bar:setValue(initialValue or 0)
    bar.onValueChange = function(widget, value)
        valueLabel:setText(value .. '%')
        if onChange then onChange(value) end
    end
    return bar
end

-- Creates a GlassSectionTitle label.
function Glass.sectionTitle(parent, text)
    local label = g_ui.createWidget('GlassSectionTitle', parent)
    label:setText(text)
    return label
end

-- Creates a GlassSeparator.
function Glass.separator(parent)
    return g_ui.createWidget('GlassSeparator', parent)
end
