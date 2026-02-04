--- === hs.claude.coordinates ===
---
--- Coordinate transformation utilities for Retina displays
---
--- Handles conversion between:
--- - Normalized coordinates (0-1000) from Claude vision
--- - Screenshot pixels (full Retina resolution)
--- - Logical pixels (display points for mouse/click actions)

local module = {}

--- hs.claude.coordinates.NORMALIZATION_RANGE
--- Constant
--- The range used for normalized coordinates (0 to this value)
module.NORMALIZATION_RANGE = 1000

--- hs.claude.coordinates.getScreenInfo() -> table
--- Function
--- Gets information about the primary screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table with screen information:
---    * width - logical width in points
---    * height - logical height in points
---    * scaleFactor - Retina scale factor (usually 2 on Retina)
---    * screenshotWidth - actual screenshot width in pixels
---    * screenshotHeight - actual screenshot height in pixels
function module.getScreenInfo()
    local screen = require("hs.screen")
    local primary = screen.primaryScreen()
    local frame = primary:fullFrame()
    local mode = primary:currentMode()

    -- Scale factor is the ratio of screenshot pixels to logical points
    local scaleFactor = mode.scale or 2

    return {
        width = frame.w,
        height = frame.h,
        scaleFactor = scaleFactor,
        screenshotWidth = math.floor(frame.w * scaleFactor),
        screenshotHeight = math.floor(frame.h * scaleFactor)
    }
end

--- hs.claude.coordinates.normalizedToScreenshot(nx, ny, screenInfo) -> table
--- Function
--- Converts normalized coordinates (0-1000) to screenshot pixel coordinates
---
--- Parameters:
---  * nx - normalized X coordinate (0-1000)
---  * ny - normalized Y coordinate (0-1000)
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * A table with x and y screenshot pixel coordinates
function module.normalizedToScreenshot(nx, ny, screenInfo)
    return {
        x = math.floor(nx * screenInfo.screenshotWidth / module.NORMALIZATION_RANGE),
        y = math.floor(ny * screenInfo.screenshotHeight / module.NORMALIZATION_RANGE)
    }
end

--- hs.claude.coordinates.screenshotToLogical(sx, sy, screenInfo) -> table
--- Function
--- Converts screenshot pixel coordinates to logical coordinates for clicking
---
--- Parameters:
---  * sx - screenshot X coordinate
---  * sy - screenshot Y coordinate
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * A table with x and y logical coordinates
function module.screenshotToLogical(sx, sy, screenInfo)
    return {
        x = math.floor(sx / screenInfo.scaleFactor),
        y = math.floor(sy / screenInfo.scaleFactor)
    }
end

--- hs.claude.coordinates.normalizedToLogical(nx, ny, screenInfo) -> table
--- Function
--- Converts normalized coordinates directly to logical coordinates
---
--- Parameters:
---  * nx - normalized X coordinate (0-1000)
---  * ny - normalized Y coordinate (0-1000)
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * A table with x and y logical coordinates
function module.normalizedToLogical(nx, ny, screenInfo)
    local screenshot = module.normalizedToScreenshot(nx, ny, screenInfo)
    return module.screenshotToLogical(screenshot.x, screenshot.y, screenInfo)
end

--- hs.claude.coordinates.logicalToNormalized(lx, ly, screenInfo) -> table
--- Function
--- Converts logical coordinates to normalized coordinates
---
--- Parameters:
---  * lx - logical X coordinate
---  * ly - logical Y coordinate
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * A table with x and y normalized coordinates (0-1000)
function module.logicalToNormalized(lx, ly, screenInfo)
    return {
        x = math.floor(lx * module.NORMALIZATION_RANGE / screenInfo.width),
        y = math.floor(ly * module.NORMALIZATION_RANGE / screenInfo.height)
    }
end

--- hs.claude.coordinates.boundingBoxToCenter(x1, y1, x2, y2) -> table
--- Function
--- Gets the center point of a bounding box
---
--- Parameters:
---  * x1 - left coordinate
---  * y1 - top coordinate
---  * x2 - right coordinate
---  * y2 - bottom coordinate
---
--- Returns:
---  * A table with x and y center coordinates
function module.boundingBoxToCenter(x1, y1, x2, y2)
    return {
        x = math.floor((x1 + x2) / 2),
        y = math.floor((y1 + y2) / 2)
    }
end

--- hs.claude.coordinates.parseBoundingBox(response) -> table or nil
--- Function
--- Parses a bounding box from Claude's response
---
--- Parameters:
---  * response - string response from Claude containing <box>(x1,y1,x2,y2)</box>
---
--- Returns:
---  * A table with x1, y1, x2, y2 coordinates, or nil if not found/invalid
function module.parseBoundingBox(response)
    if not response then return nil end

    -- Check for NOT_FOUND
    if response:find("NOT_FOUND") then
        return nil
    end

    -- Parse <box>(x1,y1,x2,y2)</box>
    local x1, y1, x2, y2 = response:match("<box>%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)%s*</box>")

    if x1 and y1 and x2 and y2 then
        return {
            x1 = tonumber(x1),
            y1 = tonumber(y1),
            x2 = tonumber(x2),
            y2 = tonumber(y2)
        }
    end

    return nil
end

--- hs.claude.coordinates.fromBoundingBox(bbox, screenInfo) -> table
--- Function
--- Converts a normalized bounding box to click coordinates
---
--- Parameters:
---  * bbox - table with x1, y1, x2, y2 in normalized coordinates
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * A table with:
---    * normalizedX, normalizedY - center in normalized coords
---    * screenshotX, screenshotY - center in screenshot pixels
---    * logicalX, logicalY - center in logical coords (for clicking)
function module.fromBoundingBox(bbox, screenInfo)
    -- Get center of bounding box in normalized coords
    local center = module.boundingBoxToCenter(bbox.x1, bbox.y1, bbox.x2, bbox.y2)

    -- Convert to screenshot pixels
    local screenshot = module.normalizedToScreenshot(center.x, center.y, screenInfo)

    -- Convert to logical pixels for clicking
    local logical = module.screenshotToLogical(screenshot.x, screenshot.y, screenInfo)

    return {
        normalizedX = center.x,
        normalizedY = center.y,
        screenshotX = screenshot.x,
        screenshotY = screenshot.y,
        logicalX = logical.x,
        logicalY = logical.y
    }
end

--- hs.claude.coordinates.validate(x, y, screenInfo) -> boolean, string
--- Function
--- Validates that coordinates are within screen bounds
---
--- Parameters:
---  * x - logical X coordinate
---  * y - logical Y coordinate
---  * screenInfo - table from getScreenInfo()
---
--- Returns:
---  * boolean - true if valid
---  * string - error message if invalid, nil otherwise
function module.validate(x, y, screenInfo)
    if x < 0 or x > screenInfo.width then
        return false, string.format("X coordinate %d out of bounds (0-%d)", x, screenInfo.width)
    end
    if y < 0 or y > screenInfo.height then
        return false, string.format("Y coordinate %d out of bounds (0-%d)", y, screenInfo.height)
    end
    return true, nil
end

return module
