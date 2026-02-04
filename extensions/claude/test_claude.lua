-- Test suite for hs.claude extension

-- Mock dependencies for testing
local function mockModule(name)
    return setmetatable({}, {
        __index = function(t, k)
            return function(...) return true end
        end
    })
end

-- Test coordinates module
local function testCoordinates()
    local coords = require("hs.claude.coordinates")

    -- Test screen info structure
    local screenInfo = {
        width = 1512,
        height = 982,
        scaleFactor = 2,
        screenshotWidth = 3024,
        screenshotHeight = 1964
    }

    -- Test normalized to screenshot conversion
    local screenshot = coords.normalizedToScreenshot(500, 500, screenInfo)
    assert(screenshot.x == 1512, "normalizedToScreenshot X failed")
    assert(screenshot.y == 982, "normalizedToScreenshot Y failed")

    -- Test screenshot to logical conversion
    local logical = coords.screenshotToLogical(1512, 982, screenInfo)
    assert(logical.x == 756, "screenshotToLogical X failed")
    assert(logical.y == 491, "screenshotToLogical Y failed")

    -- Test normalized to logical conversion
    local direct = coords.normalizedToLogical(500, 500, screenInfo)
    assert(direct.x == 756, "normalizedToLogical X failed")
    assert(direct.y == 491, "normalizedToLogical Y failed")

    -- Test bounding box center
    local center = coords.boundingBoxToCenter(100, 100, 200, 200)
    assert(center.x == 150, "boundingBoxToCenter X failed")
    assert(center.y == 150, "boundingBoxToCenter Y failed")

    -- Test bounding box parsing
    local bbox1 = coords.parseBoundingBox("<box>(100,200,300,400)</box>")
    assert(bbox1.x1 == 100, "parseBoundingBox x1 failed")
    assert(bbox1.y1 == 200, "parseBoundingBox y1 failed")
    assert(bbox1.x2 == 300, "parseBoundingBox x2 failed")
    assert(bbox1.y2 == 400, "parseBoundingBox y2 failed")

    local bbox2 = coords.parseBoundingBox("<box>NOT_FOUND</box>")
    assert(bbox2 == nil, "parseBoundingBox NOT_FOUND should return nil")

    local bbox3 = coords.parseBoundingBox("some text")
    assert(bbox3 == nil, "parseBoundingBox invalid should return nil")

    -- Test coordinate validation
    local valid1, err1 = coords.validate(756, 491, screenInfo)
    assert(valid1 == true, "validate valid coords failed")
    assert(err1 == nil, "validate valid coords should have no error")

    local valid2, err2 = coords.validate(-10, 491, screenInfo)
    assert(valid2 == false, "validate invalid X should fail")
    assert(err2 ~= nil, "validate invalid X should have error")

    local valid3, err3 = coords.validate(756, 2000, screenInfo)
    assert(valid3 == false, "validate invalid Y should fail")
    assert(err3 ~= nil, "validate invalid Y should have error")

    print("All coordinate tests passed!")
    return true
end

-- Test parser module
local function testParser()
    local parser = require("hs.claude.parser")

    -- Test JSON extraction
    local json1 = parser.extractJson('{"key": "value"}')
    assert(json1 == '{"key": "value"}', "extractJson simple failed")

    local json2 = parser.extractJson('Some text {"key": "value"} more text')
    assert(json2 == '{"key": "value"}', "extractJson embedded failed")

    local json3 = parser.extractJson('```json\n{"key": "value"}\n```')
    assert(json3 == '{"key": "value"}', "extractJson markdown failed")

    local json4 = parser.extractJson("no json here")
    assert(json4 == nil, "extractJson no json should return nil")

    -- Test action normalization
    assert(parser.normalizeAction("activate") == "activate_app", "normalizeAction activate failed")
    assert(parser.normalizeAction("launch") == "activate_app", "normalizeAction launch failed")
    assert(parser.normalizeAction("quit") == "quit_app", "normalizeAction quit failed")
    assert(parser.normalizeAction("open") == "open_url", "normalizeAction open failed")
    assert(parser.normalizeAction("click") == "click_element", "normalizeAction click failed")
    assert(parser.normalizeAction("type") == "type_text", "normalizeAction type failed")
    assert(parser.normalizeAction("unknown") == "unknown", "normalizeAction unknown failed")

    -- Test intent validation
    local valid1, err1 = parser.validateIntent({ steps = {} })
    assert(valid1 == true, "validateIntent empty steps failed")

    local valid2, err2 = parser.validateIntent({ steps = {{ action = "test", params = {} }} })
    assert(valid2 == true, "validateIntent valid step failed")

    local valid3, err3 = parser.validateIntent(nil)
    assert(valid3 == false, "validateIntent nil should fail")

    local valid4, err4 = parser.validateIntent({ steps = {{ params = {} }} })
    assert(valid4 == false, "validateIntent missing action should fail")

    print("All parser tests passed!")
    return true
end

-- Test prompts module
local function testPrompts()
    local prompts = require("hs.claude.prompts")

    assert(prompts.INTENT_PARSER ~= nil, "INTENT_PARSER prompt missing")
    assert(type(prompts.INTENT_PARSER) == "string", "INTENT_PARSER should be string")
    assert(#prompts.INTENT_PARSER > 100, "INTENT_PARSER seems too short")

    assert(prompts.ELEMENT_FINDER ~= nil, "ELEMENT_FINDER prompt missing")
    assert(prompts.SCREEN_OBSERVER ~= nil, "SCREEN_OBSERVER prompt missing")
    assert(prompts.AGENT_PLANNER ~= nil, "AGENT_PLANNER prompt missing")
    assert(prompts.CONDITION_CHECKER ~= nil, "CONDITION_CHECKER prompt missing")

    print("All prompts tests passed!")
    return true
end

-- Run all tests
local function runAllTests()
    print("Running hs.claude test suite...")
    print("")

    local allPassed = true

    local ok, err = pcall(testCoordinates)
    if not ok then
        print("Coordinate tests FAILED: " .. tostring(err))
        allPassed = false
    end

    ok, err = pcall(testParser)
    if not ok then
        print("Parser tests FAILED: " .. tostring(err))
        allPassed = false
    end

    ok, err = pcall(testPrompts)
    if not ok then
        print("Prompts tests FAILED: " .. tostring(err))
        allPassed = false
    end

    print("")
    if allPassed then
        print("All tests PASSED!")
    else
        print("Some tests FAILED!")
    end

    return allPassed
end

-- Export for Hammerspoon test runner
return {
    testCoordinates = testCoordinates,
    testParser = testParser,
    testPrompts = testPrompts,
    runAllTests = runAllTests
}
