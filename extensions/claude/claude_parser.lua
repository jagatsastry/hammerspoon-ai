--- === hs.claude.parser ===
---
--- Intent parser for natural language commands
---
--- Converts user commands into structured action sequences using Claude.

local json = require("hs.json")

local api = require("hs.claude.api")
local prompts = require("hs.claude.prompts")

local module = {}

--- hs.claude.parser.parse(command, callback)
--- Function
--- Parses a natural language command into structured intent (async)
---
--- Parameters:
---  * command - Natural language command string
---  * callback - Function called with (intent, error)
---    * intent is a table with:
---      * steps - Array of {action, params} tables
---      * requiresObservation - boolean
---      * goal - Summary of the goal
---
--- Returns:
---  * None
function module.parse(command, callback)
    local prompt = string.format([[Parse this command into automation steps:

"%s"

Return valid JSON with the schema:
{
  "steps": [ { "action": "...", "params": {...} }, ... ],
  "requiresObservation": boolean,
  "goal": "summary"
}]], command)

    api.message({
        messages = {
            { role = "user", content = prompt }
        },
        system = prompts.INTENT_PARSER
    }, function(response, err)
        if err then
            callback(nil, err)
            return
        end

        -- Extract JSON from response
        local jsonStr = module.extractJson(response.text)
        if not jsonStr then
            callback(nil, "Failed to parse response as JSON")
            return
        end

        local ok, intent = pcall(json.decode, jsonStr)
        if not ok then
            callback(nil, "JSON parse error: " .. tostring(intent))
            return
        end

        -- Validate intent structure
        if not intent.steps or type(intent.steps) ~= "table" then
            intent.steps = {}
        end

        if intent.requiresObservation == nil then
            -- Default to requiring observation for click_element actions
            intent.requiresObservation = false
            for _, step in ipairs(intent.steps) do
                if step.action == "click_element" then
                    intent.requiresObservation = true
                    break
                end
            end
        end

        intent.goal = intent.goal or command

        callback(intent, nil)
    end)
end

--- hs.claude.parser.extractJson(text) -> string or nil
--- Function
--- Extracts JSON from a text response
---
--- Parameters:
---  * text - Text that may contain JSON
---
--- Returns:
---  * JSON string or nil if not found
function module.extractJson(text)
    if not text then return nil end

    -- Try to find JSON object
    local jsonStart = text:find("{")
    local jsonEnd = text:reverse():find("}")

    if jsonStart and jsonEnd then
        jsonEnd = #text - jsonEnd + 1
        local jsonStr = text:sub(jsonStart, jsonEnd)

        -- Verify it's valid JSON
        local ok, _ = pcall(json.decode, jsonStr)
        if ok then
            return jsonStr
        end
    end

    -- Try to extract from markdown code block
    local codeBlock = text:match("```json?%s*(.-)%s*```")
    if codeBlock then
        return codeBlock
    end

    return nil
end

--- hs.claude.parser.normalizeAction(action) -> string
--- Function
--- Normalizes an action name to the standard format
---
--- Parameters:
---  * action - Action name string
---
--- Returns:
---  * Normalized action name
function module.normalizeAction(action)
    local mapping = {
        ["activate"] = "activate_app",
        ["launch"] = "activate_app",
        ["open_app"] = "activate_app",
        ["start"] = "activate_app",
        ["quit"] = "quit_app",
        ["close"] = "quit_app",
        ["kill"] = "quit_app",
        ["open"] = "open_url",
        ["url"] = "open_url",
        ["browse"] = "open_url",
        ["click"] = "click_element",
        ["tap"] = "click_element",
        ["press"] = "click_element",
        ["type"] = "type_text",
        ["input"] = "type_text",
        ["write"] = "type_text",
        ["key"] = "press_key",
        ["hotkey"] = "press_key",
        ["shortcut"] = "press_key",
        ["scroll_up"] = "scroll",
        ["scroll_down"] = "scroll",
        ["wait"] = "wait",
        ["sleep"] = "wait",
        ["delay"] = "wait"
    }

    return mapping[action:lower()] or action
end

--- hs.claude.parser.validateIntent(intent) -> boolean, string
--- Function
--- Validates an intent structure
---
--- Parameters:
---  * intent - Intent table to validate
---
--- Returns:
---  * valid - boolean
---  * error - error message if invalid
function module.validateIntent(intent)
    if not intent then
        return false, "Intent is nil"
    end

    if type(intent.steps) ~= "table" then
        return false, "Intent.steps must be a table"
    end

    for i, step in ipairs(intent.steps) do
        if not step.action then
            return false, string.format("Step %d missing action", i)
        end
        if type(step.params) ~= "table" and step.params ~= nil then
            return false, string.format("Step %d params must be a table", i)
        end
    end

    return true, nil
end

--- hs.claude.parser.classifyComplexity(command) -> boolean
--- Function
--- Quickly determines if a task requires observation (vision) without calling the LLM
---
--- Parameters:
---  * command - Natural language command string
---
--- Returns:
---  * true if task requires observation, false for simple execution
---
--- Notes:
---  * This is a heuristic-based classification for quick decisions
---  * For accurate classification, use the full parse() function
function module.classifyComplexity(command)
    local commandLower = command:lower()

    -- Keywords that indicate simple tasks (no vision needed)
    local simpleKeywords = {
        "open", "launch", "start", "quit", "close", "exit",
        "go to", "navigate to", "visit", "search youtube for",
        "search google for", "google ", "youtube "
    }

    -- Keywords that indicate complex tasks (vision needed)
    local complexKeywords = {
        "click", "find", "most popular", "first result", "best",
        "select", "choose", "pick", "look for", "locate", "identify",
        "fill", "form", "cheapest", "highest", "lowest", "compare",
        "book", "reserve", "buy ticket"
    }

    -- Check for complex indicators first (higher priority)
    for _, keyword in ipairs(complexKeywords) do
        if commandLower:find(keyword, 1, true) then
            return true
        end
    end

    -- Check for simple indicators
    for _, keyword in ipairs(simpleKeywords) do
        if commandLower:find(keyword, 1, true) then
            return false
        end
    end

    -- Default to requiring observation for safety
    return true
end

--- hs.claude.parser.normalizeAppName(appName) -> string
--- Function
--- Normalizes an application name to the official macOS app name
---
--- Parameters:
---  * appName - User-provided application name
---
--- Returns:
---  * Normalized application name
function module.normalizeAppName(appName)
    local mapping = {
        ["chrome"] = "Google Chrome",
        ["safari"] = "Safari",
        ["firefox"] = "Firefox",
        ["vscode"] = "Visual Studio Code",
        ["code"] = "Visual Studio Code",
        ["terminal"] = "Terminal",
        ["iterm"] = "iTerm",
        ["iterm2"] = "iTerm",
        ["slack"] = "Slack",
        ["discord"] = "Discord",
        ["zoom"] = "zoom.us",
        ["teams"] = "Microsoft Teams",
        ["word"] = "Microsoft Word",
        ["excel"] = "Microsoft Excel",
        ["powerpoint"] = "Microsoft PowerPoint",
        ["outlook"] = "Microsoft Outlook",
        ["notes"] = "Notes",
        ["mail"] = "Mail",
        ["calendar"] = "Calendar",
        ["messages"] = "Messages",
        ["facetime"] = "FaceTime",
        ["finder"] = "Finder",
        ["preview"] = "Preview",
        ["textedit"] = "TextEdit",
        ["activity monitor"] = "Activity Monitor",
        ["system preferences"] = "System Preferences",
        ["system settings"] = "System Settings",
        ["spotify"] = "Spotify"
    }

    return mapping[appName:lower()] or appName
end

--- hs.claude.parser.normalizeUrl(url) -> string
--- Function
--- Normalizes a partial URL or site name to a full URL
---
--- Parameters:
---  * url - Partial URL or site name
---
--- Returns:
---  * Full URL with protocol
function module.normalizeUrl(url)
    -- Already has protocol
    if url:match("^https?://") then
        return url
    end

    -- Common site mappings
    local siteMapping = {
        ["youtube"] = "https://www.youtube.com",
        ["google"] = "https://www.google.com",
        ["github"] = "https://github.com",
        ["reddit"] = "https://www.reddit.com",
        ["twitter"] = "https://x.com",
        ["x"] = "https://x.com",
        ["facebook"] = "https://www.facebook.com",
        ["amazon"] = "https://www.amazon.com",
        ["netflix"] = "https://www.netflix.com",
        ["spotify"] = "https://open.spotify.com"
    }

    local normalized = siteMapping[url:lower()]
    if normalized then
        return normalized
    end

    -- Add https:// prefix
    return "https://" .. url
end

return module
