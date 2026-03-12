-- UI Inspector for serializing widget trees
UIInspector = {}

-- Serializa widget recursivamente
function UIInspector.serializeWidget(widget, maxDepth, currentDepth)
  if not widget or currentDepth > maxDepth then
    return nil
  end

  local data = {
    id = widget:getId() or "",
    class = widget:getClassName() or "",
    rect = {
      x = widget:getX(),
      y = widget:getY(),
      width = widget:getWidth(),
      height = widget:getHeight()
    },
    visible = widget:isVisible(),
    enabled = widget:isEnabled(),
    text = "",
    children = {}
  }

  -- Try to get text if widget has getText method
  local success, text = pcall(function() return widget:getText() end)
  if success and text then
    data.text = text
  end

  -- Get additional properties for layout analysis
  local opacitySuccess, opacity = pcall(function() return widget:getOpacity() end)
  if opacitySuccess and opacity then
    data.opacity = opacity
  end

  local phantomSuccess, phantom = pcall(function() return widget:isPhantom() end)
  if phantomSuccess and phantom ~= nil then
    data.phantom = phantom
  end

  local clippingSuccess, clipping = pcall(function() return widget:isClipping() end)
  if clippingSuccess and clipping ~= nil then
    data.clipping = clipping
  end

  local focusableSuccess, focusable = pcall(function() return widget:isFocusable() end)
  if focusableSuccess and focusable ~= nil then
    data.focusable = focusable
  end

  local draggableSuccess, draggable = pcall(function() return widget:isDraggable() end)
  if draggableSuccess and draggable ~= nil then
    data.draggable = draggable
  end

  -- Get rotation
  local rotationSuccess, rotation = pcall(function() return widget:getRotation() end)
  if rotationSuccess and rotation then
    data.rotation = rotation
  else
    data.rotation = 0
  end

  -- Get margins
  local margins = {}
  local marginTopSuccess, marginTop = pcall(function() return widget:getMarginTop() end)
  if marginTopSuccess and marginTop then
    margins.top = marginTop
  end
  local marginRightSuccess, marginRight = pcall(function() return widget:getMarginRight() end)
  if marginRightSuccess and marginRight then
    margins.right = marginRight
  end
  local marginBottomSuccess, marginBottom = pcall(function() return widget:getMarginBottom() end)
  if marginBottomSuccess and marginBottom then
    margins.bottom = marginBottom
  end
  local marginLeftSuccess, marginLeft = pcall(function() return widget:getMarginLeft() end)
  if marginLeftSuccess and marginLeft then
    margins.left = marginLeft
  end
  if next(margins) then
    data.margins = margins
  end

  -- Get font
  local fontSuccess, font = pcall(function() return widget:getFont() end)
  if fontSuccess and font then
    data.font = tostring(font)
  end

  -- Get parent ID
  local parent = widget:getParent()
  if parent then
    local parentIdSuccess, parentId = pcall(function() return parent:getId() end)
    if parentIdSuccess and parentId and parentId ~= "" then
      data.parentId = parentId
    end
  end

  -- Calculate visual rect for rotated widgets
  if data.rotation ~= 0 and data.rotation ~= nil then
    local cx = data.rect.x + data.rect.width / 2
    local cy = data.rect.y + data.rect.height / 2
    local rad = math.rad(data.rotation)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    
    -- Calculate rotated corners relative to center
    local hw = data.rect.width / 2
    local hh = data.rect.height / 2
    
    -- Four corners before rotation (relative to center)
    local corners = {
      {x = -hw, y = -hh},
      {x = hw, y = -hh},
      {x = hw, y = hh},
      {x = -hw, y = hh}
    }
    
    -- Rotate corners and find bounding box
    local minX = math.huge
    local maxX = -math.huge
    local minY = math.huge
    local maxY = -math.huge
    
    for _, corner in ipairs(corners) do
      local rotatedX = corner.x * cos - corner.y * sin
      local rotatedY = corner.x * sin + corner.y * cos
      
      minX = math.min(minX, rotatedX)
      maxX = math.max(maxX, rotatedX)
      minY = math.min(minY, rotatedY)
      maxY = math.max(maxY, rotatedY)
    end
    
    -- Visual rect is the bounding box of rotated corners
    data.visualRect = {
      x = cx + minX,
      y = cy + minY,
      width = maxX - minX,
      height = maxY - minY
    }
  end

  -- Recursão nos filhos
  local children = widget:getChildren()
  if children then
    for i, child in ipairs(children) do
      -- Only serialize visible widgets to reduce size
      if child:isVisible() then
        local childData = UIInspector.serializeWidget(child, maxDepth, currentDepth + 1)
        if childData then
          table.insert(data.children, childData)
        end
      end
    end
  end

  return data
end

-- Retorna árvore completa de UI
function UIInspector.getTree(maxDepth)
  maxDepth = maxDepth or 5
  local root = g_ui.getRootWidget()
  if not root then
    return {
      id = "root",
      class = "UIWidget",
      rect = { x = 0, y = 0, width = 0, height = 0 },
      visible = false,
      enabled = false,
      text = "",
      children = {}
    }
  end
  
  return UIInspector.serializeWidget(root, maxDepth, 0)
end

-- Find widget by ID
function UIInspector.findWidget(id)
  local root = g_ui.getRootWidget()
  if not root then
    return nil
  end
  
  local function search(widget)
    if widget:getId() == id then
      return widget
    end
    
    local children = widget:getChildren()
    if children then
      for i, child in ipairs(children) do
        local found = search(child)
        if found then
          return found
        end
      end
    end
    
    return nil
  end
  
  return search(root)
end
