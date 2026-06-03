---
name: penpot-login
description: Connect to Penpot MCP - starts the MCP server, logs into penpot.schweitz.net, and installs/connects the plugin
allowed-tools: Read, Bash, mcp__chrome-devtools__new_page, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__click, mcp__chrome-devtools__fill, mcp__chrome-devtools__press_key, mcp__chrome-devtools__list_pages
---

# Penpot MCP Connection

This skill connects Claude to Penpot by:
1. Starting the Penpot MCP server (if not running)
2. Logging into penpot.schweitz.net via Authentik
3. Installing and connecting the Penpot MCP plugin

## Step 1: Start MCP Server

Check if the MCP server is running, start it if not:

```bash
# Check if server is running
if ! curl -s http://localhost:9880/mcp > /dev/null 2>&1; then
    # Start the server in background
    cd ~/Projects/penpot-mcp && ./start-server.sh &
    sleep 3  # Wait for server to start
fi
```

Server endpoints when running:
- MCP Server: http://localhost:9880/mcp
- Plugin Server: http://localhost:9879/
- WebSocket: ws://localhost:4402

## Step 2: Login Credentials

Read credentials from the project root file `claude-authentik-credentials.md`:
!`cat claude-authentik-credentials.md`

## Step 3: Login Flow

1. **Navigate to Penpot**
   - Use `mcp__chrome-devtools__new_page` to go to `https://penpot.schweitz.net`

2. **Check if already logged in**
   - Take a snapshot
   - If you see "Projects" heading, you're logged in - skip to Step 4
   - If you see login page, continue with authentication

3. **Authenticate via Authentik** (if not logged in)
   - Click the OpenID button to redirect to Authentik
   - On auth.schweitz.net, fill username textbox
   - Click "Log in" button
   - Fill password textbox
   - Click "Continue" button
   - If redirected to Authentik user page instead of Penpot, navigate back to `https://penpot.schweitz.net`

## Step 4: Open Design File

1. **Navigate to the Clide project**
   - Double-click on the TUI file to open the workspace

## Step 5: Install/Connect Plugin

1. **Open Plugins menu**
   - Click the Plugins button (puzzle icon, keyboard shortcut: Cmd+Alt+P)

2. **Check if plugin is installed**
   - If "Penpot MCP Plugin" appears under "INSTALLED PLUGINS", click OPEN
   - Otherwise, install it first:

3. **Install plugin** (if not installed)
   - Fill the plugin URL textbox with: `http://localhost:9879/manifest.json`
   - Click INSTALL
   - Click ALLOW on the permissions dialog

4. **Connect to MCP server**
   - In the plugin UI, click "CONNECT TO MCP SERVER"
   - Verify it shows "Connected to MCP server"

## Step 6: Configure Claude Code MCP

Add the Penpot MCP server to Claude Code (if not already configured):

```bash
claude mcp add penpot -t http http://localhost:9880/mcp
```

**Important**: Use HTTP transport (`-t http`) with the `/mcp` endpoint. Do NOT use SSE transport - it causes "Server not initialized" errors.

## Step 7: Verify Connection

After connecting, restart the MCP connection in Claude Code:
- Use `/mcp` command to reconnect the penpot server
- The Penpot MCP tools (execute_code, export_shape, etc.) will then be available

Test with:
```javascript
mcp__penpot__execute_code(code="return penpot.currentPage.name;")
```

## Important Notes

- Keep the Penpot plugin UI window open while using MCP tools
- The MCP server must be running for the plugin to connect
- If connection fails, check that the server is running on port 9880
- Use HTTP transport (`-t http`), NOT SSE transport
