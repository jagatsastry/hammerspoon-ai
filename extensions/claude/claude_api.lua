--- === hs.claude.api ===
---
--- Claude API client for Hammerspoon
---
--- Provides async HTTP interface to Claude's Messages API with vision support.

local http = require("hs.http")
local json = require("hs.json")

local module = {}

-- Private state
local config = {
    apiKey = nil,
    baseUrl = "https://api.anthropic.com/v1/messages",
    model = "claude-sonnet-4-20250514",
    maxTokens = 4096,
    apiVersion = "2023-06-01"
}

--- hs.claude.api.configure(options)
--- Function
--- Configure the Claude API client
---
--- Parameters:
---  * options - A table with configuration options:
---    * apiKey - Anthropic API key (required)
---    * model - Model to use (default: claude-sonnet-4-20250514)
---    * maxTokens - Maximum response tokens (default: 4096)
---
--- Returns:
---  * None
function module.configure(options)
    if options.apiKey then config.apiKey = options.apiKey end
    if options.model then config.model = options.model end
    if options.maxTokens then config.maxTokens = options.maxTokens end
end

--- hs.claude.api.setApiKey(key)
--- Function
--- Set the Anthropic API key
---
--- Parameters:
---  * key - The API key string
---
--- Returns:
---  * None
function module.setApiKey(key)
    config.apiKey = key
end

--- hs.claude.api.getModel() -> string
--- Function
--- Get the currently configured model
---
--- Returns:
---  * The model identifier string
function module.getModel()
    return config.model
end

-- Internal: Build request headers
local function buildHeaders()
    return {
        ["Content-Type"] = "application/json",
        ["x-api-key"] = config.apiKey,
        ["anthropic-version"] = config.apiVersion
    }
end

-- Internal: Parse API response
local function parseResponse(status, body, headers)
    if status < 0 then
        return nil, "Network error: " .. (body or "unknown")
    end

    local ok, data = pcall(json.decode, body)
    if not ok then
        return nil, "JSON parse error: " .. tostring(data)
    end

    if status ~= 200 then
        local errorMsg = "API error"
        if data and data.error then
            errorMsg = data.error.message or data.error.type or "Unknown API error"
        end
        return nil, string.format("HTTP %d: %s", status, errorMsg)
    end

    return data, nil
end

-- Internal: Extract text from response
local function extractText(response)
    if not response or not response.content then
        return ""
    end

    local text = ""
    for _, block in ipairs(response.content) do
        if block.type == "text" then
            text = text .. block.text
        end
    end
    return text
end

-- Internal: Detect image media type from base64 data
local function detectMediaType(base64Data)
    -- Check first few characters to identify format
    if base64Data:sub(1, 4) == "/9j/" then
        return "image/jpeg"
    elseif base64Data:sub(1, 5) == "iVBOR" then
        return "image/png"
    elseif base64Data:sub(1, 6) == "R0lGOD" then
        return "image/gif"
    elseif base64Data:sub(1, 6) == "UklGR" then
        return "image/webp"
    end
    -- Default to PNG
    return "image/png"
end

--- hs.claude.api.message(params, callback)
--- Function
--- Send a message to Claude API (async)
---
--- Parameters:
---  * params - A table with:
---    * messages - Array of message objects
---    * system - Optional system prompt
---    * model - Optional model override
---    * max_tokens - Optional max tokens override
---  * callback - Function called with (response, error)
---
--- Returns:
---  * None
function module.message(params, callback)
    if not config.apiKey then
        callback(nil, "API key not configured. Call hs.claude.api.setApiKey() first.")
        return
    end

    local requestBody = {
        model = params.model or config.model,
        max_tokens = params.max_tokens or config.maxTokens,
        messages = params.messages
    }

    if params.system then
        requestBody.system = params.system
    end

    local bodyJson = json.encode(requestBody)
    local headers = buildHeaders()

    http.asyncPost(config.baseUrl, bodyJson, headers, function(status, body, respHeaders)
        local response, err = parseResponse(status, body, respHeaders)
        if err then
            callback(nil, err)
            return
        end

        local text = extractText(response)
        callback({
            text = text,
            raw = response,
            model = response.model,
            usage = response.usage
        }, nil)
    end)
end

--- hs.claude.api.messageWithImage(params, imageBase64, callback)
--- Function
--- Send a message with an image to Claude API (async)
---
--- Parameters:
---  * params - A table with:
---    * prompt - Text prompt to accompany the image
---    * system - Optional system prompt
---    * model - Optional model override
---    * max_tokens - Optional max tokens override
---    * mediaType - Optional media type (auto-detected if not provided)
---  * imageBase64 - Base64 encoded image data
---  * callback - Function called with (response, error)
---
--- Returns:
---  * None
function module.messageWithImage(params, imageBase64, callback)
    if not config.apiKey then
        callback(nil, "API key not configured. Call hs.claude.api.setApiKey() first.")
        return
    end

    -- Detect or use provided media type
    local mediaType = params.mediaType or detectMediaType(imageBase64)

    -- Build message with image
    local messages = {
        {
            role = "user",
            content = {
                {
                    type = "image",
                    source = {
                        type = "base64",
                        media_type = mediaType,
                        data = imageBase64
                    }
                },
                {
                    type = "text",
                    text = params.prompt or "Describe this image."
                }
            }
        }
    }

    local requestBody = {
        model = params.model or config.model,
        max_tokens = params.max_tokens or config.maxTokens,
        messages = messages
    }

    if params.system then
        requestBody.system = params.system
    end

    local bodyJson = json.encode(requestBody)
    local headers = buildHeaders()

    http.asyncPost(config.baseUrl, bodyJson, headers, function(status, body, respHeaders)
        local response, err = parseResponse(status, body, respHeaders)
        if err then
            callback(nil, err)
            return
        end

        local text = extractText(response)
        callback({
            text = text,
            raw = response,
            model = response.model,
            usage = response.usage
        }, nil)
    end)
end

--- hs.claude.api.simpleMessage(prompt, callback)
--- Function
--- Send a simple text message to Claude (async)
---
--- Parameters:
---  * prompt - Text prompt string
---  * callback - Function called with (responseText, error)
---
--- Returns:
---  * None
function module.simpleMessage(prompt, callback)
    module.message({
        messages = {
            { role = "user", content = prompt }
        }
    }, function(response, err)
        if err then
            callback(nil, err)
        else
            callback(response.text, nil)
        end
    end)
end

--- hs.claude.api.isConfigured() -> boolean
--- Function
--- Check if the API is configured with an API key
---
--- Returns:
---  * true if API key is set, false otherwise
function module.isConfigured()
    return config.apiKey ~= nil and config.apiKey ~= ""
end

return module
