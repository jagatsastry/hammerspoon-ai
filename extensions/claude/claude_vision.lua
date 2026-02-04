--- === hs.claude.vision ===
---
--- Screen capture and vision analysis using Claude
---
--- Captures screenshots and uses Claude's vision capabilities to analyze
--- screen content, find UI elements, and verify conditions.

local screen = require("hs.screen")
local image = require("hs.image")

local api = require("hs.claude.api")
local prompts = require("hs.claude.prompts")
local coords = require("hs.claude.coordinates")

local module = {}

-- Private state
local config = {
    screenshotQuality = 0.85,
    maxImageBytes = 4500000,  -- 4.5MB (leave room for base64 overhead under Anthropic's 5MB limit)
    jpegQualityLevels = { 85, 70, 55, 40, 30 },  -- Quality levels to try
    resizeScales = { 0.75, 0.5, 0.4, 0.3 }  -- Scale factors to try if still too large
}

--- hs.claude.vision.configure(options)
--- Function
--- Configure vision settings
---
--- Parameters:
---  * options - A table with:
---    * screenshotQuality - JPEG quality 0-1 (default: 0.85)
---    * maxImageBytes - Maximum image size in bytes (default: 4.5MB)
---
--- Returns:
---  * None
function module.configure(options)
    if options.screenshotQuality then
        config.screenshotQuality = options.screenshotQuality
    end
    if options.maxImageBytes then
        config.maxImageBytes = options.maxImageBytes
    end
end

-- Internal: Calculate base64 encoded size from raw bytes
local function estimateBase64Size(rawBytes)
    return math.ceil(rawBytes * 4 / 3)
end

-- Internal: Compress image data to stay under size limit
-- Tries progressively lower quality levels, then resizes if needed
local function compressImage(snapshot, screenInfo)
    -- Try different quality levels first
    for _, quality in ipairs(config.jpegQualityLevels) do
        -- Convert quality from 0-100 to 0-1 for Hammerspoon
        local normalizedQuality = quality / 100

        -- Encode as JPEG
        local jpegData = snapshot:encodeAsURLString(false, "JPEG", normalizedQuality)
        if jpegData then
            local base64 = jpegData:gsub("^data:image/jpeg;base64,", "")
            if #base64 <= config.maxImageBytes then
                return base64, "image/jpeg"
            end
        end
    end

    -- If still too large, resize and compress
    -- Note: Hammerspoon's hs.image doesn't have direct resize, so we use a workaround
    -- by capturing at lower resolution using hs.screen:snapshot() with scale
    for _, scale in ipairs(config.resizeScales) do
        local scaledSnapshot = snapshot:size()
        if scaledSnapshot then
            -- Create a scaled version using image:copy()
            local newWidth = math.floor(scaledSnapshot.w * scale)
            local newHeight = math.floor(scaledSnapshot.h * scale)

            -- Use the setSize method if available, otherwise continue with original
            local resized = snapshot:setSize({ w = newWidth, h = newHeight }, false)
            if resized then
                local jpegData = resized:encodeAsURLString(false, "JPEG", 0.50)
                if jpegData then
                    local base64 = jpegData:gsub("^data:image/jpeg;base64,", "")
                    if #base64 <= config.maxImageBytes then
                        return base64, "image/jpeg"
                    end
                end
            end
        end
    end

    -- Last resort: return PNG data as is
    local pngData = snapshot:encodeAsURLString(false, "PNG")
    local base64 = pngData:gsub("^data:image/png;base64,", "")
    return base64, "image/png"
end

--- hs.claude.vision.captureScreen() -> string, table, string
--- Function
--- Captures a screenshot of the primary screen as base64
---
--- Parameters:
---  * None
---
--- Returns:
---  * base64 - Base64 encoded image data (JPEG or PNG)
---  * screenInfo - Table with screen dimensions and scale factor
---  * mediaType - MIME type of the image (image/jpeg or image/png)
---
--- Notes:
---  * Automatically compresses to stay under Anthropic's API size limit
---  * Tries progressively lower JPEG quality, then resizes if needed
function module.captureScreen()
    local primary = screen.primaryScreen()
    local snapshot = primary:snapshot()

    if not snapshot then
        return nil, nil, nil, "Failed to capture screenshot"
    end

    -- Get screen info for coordinate calculations
    local screenInfo = coords.getScreenInfo()

    -- Compress image to stay under API size limit
    local base64, mediaType = compressImage(snapshot, screenInfo)

    return base64, screenInfo, mediaType
end

--- hs.claude.vision.captureScreenRaw() -> hs.image, table
--- Function
--- Captures a raw screenshot without base64 encoding
---
--- Parameters:
---  * None
---
--- Returns:
---  * snapshot - hs.image object
---  * screenInfo - Table with screen dimensions and scale factor
function module.captureScreenRaw()
    local primary = screen.primaryScreen()
    local snapshot = primary:snapshot()

    if not snapshot then
        return nil, nil, "Failed to capture screenshot"
    end

    local screenInfo = coords.getScreenInfo()
    return snapshot, screenInfo
end

--- hs.claude.vision.describeScreen(callback)
--- Function
--- Describes the current screen state (async)
---
--- Parameters:
---  * callback - Function called with (description, error)
---
--- Returns:
---  * None
function module.describeScreen(callback)
    local base64, screenInfo, mediaType, err = module.captureScreen()
    if err then
        callback(nil, err)
        return
    end

    api.messageWithImage({
        prompt = "Describe the current screen state. What app is open? What UI elements are visible?",
        system = prompts.SCREEN_OBSERVER,
        mediaType = mediaType
    }, base64, function(response, apiErr)
        if apiErr then
            callback(nil, apiErr)
        else
            callback(response.text, nil)
        end
    end)
end

--- hs.claude.vision.findElement(description, callback)
--- Function
--- Finds a UI element by description and returns its coordinates (async)
---
--- Parameters:
---  * description - Text description of the element to find
---  * callback - Function called with (coordinates, error)
---    * coordinates is a table with:
---      * logicalX, logicalY - For clicking
---      * screenshotX, screenshotY - In screenshot pixels
---      * normalizedX, normalizedY - In 0-1000 range
---
--- Returns:
---  * None
function module.findElement(description, callback)
    local base64, screenInfo, mediaType, err = module.captureScreen()
    if err then
        callback(nil, err)
        return
    end

    local prompt = string.format("Find this element: %s\nReturn its bounding box.", description)

    api.messageWithImage({
        prompt = prompt,
        system = prompts.ELEMENT_FINDER,
        mediaType = mediaType
    }, base64, function(response, apiErr)
        if apiErr then
            callback(nil, apiErr)
            return
        end

        -- Parse bounding box from response
        local bbox = coords.parseBoundingBox(response.text)
        if not bbox then
            callback(nil, "Element not found: " .. description)
            return
        end

        -- Convert to all coordinate formats
        local coordinates = coords.fromBoundingBox(bbox, screenInfo)

        -- Validate coordinates
        local valid, validErr = coords.validate(coordinates.logicalX, coordinates.logicalY, screenInfo)
        if not valid then
            callback(nil, validErr)
            return
        end

        callback(coordinates, nil)
    end)
end

--- hs.claude.vision.checkCondition(condition, callback)
--- Function
--- Checks if a condition is met on the current screen (async)
---
--- Parameters:
---  * condition - Text description of the condition to check
---  * callback - Function called with (boolean, error)
---
--- Returns:
---  * None
function module.checkCondition(condition, callback)
    local base64, screenInfo, mediaType, err = module.captureScreen()
    if err then
        callback(nil, err)
        return
    end

    local prompt = string.format("Answer YES or NO: %s\n\nRespond with ONLY \"YES\" or \"NO\", nothing else.", condition)

    api.messageWithImage({
        prompt = prompt,
        system = prompts.CONDITION_CHECKER,
        mediaType = mediaType
    }, base64, function(response, apiErr)
        if apiErr then
            callback(nil, apiErr)
            return
        end

        local answer = response.text:upper():gsub("%s+", "")
        callback(answer:find("YES") ~= nil, nil)
    end)
end

--- hs.claude.vision.extractInfo(query, callback)
--- Function
--- Extracts information from the current screen (async)
---
--- Parameters:
---  * query - Question about the screen content
---  * callback - Function called with (answer, error)
---
--- Returns:
---  * None
function module.extractInfo(query, callback)
    local base64, screenInfo, mediaType, err = module.captureScreen()
    if err then
        callback(nil, err)
        return
    end

    local prompt = string.format("Based on what you see on this screen, answer the following:\n\n%s", query)

    api.messageWithImage({
        prompt = prompt,
        system = prompts.SCREEN_OBSERVER,
        mediaType = mediaType
    }, base64, function(response, apiErr)
        if apiErr then
            callback(nil, apiErr)
        else
            callback(response.text, nil)
        end
    end)
end

--- hs.claude.vision.extractElements(elementType, callback)
--- Function
--- Extracts a list of elements of a specific type from the screen (async)
---
--- Parameters:
---  * elementType - Type of elements to find (e.g., "videos", "links", "buttons")
---  * callback - Function called with (elements, error)
---
--- Returns:
---  * None
function module.extractElements(elementType, callback)
    local base64, screenInfo, mediaType, err = module.captureScreen()
    if err then
        callback(nil, err)
        return
    end

    local prompt = string.format([[List all %s visible on this screen.

For each item, provide:
- title or text
- any numerical info (views, likes, etc.)
- approximate position (top/middle/bottom, left/center/right)

Format as a numbered list.]], elementType)

    api.messageWithImage({
        prompt = prompt,
        system = prompts.ELEMENT_EXTRACTOR,
        mediaType = mediaType
    }, base64, function(response, apiErr)
        if apiErr then
            callback(nil, apiErr)
        else
            callback({ raw_description = response.text }, nil)
        end
    end)
end

--- hs.claude.vision.getScreenInfo() -> table
--- Function
--- Gets information about the primary screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table with screen dimensions and scale factor
function module.getScreenInfo()
    return coords.getScreenInfo()
end

return module
