-- Reload MCP Bridge module
print("=== Reloading MCP Bridge ===")

-- Terminate existing connection
if MCPBridge then
  MCPBridge.terminate()
end

-- Clear the module
package.loaded['mcp_bridge'] = nil
package.loaded['ui_inspector'] = nil

-- Reload
dofile('ui_inspector.lua')
dofile('mcp_bridge.lua')

print("✓ MCP Bridge reloaded")
print("Initializing connection...")

-- Initialize connection
MCPBridge.init()

-- Wait a bit and check connection status
scheduleEvent(function()
  print("Connection status:", MCPBridge.connected and "CONNECTED" or "DISCONNECTED")
  if MCPBridge.connected then
    print("✓ Ready to capture screenshots")
  else
    print("⚠ Not connected yet, may still be connecting...")
  end
end, 2000)
