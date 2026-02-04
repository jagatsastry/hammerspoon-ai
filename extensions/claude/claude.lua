--- === hs.claude ===
---
--- AI-powered macOS automation using Claude
---
--- This module provides natural language control of macOS using Claude's
--- vision and language capabilities. It supports both simple sequential
--- tasks and complex agentic loops with visual feedback.
---
--- ## Quick Start
---
--- ```lua
--- -- Configure with your API key
--- hs.claude.configure({
---     apiKey = os.getenv("ANTHROPIC_API_KEY")
--- })
---
--- -- Execute a command
--- hs.claude.execute("Open Safari and go to youtube.com", function(result)
---     if result.success then
---         hs.alert.show("Done!")
---     else
---         hs.alert.show("Error: " .. result.message)
---     end
--- end)
--- ```
---
--- ## Hotkey Integration
---
--- ```lua
--- hs.hotkey.bind({"cmd", "shift"}, "A", function()
---     local button, text = hs.dialog.textPrompt("Claude", "Command:", "", "Run", "Cancel")
---     if button == "Run" then
---         hs.claude.execute(text, function(result)
---             hs.alert.show(result.success and "Done!" or result.message)
---         end)
---     end
--- end)
--- ```

-- Load submodules
local api = require("hs.claude.api")
local vision = require("hs.claude.vision")
local actions = require("hs.claude.actions")
local parser = require("hs.claude.parser")
local agent = require("hs.claude.agent")
local prompts = require("hs.claude.prompts")
local coordinates = require("hs.claude.coordinates")

local module = {}

-- Export submodules
module.api = api
module.vision = vision
module.actions = actions
module.parser = parser
module.agent = agent
module.prompts = prompts
module.coordinates = coordinates

--- hs.claude.configure(options)
--- Function
--- Configure the Claude automation system
---
--- Parameters:
---  * options - A table with configuration options:
---    * apiKey - Anthropic API key (required)
---    * model - Claude model to use (default: claude-sonnet-4-20250514)
---    * maxTokens - Maximum response tokens (default: 4096)
---    * maxIterations - Maximum agentic loop iterations (default: 20)
---    * actionDelay - Delay between actions in seconds (default: 0.5)
---    * screenshotQuality - Screenshot quality 0-1 (default: 0.8)
---
--- Returns:
---  * None
function module.configure(options)
    if options.apiKey then
        api.configure({ apiKey = options.apiKey })
    end
    if options.model then
        api.configure({ model = options.model })
    end
    if options.maxTokens then
        api.configure({ maxTokens = options.maxTokens })
    end
    if options.maxIterations or options.actionDelay then
        agent.configure({
            maxIterations = options.maxIterations,
            actionDelay = options.actionDelay
        })
    end
    if options.screenshotQuality then
        vision.configure({ screenshotQuality = options.screenshotQuality })
    end
end

--- hs.claude.setApiKey(key)
--- Function
--- Set the Anthropic API key
---
--- Parameters:
---  * key - API key string
---
--- Returns:
---  * None
function module.setApiKey(key)
    api.setApiKey(key)
end

--- hs.claude.execute(command, callback)
--- Function
--- Execute a natural language command (async)
---
--- Parameters:
---  * command - Natural language command string
---  * callback - Function called with (result)
---    * result.success - boolean indicating success
---    * result.message - completion or error message
---    * result.steps - array of executed actions
---    * result.iterations - number of agentic iterations used
---
--- Returns:
---  * None
---
--- Examples:
--- ```lua
--- -- Simple command (no vision needed)
--- hs.claude.execute("Open Safari", function(r) print(r.success) end)
---
--- -- Complex command (uses vision)
--- hs.claude.execute("Search YouTube for cooking tutorials", function(r)
---     for i, step in ipairs(r.steps) do
---         print(step.action, step.success)
---     end
--- end)
--- ```
function module.execute(command, callback)
    if not api.isConfigured() then
        callback({
            success = false,
            message = "API key not configured. Call hs.claude.configure({apiKey=...}) first.",
            steps = {},
            iterations = 0
        })
        return
    end

    agent.execute(command, callback)
end

--- hs.claude.isConfigured() -> boolean
--- Function
--- Check if Claude is configured with an API key
---
--- Returns:
---  * true if configured, false otherwise
function module.isConfigured()
    return api.isConfigured()
end

--- hs.claude.describe(callback)
--- Function
--- Describe the current screen state (async)
---
--- Parameters:
---  * callback - Function called with (description, error)
---
--- Returns:
---  * None
function module.describe(callback)
    if not api.isConfigured() then
        callback(nil, "API key not configured")
        return
    end

    vision.describeScreen(callback)
end

--- hs.claude.findElement(description, callback)
--- Function
--- Find a UI element on screen and return its coordinates (async)
---
--- Parameters:
---  * description - Text description of the element
---  * callback - Function called with (coordinates, error)
---    * coordinates.logicalX, coordinates.logicalY - for clicking
---
--- Returns:
---  * None
function module.findElement(description, callback)
    if not api.isConfigured() then
        callback(nil, "API key not configured")
        return
    end

    vision.findElement(description, callback)
end

--- hs.claude.click(description, callback)
--- Function
--- Find and click a UI element (async)
---
--- Parameters:
---  * description - Text description of the element to click
---  * callback - Function called with (success, error)
---
--- Returns:
---  * None
function module.click(description, callback)
    if not api.isConfigured() then
        callback(false, "API key not configured")
        return
    end

    vision.findElement(description, function(coords, findErr)
        if findErr then
            callback(false, findErr)
            return
        end

        local success, clickErr = actions.click(coords.logicalX, coords.logicalY)
        callback(success, clickErr)
    end)
end

--- hs.claude.ask(question, callback)
--- Function
--- Ask Claude a question about the current screen (async)
---
--- Parameters:
---  * question - Question about the screen content
---  * callback - Function called with (answer, error)
---
--- Returns:
---  * None
function module.ask(question, callback)
    if not api.isConfigured() then
        callback(nil, "API key not configured")
        return
    end

    vision.extractInfo(question, callback)
end

--- hs.claude.check(condition, callback)
--- Function
--- Check if a condition is true on the current screen (async)
---
--- Parameters:
---  * condition - Condition to check (e.g., "Is Safari open?")
---  * callback - Function called with (boolean, error)
---
--- Returns:
---  * None
function module.check(condition, callback)
    if not api.isConfigured() then
        callback(nil, "API key not configured")
        return
    end

    vision.checkCondition(condition, callback)
end

-- Version info
module._VERSION = "1.0.0"
module._DESCRIPTION = "AI-powered macOS automation using Claude"
module._AUTHOR = "Hammerspoon AI"

return module
