-- MCP Bridge for AI-assisted development
-- Connects OTClient to MCP Server via WebSocket

dofile('ui_inspector')

MCPBridge = {
  url = "ws://127.0.0.1:8765",
  timeout = 10,
  websocket = nil,
  connected = false,
  requestId = 0,
  pendingRequests = {},
  screenshotQueue = {},
  reconnectAttempts = 0,
  maxReconnectAttempts = 10,
  reconnectDelay = 2000,
}

-- Conexão WebSocket
function MCPBridge.init()
  if MCPBridge.websocket then
    print("[MCP Bridge] Already initialized")
    return
  end

  print("[MCP Bridge] Connecting to MCP server at " .. MCPBridge.url)
  
  MCPBridge.websocket = HTTP.WebSocketJSON(MCPBridge.url, {
    onOpen = MCPBridge.onOpen,
    onMessage = MCPBridge.onMessage,
    onClose = MCPBridge.onClose,
    onError = MCPBridge.onError
  }, MCPBridge.timeout)
end

function MCPBridge.onOpen(message, socketId)
  print("[MCP Bridge] Connected to MCP server")
  MCPBridge.connected = true
  MCPBridge.reconnectAttempts = 0
end

function MCPBridge.onMessage(data, socketId)
  if not MCPBridge.websocket or MCPBridge.websocket.id ~= socketId then
    return
  end

  local command = data.command
  local requestId = data.requestId
  local params = data.params or {}

  print("[MCP Bridge] Received command: " .. (command or "unknown"))

  if command == "capture_screenshot" then
    MCPBridge.captureScreenshot(requestId, params)
  elseif command == "get_ui_tree" then
    MCPBridge.getUITree(requestId, params)
  else
    print("[MCP Bridge] Unknown command: " .. (command or "nil"))
  end
end

function MCPBridge.onClose(message, socketId)
  print("[MCP Bridge] Disconnected from MCP server")
  MCPBridge.connected = false
  MCPBridge.websocket = nil
  
  -- Try to reconnect
  MCPBridge.tryReconnect()
end

function MCPBridge.onError(message, socketId)
  print("[MCP Bridge] WebSocket error: " .. (message or "unknown"))
end

function MCPBridge.tryReconnect()
  if MCPBridge.reconnectAttempts >= MCPBridge.maxReconnectAttempts then
    print("[MCP Bridge] Max reconnection attempts reached")
    return
  end

  MCPBridge.reconnectAttempts = MCPBridge.reconnectAttempts + 1
  local delay = MCPBridge.reconnectDelay * (2 ^ math.min(MCPBridge.reconnectAttempts - 1, 5))
  
  print("[MCP Bridge] Reconnecting in " .. (delay / 1000) .. " seconds (attempt " .. MCPBridge.reconnectAttempts .. ")")
  
  scheduleEvent(function()
    MCPBridge.init()
  end, delay)
end

-- Captura screenshot e envia ao servidor
function MCPBridge.captureScreenshot(requestId, params)
  local type = params.type or "full"
  local annotation = params.annotation
  local timestamp = os.time()
  local filename = "mcp_screenshot_" .. timestamp .. ".png"

  print("[MCP Bridge] Capturing " .. type .. " screenshot")

  -- Captura UI tree
  local uiTree = UIInspector.getTree(5)

  -- Captura screenshot para disco (assíncrono)
  if type == "full" then
    g_app.doScreenshot(filename)
  else
    g_app.doMapScreenshot(filename)
  end

  -- Aguarda arquivo ser escrito e lê do disco
  local attempts = 0
  local maxAttempts = 20
  local lastSize = 0
  local stableCount = 0
  
  local function tryReadScreenshot()
    attempts = attempts + 1
    
    local writeDir = g_resources.getWriteDir()
    local fullPath = (writeDir .. filename):gsub("/", "\\")
    local file = io.open(fullPath, "rb")
    
    if file then
      local size = file:seek("end")
      file:close()
      
      if size > 100000 then
        if size == lastSize then
          stableCount = stableCount + 1
          
          if stableCount >= 2 then
            -- File is stable, read it
            local readFile = io.open(fullPath, "rb")
            if readFile then
              local imageData = readFile:read("*all")
              readFile:close()
              
              print("[MCP Bridge] Screenshot captured, size: " .. #imageData .. " bytes")
              
              -- Delete file
              pcall(function() os.remove(fullPath) end)
              
              -- Send data
              MCPBridge.sendScreenshotDataDirect(requestId, imageData, type, uiTree, annotation)
              return
            end
          end
        else
          stableCount = 0
          lastSize = size
        end
      else
        lastSize = size
      end
      
      if attempts < maxAttempts then
        scheduleEvent(tryReadScreenshot, 500)
      else
        print("[MCP Bridge] Screenshot timeout")
        MCPBridge.sendError(requestId, "Screenshot timeout")
      end
    elseif attempts < maxAttempts then
      scheduleEvent(tryReadScreenshot, 500)
    else
      print("[MCP Bridge] Screenshot file not created")
      MCPBridge.sendError(requestId, "Screenshot file not created")
    end
  end
  
  scheduleEvent(tryReadScreenshot, 500)
end

function MCPBridge.sendScreenshotDataDirect(requestId, imageData, type, uiTree, annotation)
  print("[MCP Bridge] Preparing screenshot data for sending")

  -- Convert to base64
  print("[MCP Bridge] Converting to base64...")
  local base64 = MCPBridge.toBase64(imageData)
  
  if not base64 then
    print("[MCP Bridge] Error: Could not convert screenshot to base64")
    MCPBridge.sendError(requestId, "Failed to convert screenshot to base64")
    return
  end
  
  print("[MCP Bridge] Base64 conversion successful, length: " .. #base64)

  -- Get image dimensions (assume standard size for now)
  local width = g_window.getWidth()
  local height = g_window.getHeight()

  -- Send response
  local response = {
    type = "screenshot_captured",
    requestId = requestId,
    data = {
      imageBase64 = base64,
      width = width,
      height = height,
      type = type,
      uiTree = uiTree
    }
  }

  if MCPBridge.websocket then
    MCPBridge.websocket.send(response)
    print("[MCP Bridge] Screenshot sent successfully")
  end
end

function MCPBridge.getUITree(requestId, params)
  local maxDepth = params.maxDepth or 5
  local uiTree = UIInspector.getTree(maxDepth)

  local response = {
    type = "ui_tree",
    requestId = requestId,
    data = uiTree
  }

  if MCPBridge.websocket then
    MCPBridge.websocket.send(response)
    print("[MCP Bridge] UI tree sent successfully")
  end
end

function MCPBridge.sendError(requestId, errorMessage)
  local response = {
    type = "error",
    requestId = requestId,
    error = errorMessage
  }

  if MCPBridge.websocket then
    MCPBridge.websocket.send(response)
  end
end

-- Convert binary data to base64
function MCPBridge.toBase64(data)
  -- Base64 encoding table
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local b64 = {}
  
  for i = 1, #data, 3 do
    local a, b, c = data:byte(i, i + 2)
    b = b or 0
    c = c or 0
    
    local n = a * 65536 + b * 256 + c
    local b1 = math.floor(n / 262144) % 64
    local b2 = math.floor(n / 4096) % 64
    local b3 = math.floor(n / 64) % 64
    local b4 = n % 64
    
    table.insert(b64, b64chars:sub(b1 + 1, b1 + 1))
    table.insert(b64, b64chars:sub(b2 + 1, b2 + 1))
    table.insert(b64, i + 1 <= #data and b64chars:sub(b3 + 1, b3 + 1) or '=')
    table.insert(b64, i + 2 <= #data and b64chars:sub(b4 + 1, b4 + 1) or '=')
  end
  
  return table.concat(b64)
end

function MCPBridge.terminate()
  if MCPBridge.websocket then
    MCPBridge.websocket.close()
    MCPBridge.websocket = nil
  end
  MCPBridge.connected = false
  print("[MCP Bridge] Terminated")
end

-- Export functions
return MCPBridge
