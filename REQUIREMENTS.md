# Hammerspoon AI Extension Requirements

## Overview

This document specifies the requirements for `hs.claude`, an AI-powered automation extension for Hammerspoon that enables natural language control of macOS using Claude's vision and language capabilities.

---

## Goals

1. **Natural Language Commands**: Execute macOS automation tasks via natural language
2. **Vision-Guided Actions**: Use Claude's vision API to understand screen state and find UI elements
3. **Agentic Loop**: Implement observe-think-act cycle for complex tasks
4. **Native Integration**: Leverage existing Hammerspoon APIs (mouse, keyboard, screen, application)
5. **Async Operation**: Non-blocking API calls with callbacks

---

## Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     hs.claude Extension                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Command ─────► Intent Parser ─────► Complexity Check      │
│                         (Claude)              │                 │
│                                               ▼                 │
│                     ┌─────────────────────────────────────┐     │
│                     │         Simple Task?                │     │
│                     └─────────────────────────────────────┘     │
│                              │              │                   │
│                            YES             NO                   │
│                              │              │                   │
│                              ▼              ▼                   │
│                     ┌──────────────┐ ┌────────────────────┐     │
│                     │  Sequential  │ │   Agentic Loop     │     │
│                     │  Execution   │ │  (Vision-guided)   │     │
│                     └──────────────┘ └────────────────────┘     │
│                              │              │                   │
│                              ▼              ▼                   │
│                     ┌─────────────────────────────────────┐     │
│                     │       Hammerspoon Native APIs       │     │
│                     │  (mouse, keyboard, screen, app)     │     │
│                     └─────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Agentic Loop Detail

```
┌─────────────────────────────────────────────────────────────┐
│                      AGENTIC LOOP                           │
│                                                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │ OBSERVE │ →  │  THINK  │ →  │   ACT   │ →  │  CHECK  │  │
│  │(Screen) │    │(Claude) │    │(Native) │    │(Success)│  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
│       ↑                                            │        │
│       └────────────────────────────────────────────┘        │
│                    (Loop until done)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Claude API Client (`hs.claude.api`)

**Purpose**: HTTP client for Claude API with vision support

**Functions**:
```lua
-- Configure API key
hs.claude.api.setApiKey(key)

-- Send message to Claude (async)
hs.claude.api.message(params, callback)
-- params: {
--   model = "claude-sonnet-4-20250514",
--   messages = { {role="user", content=...} },
--   max_tokens = 4096,
--   system = "optional system prompt"
-- }
-- callback: function(response, error)

-- Send message with image (async)
hs.claude.api.messageWithImage(params, imageBase64, callback)
```

**Implementation Notes**:
- Uses `hs.http.asyncPost` for non-blocking requests
- Handles JSON encoding/decoding
- Manages API errors gracefully

### 2. Screen Observer (`hs.claude.vision`)

**Purpose**: Capture and analyze screen state using Claude's vision

**Functions**:
```lua
-- Capture screenshot as base64
hs.claude.vision.captureScreen() -> base64String

-- Describe current screen state
hs.claude.vision.describeScreen(callback)
-- callback: function(description, error)

-- Find UI element by description, returns coordinates
hs.claude.vision.findElement(description, callback)
-- callback: function({x=number, y=number} or nil, error)

-- Check if condition is met on screen
hs.claude.vision.checkCondition(condition, callback)
-- callback: function(boolean, error)

-- Extract information from screen
hs.claude.vision.extractInfo(query, callback)
-- callback: function(answer, error)
```

**Implementation Notes**:
- Uses `hs.screen.primaryScreen():snapshot()` for capture
- Converts hs.image to base64 for Claude API
- Handles Retina scaling (screenshot pixels vs logical pixels)
- Normalizes coordinates (0-1000 range from Claude → actual pixels)

### 3. Action Registry (`hs.claude.actions`)

**Purpose**: Execute macOS automation actions

**Available Actions**:
```lua
-- Application control
hs.claude.actions.activateApp(appName) -> success, error
hs.claude.actions.quitApp(appName) -> success, error

-- URL handling
hs.claude.actions.openUrl(url, browser) -> success, error

-- Mouse actions
hs.claude.actions.click(x, y) -> success, error
hs.claude.actions.doubleClick(x, y) -> success, error
hs.claude.actions.rightClick(x, y) -> success, error
hs.claude.actions.moveTo(x, y) -> success, error
hs.claude.actions.scroll(direction, amount) -> success, error

-- Keyboard actions
hs.claude.actions.typeText(text) -> success, error
hs.claude.actions.pressKey(key, modifiers) -> success, error

-- Composite actions
hs.claude.actions.clickElement(description, callback)
-- Uses vision to find element, then clicks it
```

**Implementation Notes**:
- Wraps native Hammerspoon APIs
- Handles coordinate transformations
- Provides consistent error handling

### 4. Intent Parser (`hs.claude.parser`)

**Purpose**: Parse natural language commands into structured actions

**Functions**:
```lua
-- Parse command into intent
hs.claude.parser.parse(command, callback)
-- callback: function(intent, error)
-- intent: {
--   steps = { {action="...", params={...}}, ... },
--   requiresObservation = boolean,
--   goal = "original command"
-- }
```

**Output Schema**:
```lua
{
  steps = {
    { action = "activate_app", params = { appName = "Safari" } },
    { action = "open_url", params = { url = "https://youtube.com" } },
    { action = "click_element", params = { description = "search box" } },
    { action = "type_text", params = { text = "cooking videos" } },
    { action = "press_key", params = { key = "return" } }
  },
  requiresObservation = true,  -- needs vision for UI interaction
  goal = "Search YouTube for cooking videos"
}
```

### 5. Automation Agent (`hs.claude.agent`)

**Purpose**: Main agentic loop for complex task execution

**Functions**:
```lua
-- Execute a natural language command
hs.claude.agent.execute(command, callback)
-- callback: function(result, error)
-- result: {
--   success = boolean,
--   message = "completion message",
--   steps = { ... },  -- list of executed actions
--   iterations = number
-- }

-- Configure agent behavior
hs.claude.agent.configure(options)
-- options: {
--   maxIterations = 20,
--   actionDelay = 0.5,  -- seconds between actions
--   screenshotQuality = 0.8,
--   model = "claude-sonnet-4-20250514"
-- }
```

**Execution Modes**:
1. **Sequential**: For simple tasks without UI observation
2. **Agentic**: For complex tasks requiring vision feedback

---

## Coordinate System

### Screenshot vs Logical Coordinates

On Retina displays:
- **Screenshot pixels**: Full resolution (e.g., 3024 x 1964)
- **Logical pixels**: Display points (e.g., 1512 x 982)
- **Scale factor**: Typically 2x on Retina

### Coordinate Transformation

```lua
-- Claude returns normalized coordinates (0-1000)
-- Convert to screenshot pixels
function normalizedToScreenshot(nx, ny, screenWidth, screenHeight)
  return {
    x = math.floor(nx * screenWidth / 1000),
    y = math.floor(ny * screenHeight / 1000)
  }
end

-- Convert screenshot pixels to logical pixels for clicking
function screenshotToLogical(sx, sy, scaleFactor)
  return {
    x = math.floor(sx / scaleFactor),
    y = math.floor(sy / scaleFactor)
  }
end
```

---

## API Design

### Main Entry Point

```lua
-- Simple usage
hs.claude.execute("Open Safari and go to youtube.com", function(result)
  if result.success then
    print("Done!")
  else
    print("Error: " .. result.error)
  end
end)

-- With configuration
hs.claude.configure({
  apiKey = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-sonnet-4-20250514",
  maxIterations = 20
})
```

### Hotkey Integration

```lua
-- Bind to hotkey for quick access
hs.hotkey.bind({"cmd", "shift"}, "A", function()
  -- Show input dialog
  local button, text = hs.dialog.textPrompt("Claude Automation", "Enter command:", "", "Execute", "Cancel")
  if button == "Execute" then
    hs.claude.execute(text, function(result)
      hs.alert.show(result.success and "Done!" or "Failed: " .. result.message)
    end)
  end
end)
```

---

## Prompt Engineering

### Intent Parser System Prompt

```
You are a macOS automation intent parser. Convert user commands to structured JSON.

Available actions:
- activate_app: Launch or focus an application (params: appName)
- quit_app: Close an application (params: appName)
- open_url: Open URL in browser (params: url, browser)
- click_element: Click UI element by description (params: description)
- type_text: Type text (params: text)
- press_key: Press key/shortcut (params: key, modifiers)
- scroll: Scroll in direction (params: direction, amount)
- wait: Wait for condition (params: seconds or condition)

Rules:
1. Infer URLs from names (youtube → https://youtube.com)
2. Use exact app names (Chrome → Google Chrome)
3. Set requiresObservation=true if the task needs to see the screen
4. Break complex tasks into atomic steps

Output valid JSON only.
```

### Element Finder System Prompt

```
You are a UI element locator. Find the requested element and return its bounding box.

Return coordinates in this format:
<box>(x1,y1,x2,y2)</box>

Coordinates are normalized 0-1000 (top-left=0,0, bottom-right=1000,1000).

If element not found:
<box>NOT_FOUND</box>

Rules:
- Be precise - the box should tightly contain the element
- For buttons, include the full clickable area
- Return ONLY the box tag
```

### Agent Planner System Prompt

```
You are a macOS automation agent. Based on the goal and history, decide the next action.

If goal is achieved: {"complete": true, "reasoning": "..."}
Otherwise: {"action": "...", "params": {...}, "reasoning": "..."}

Available actions: activate_app, click_element, type_text, press_key, scroll, wait

Consider:
1. What is visible on screen?
2. What has been tried before?
3. What is the most direct path to the goal?
```

---

## Error Handling

### Error Types

1. **API Errors**: Network failures, authentication, rate limits
2. **Vision Errors**: Element not found, unclear screen state
3. **Action Errors**: App not found, permission denied
4. **Timeout Errors**: Max iterations reached, action timeout

### Error Response Format

```lua
{
  success = false,
  error = "Error type: Description",
  errorType = "api|vision|action|timeout",
  context = { ... }  -- additional debug info
}
```

---

## Configuration

### Default Configuration

```lua
hs.claude.defaults = {
  -- API settings
  model = "claude-sonnet-4-20250514",
  maxTokens = 4096,

  -- Agent settings
  maxIterations = 20,
  actionDelay = 0.5,  -- seconds

  -- Vision settings
  screenshotQuality = 0.8,
  maxImageSize = 1024 * 1024,  -- 1MB

  -- Coordinate settings
  normalizationRange = 1000,

  -- Logging
  logLevel = "info"  -- debug, info, warn, error
}
```

### User Configuration

Store API key securely:
```lua
-- In ~/.hammerspoon/init.lua
hs.claude.configure({
  apiKey = hs.settings.get("claude_api_key") or os.getenv("ANTHROPIC_API_KEY")
})
```

---

## File Structure

```
extensions/claude/
├── claude.lua           # Main module, exports hs.claude
├── api.lua              # Claude API client
├── vision.lua           # Screen capture and analysis
├── actions.lua          # Action implementations
├── parser.lua           # Intent parsing
├── agent.lua            # Agentic loop
├── coordinates.lua      # Coordinate transformations
├── prompts.lua          # System prompts
└── test_claude.lua      # Test suite
```

---

## Dependencies

Uses existing Hammerspoon modules:
- `hs.http` - HTTP requests
- `hs.screen` - Screen capture
- `hs.image` - Image handling
- `hs.mouse` - Mouse control
- `hs.eventtap` - Keyboard/mouse events
- `hs.application` - Application control
- `hs.timer` - Delays and scheduling
- `hs.json` - JSON encoding/decoding
- `hs.alert` - User notifications
- `hs.dialog` - User input dialogs

---

## Example Usage

### Simple Command

```lua
hs.claude.execute("Open Safari", function(result)
  print(result.success and "Safari opened" or result.error)
end)
```

### Complex Task

```lua
hs.claude.execute(
  "Search YouTube for cooking tutorials and click on the most popular video",
  function(result)
    print("Completed in " .. result.iterations .. " iterations")
    for i, step in ipairs(result.steps) do
      print(i .. ". " .. step.action .. ": " .. (step.success and "OK" or step.error))
    end
  end
)
```

### With Vision Query

```lua
hs.claude.vision.describeScreen(function(description)
  print("Current screen: " .. description)
end)

hs.claude.vision.findElement("the red Subscribe button", function(coords)
  if coords then
    print("Found at: " .. coords.x .. ", " .. coords.y)
    hs.claude.actions.click(coords.x, coords.y)
  end
end)
```

---

## Security Considerations

1. **API Key Storage**: Never hardcode; use `hs.settings` or environment variables
2. **Action Confirmation**: Optionally prompt user before destructive actions
3. **Rate Limiting**: Implement backoff for API calls
4. **Scope Limitation**: Allow configuring which apps/actions are permitted

---

## Testing Strategy

1. **Unit Tests**: Test each module in isolation
2. **Integration Tests**: Test complete workflows
3. **Mock API**: Test without actual Claude API calls
4. **Visual Verification**: Manual testing of click accuracy

---

## Future Enhancements

1. **Accessibility API Integration**: Use `hs.axuielement` for more reliable element finding
2. **Recording/Playback**: Record user actions and replay
3. **Multi-Screen Support**: Handle multiple monitors
4. **Custom Spoon**: Package as distributable Spoon
5. **Voice Control**: Integrate with macOS dictation
