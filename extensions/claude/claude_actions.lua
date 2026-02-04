--- === hs.claude.actions ===
---
--- Action implementations for macOS automation
---
--- Provides a unified interface for executing automation actions using
--- Hammerspoon's native APIs.

local application = require("hs.application")
local eventtap = require("hs.eventtap")
local mouse = require("hs.mouse")
local timer = require("hs.timer")
local osascript = require("hs.osascript")

local module = {}

-- Private state
local config = {
    clickDelay = 200000,  -- microseconds (200ms)
    typeDelay = 50000,    -- microseconds between keystrokes
    actionDelay = 500     -- milliseconds between actions
}

--- hs.claude.actions.configure(options)
--- Function
--- Configure action settings
---
--- Parameters:
---  * options - A table with:
---    * clickDelay - Delay between mouse down/up in microseconds
---    * typeDelay - Delay between keystrokes in microseconds
---    * actionDelay - Delay between actions in milliseconds
---
--- Returns:
---  * None
function module.configure(options)
    if options.clickDelay then config.clickDelay = options.clickDelay end
    if options.typeDelay then config.typeDelay = options.typeDelay end
    if options.actionDelay then config.actionDelay = options.actionDelay end
end

--- hs.claude.actions.activateApp(appName) -> boolean, string
--- Function
--- Launches or activates an application
---
--- Parameters:
---  * appName - Name of the application
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.activateApp(appName)
    -- Try to find running app first
    local app = application.get(appName)

    if app then
        -- App is running, activate it
        local success = app:activate()
        if success then
            return true, nil
        else
            return false, "Failed to activate " .. appName
        end
    else
        -- App not running, try to launch
        local success = application.launchOrFocus(appName)
        if success then
            -- Wait a bit for app to launch
            timer.usleep(500000)  -- 500ms
            return true, nil
        else
            return false, "Failed to launch " .. appName
        end
    end
end

--- hs.claude.actions.quitApp(appName) -> boolean, string
--- Function
--- Quits an application
---
--- Parameters:
---  * appName - Name of the application
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.quitApp(appName)
    local app = application.get(appName)
    if not app then
        return false, "Application not found: " .. appName
    end

    local success = app:kill()
    return success, success and nil or "Failed to quit " .. appName
end

--- hs.claude.actions.openUrl(url, browser) -> boolean, string
--- Function
--- Opens a URL in a browser
---
--- Parameters:
---  * url - URL to open
---  * browser - Optional browser name (default: system default)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.openUrl(url, browser)
    -- Ensure URL has protocol
    if not url:match("^https?://") then
        url = "https://" .. url
    end

    if browser then
        -- Open in specific browser
        local script = string.format([[
            tell application "%s"
                activate
                open location "%s"
            end tell
        ]], browser, url)

        local ok, result, raw = osascript.applescript(script)
        if ok then
            return true, nil
        else
            return false, "Failed to open URL in " .. browser .. ": " .. tostring(raw)
        end
    else
        -- Open with default handler using AppleScript
        local script = string.format([[
            open location "%s"
        ]], url)

        local ok, result, raw = osascript.applescript(script)
        if ok then
            return true, nil
        else
            return false, "Failed to open URL: " .. tostring(raw)
        end
    end
end

--- hs.claude.actions.click(x, y) -> boolean, string
--- Function
--- Performs a left click at the specified coordinates
---
--- Parameters:
---  * x - Logical X coordinate
---  * y - Logical Y coordinate
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.click(x, y)
    local point = { x = x, y = y }

    -- Perform click
    eventtap.leftClick(point, config.clickDelay)

    return true, nil
end

--- hs.claude.actions.doubleClick(x, y) -> boolean, string
--- Function
--- Performs a double click at the specified coordinates
---
--- Parameters:
---  * x - Logical X coordinate
---  * y - Logical Y coordinate
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.doubleClick(x, y)
    local point = { x = x, y = y }

    -- Perform double click
    eventtap.leftClick(point, config.clickDelay)
    timer.usleep(100000)  -- 100ms delay
    eventtap.leftClick(point, config.clickDelay)

    return true, nil
end

--- hs.claude.actions.rightClick(x, y) -> boolean, string
--- Function
--- Performs a right click at the specified coordinates
---
--- Parameters:
---  * x - Logical X coordinate
---  * y - Logical Y coordinate
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.rightClick(x, y)
    local point = { x = x, y = y }

    -- Perform right click
    eventtap.rightClick(point, config.clickDelay)

    return true, nil
end

--- hs.claude.actions.moveTo(x, y) -> boolean, string
--- Function
--- Moves the mouse to specified coordinates
---
--- Parameters:
---  * x - Logical X coordinate
---  * y - Logical Y coordinate
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.moveTo(x, y)
    mouse.absolutePosition({ x = x, y = y })
    return true, nil
end

--- hs.claude.actions.scroll(direction, amount) -> boolean, string
--- Function
--- Scrolls in a direction
---
--- Parameters:
---  * direction - "up", "down", "left", or "right"
---  * amount - Number of scroll units (default: 3)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.scroll(direction, amount)
    amount = amount or 3

    local scrollAmount = 0
    if direction == "up" then
        scrollAmount = amount
    elseif direction == "down" then
        scrollAmount = -amount
    elseif direction == "left" then
        -- Horizontal scrolling via AppleScript
        local script = string.format([[
            tell application "System Events"
                key code 123 using {shift down}  -- left arrow with shift
            end tell
        ]])
        osascript.applescript(script)
        return true, nil
    elseif direction == "right" then
        local script = string.format([[
            tell application "System Events"
                key code 124 using {shift down}  -- right arrow with shift
            end tell
        ]])
        osascript.applescript(script)
        return true, nil
    else
        return false, "Invalid scroll direction: " .. tostring(direction)
    end

    -- Vertical scroll
    eventtap.scrollWheel({ 0, scrollAmount }, {})

    return true, nil
end

--- hs.claude.actions.typeText(text) -> boolean, string
--- Function
--- Types text using keyboard simulation
---
--- Parameters:
---  * text - Text to type
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.typeText(text)
    -- Use eventtap.keyStrokes for reliable text entry
    eventtap.keyStrokes(text)

    return true, nil
end

--- hs.claude.actions.pressKey(key, modifiers) -> boolean, string
--- Function
--- Presses a key with optional modifiers
---
--- Parameters:
---  * key - Key name (e.g., "return", "escape", "tab", "a")
---  * modifiers - Optional table of modifiers (e.g., {"cmd", "shift"})
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.pressKey(key, modifiers)
    modifiers = modifiers or {}

    -- Map common key names
    local keyMap = {
        ["return"] = "return",
        ["enter"] = "return",
        ["escape"] = "escape",
        ["esc"] = "escape",
        ["tab"] = "tab",
        ["space"] = "space",
        ["delete"] = "delete",
        ["backspace"] = "delete",
        ["up"] = "up",
        ["down"] = "down",
        ["left"] = "left",
        ["right"] = "right"
    }

    local mappedKey = keyMap[key:lower()] or key

    -- Create and post key event
    eventtap.keyStroke(modifiers, mappedKey)

    return true, nil
end

--- hs.claude.actions.wait(seconds) -> boolean, string
--- Function
--- Waits for specified number of seconds
---
--- Parameters:
---  * seconds - Number of seconds to wait
---
--- Returns:
---  * success - boolean
---  * error - always nil
function module.wait(seconds)
    timer.usleep(math.floor(seconds * 1000000))
    return true, nil
end

--- hs.claude.actions.execute(action, params) -> boolean, string
--- Function
--- Executes an action by name
---
--- Parameters:
---  * action - Action name (e.g., "activate_app", "click")
---  * params - Table of parameters for the action
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.execute(action, params)
    params = params or {}

    if action == "activate_app" then
        return module.activateApp(params.appName)

    elseif action == "quit_app" then
        return module.quitApp(params.appName)

    elseif action == "open_url" then
        return module.openUrl(params.url, params.browser)

    elseif action == "click" then
        return module.click(params.x, params.y)

    elseif action == "double_click" then
        return module.doubleClick(params.x, params.y)

    elseif action == "right_click" then
        return module.rightClick(params.x, params.y)

    elseif action == "move_to" then
        return module.moveTo(params.x, params.y)

    elseif action == "scroll" then
        return module.scroll(params.direction, params.amount)

    elseif action == "type_text" then
        return module.typeText(params.text)

    elseif action == "press_key" then
        return module.pressKey(params.key, params.modifiers)

    elseif action == "wait" then
        return module.wait(params.seconds or 1)

    else
        return false, "Unknown action: " .. tostring(action)
    end
end

--- hs.claude.actions.getActionDelay() -> number
--- Function
--- Gets the configured delay between actions in seconds
---
--- Returns:
---  * Delay in seconds
function module.getActionDelay()
    return config.actionDelay / 1000
end

--- hs.claude.actions.getFrontmostApp() -> string, string
--- Function
--- Gets the name of the frontmost application
---
--- Parameters:
---  * None
---
--- Returns:
---  * appName - Name of the frontmost app
---  * error - error message if failed
function module.getFrontmostApp()
    local app = application.frontmostApplication()
    if app then
        return app:name(), nil
    else
        return nil, "Could not determine frontmost application"
    end
end

--- hs.claude.actions.isAppRunning(appName) -> boolean, string
--- Function
--- Checks if an application is currently running
---
--- Parameters:
---  * appName - Name of the application
---
--- Returns:
---  * running - boolean indicating if app is running
---  * error - error message if failed
function module.isAppRunning(appName)
    local app = application.get(appName)
    return app ~= nil, nil
end

--- hs.claude.actions.typeTextAppleScript(text) -> boolean, string
--- Function
--- Types text using AppleScript (more reliable for some apps)
---
--- Parameters:
---  * text - Text to type
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.typeTextAppleScript(text)
    -- Escape special characters for AppleScript
    local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')

    local script = string.format([[
        tell application "System Events"
            keystroke "%s"
        end tell
    ]], escaped)

    local ok, result, raw = osascript.applescript(script)
    if ok then
        return true, nil
    else
        return false, "Failed to type text: " .. tostring(raw)
    end
end

--- hs.claude.actions.pressKeyAppleScript(key, modifiers) -> boolean, string
--- Function
--- Presses a key using AppleScript (supports more key codes)
---
--- Parameters:
---  * key - Key name or key code
---  * modifiers - Optional table of modifiers
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.pressKeyAppleScript(key, modifiers)
    modifiers = modifiers or {}

    -- Map key names to AppleScript key codes
    local keyCodes = {
        ["return"] = 36,
        ["enter"] = 76,
        ["tab"] = 48,
        ["space"] = 49,
        ["delete"] = 51,
        ["escape"] = 53,
        ["up"] = 126,
        ["down"] = 125,
        ["left"] = 123,
        ["right"] = 124,
        ["f1"] = 122,
        ["f2"] = 120,
        ["f3"] = 99,
        ["f4"] = 118,
        ["f5"] = 96,
        ["f6"] = 97,
        ["f7"] = 98,
        ["f8"] = 100,
        ["f9"] = 101,
        ["f10"] = 109,
        ["f11"] = 103,
        ["f12"] = 111,
        ["home"] = 115,
        ["end"] = 119,
        ["pageup"] = 116,
        ["pagedown"] = 121
    }

    -- Build modifier string
    local modifierParts = {}
    for _, mod in ipairs(modifiers) do
        local modMap = {
            ["cmd"] = "command down",
            ["command"] = "command down",
            ["shift"] = "shift down",
            ["alt"] = "option down",
            ["option"] = "option down",
            ["ctrl"] = "control down",
            ["control"] = "control down",
            ["fn"] = "function down"
        }
        if modMap[mod:lower()] then
            table.insert(modifierParts, modMap[mod:lower()])
        end
    end

    local modifierStr = ""
    if #modifierParts > 0 then
        modifierStr = " using {" .. table.concat(modifierParts, ", ") .. "}"
    end

    local keyCode = keyCodes[key:lower()]
    local script

    if keyCode then
        script = string.format([[
            tell application "System Events"
                key code %d%s
            end tell
        ]], keyCode, modifierStr)
    else
        -- Single character key
        script = string.format([[
            tell application "System Events"
                keystroke "%s"%s
            end tell
        ]], key, modifierStr)
    end

    local ok, result, raw = osascript.applescript(script)
    if ok then
        return true, nil
    else
        return false, "Failed to press key: " .. tostring(raw)
    end
end

--- hs.claude.actions.selectAll() -> boolean, string
--- Function
--- Selects all content (Cmd+A)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.selectAll()
    return module.pressKey("a", {"cmd"})
end

--- hs.claude.actions.copy() -> boolean, string
--- Function
--- Copies selected content (Cmd+C)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.copy()
    return module.pressKey("c", {"cmd"})
end

--- hs.claude.actions.paste() -> boolean, string
--- Function
--- Pastes from clipboard (Cmd+V)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.paste()
    return module.pressKey("v", {"cmd"})
end

--- hs.claude.actions.cut() -> boolean, string
--- Function
--- Cuts selected content (Cmd+X)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.cut()
    return module.pressKey("x", {"cmd"})
end

--- hs.claude.actions.undo() -> boolean, string
--- Function
--- Undoes last action (Cmd+Z)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.undo()
    return module.pressKey("z", {"cmd"})
end

--- hs.claude.actions.clearField() -> boolean, string
--- Function
--- Clears the current text field (Select all + Delete)
---
--- Returns:
---  * success - boolean
---  * error - error message if failed
function module.clearField()
    local success, err = module.selectAll()
    if not success then
        return false, err
    end
    timer.usleep(50000)  -- 50ms
    return module.pressKey("delete", {})
end

return module
