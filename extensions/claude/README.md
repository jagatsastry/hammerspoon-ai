# hs.claude - AI-Powered macOS Automation

This Hammerspoon extension enables natural language control of macOS using Claude's vision and language capabilities.

## Features

- **Natural Language Commands**: Execute tasks like "Open Safari and go to YouTube"
- **Vision-Guided Actions**: Find and click UI elements by description
- **Agentic Loop**: Automatically observe, plan, and act for complex tasks
- **Async API**: Non-blocking operations with callbacks

## Installation

### For Development (Without Rebuilding Hammerspoon)

1. Copy the claude extension files to your Hammerspoon config:

```bash
mkdir -p ~/.hammerspoon/hs/
cp extensions/claude/claude.lua ~/.hammerspoon/hs/claude.lua
cp extensions/claude/claude_*.lua ~/.hammerspoon/hs/
```

2. Add preloads to your `~/.hammerspoon/init.lua`:

```lua
-- Add Claude submodule preloads
local preload = function(m) return function() return require(m) end end
package.preload['hs.claude.api']         = preload 'hs.claude_api'
package.preload['hs.claude.vision']      = preload 'hs.claude_vision'
package.preload['hs.claude.actions']     = preload 'hs.claude_actions'
package.preload['hs.claude.parser']      = preload 'hs.claude_parser'
package.preload['hs.claude.agent']       = preload 'hs.claude_agent'
package.preload['hs.claude.prompts']     = preload 'hs.claude_prompts'
package.preload['hs.claude.coordinates'] = preload 'hs.claude_coordinates'

-- Now configure Claude
hs.claude = require("hs.claude")
hs.claude.configure({
    apiKey = os.getenv("ANTHROPIC_API_KEY")
})
```

### For Building into Hammerspoon

1. Open `Hammerspoon.xcodeproj` in Xcode

2. In the Project Navigator, expand **extensions** group

3. Right-click **extensions** → **New Group** → Name it `claude`

4. Right-click the new `claude` group → **Add Files to "Hammerspoon"...**
   - Select all `*.lua` files from `extensions/claude/`
   - **Uncheck** "Copy items if needed"
   - **Uncheck** "Hammerspoon" target (files are added to build phase, not compiled)
   - Click **Add**

5. Select the **Hammerspoon** target → **Build Phases**

6. Expand **Copy Extension Lua files**

7. Click **+** and add all the claude `.lua` files

8. Build the project (Cmd+B)

## Quick Start

```lua
-- Configure with your API key
hs.claude.configure({
    apiKey = os.getenv("ANTHROPIC_API_KEY")
})

-- Execute a simple command
hs.claude.execute("Open Safari", function(result)
    if result.success then
        hs.alert.show("Done!")
    else
        hs.alert.show("Error: " .. result.message)
    end
end)
```

## API Reference

### Configuration

```lua
hs.claude.configure({
    apiKey = "your-api-key",           -- Required
    model = "claude-sonnet-4-20250514", -- Optional
    maxIterations = 20,                 -- Max agentic loop iterations
    actionDelay = 0.5,                  -- Seconds between actions
    screenshotQuality = 0.8             -- Screenshot quality 0-1
})
```

### Main Functions

#### `hs.claude.execute(command, callback)`
Execute a natural language command.

```lua
hs.claude.execute("Search YouTube for cooking tutorials", function(result)
    print("Success:", result.success)
    print("Message:", result.message)
    print("Iterations:", result.iterations)
    for i, step in ipairs(result.steps) do
        print(i, step.action, step.success)
    end
end)
```

#### `hs.claude.describe(callback)`
Describe the current screen state.

```lua
hs.claude.describe(function(description, err)
    print(description)
end)
```

#### `hs.claude.findElement(description, callback)`
Find a UI element and get its coordinates.

```lua
hs.claude.findElement("the search button", function(coords, err)
    if coords then
        print("Found at:", coords.logicalX, coords.logicalY)
    end
end)
```

#### `hs.claude.click(description, callback)`
Find and click a UI element.

```lua
hs.claude.click("the red Subscribe button", function(success, err)
    print("Clicked:", success)
end)
```

#### `hs.claude.ask(question, callback)`
Ask a question about the current screen.

```lua
hs.claude.ask("What video is playing?", function(answer, err)
    print(answer)
end)
```

#### `hs.claude.check(condition, callback)`
Check if a condition is true on screen.

```lua
hs.claude.check("Is Safari open?", function(result, err)
    print("Safari is open:", result)
end)
```

### Submodules

- `hs.claude.api` - Direct Claude API access
- `hs.claude.vision` - Screen capture and analysis
- `hs.claude.actions` - Low-level automation actions
- `hs.claude.parser` - Intent parsing
- `hs.claude.agent` - Agentic loop engine
- `hs.claude.coordinates` - Coordinate transformations
- `hs.claude.prompts` - System prompts

## Hotkey Integration

Add a hotkey to trigger Claude commands:

```lua
hs.hotkey.bind({"cmd", "shift"}, "A", function()
    local button, text = hs.dialog.textPrompt(
        "Claude Automation",
        "Enter command:",
        "",
        "Execute",
        "Cancel"
    )
    if button == "Execute" and text ~= "" then
        hs.alert.show("Executing: " .. text)
        hs.claude.execute(text, function(result)
            if result.success then
                hs.alert.show("Done!")
            else
                hs.alert.show("Failed: " .. result.message)
            end
        end)
    end
end)
```

## Example Commands

Simple (no vision needed):
- "Open Safari"
- "Open YouTube in Chrome"
- "Quit Finder"

Complex (uses vision):
- "Search YouTube for cooking tutorials"
- "Click the Subscribe button"
- "Book a table for 2 at Joey's restaurant"

## Architecture

```
User Command
    │
    ▼
Intent Parser (Claude)
    │
    ├─ Simple Task ───► Sequential Execution
    │
    └─ Complex Task ──► Agentic Loop
                           │
                           ▼
                    ┌──────────────┐
                    │   OBSERVE    │ ◄─┐
                    │  (Screenshot)│   │
                    └──────┬───────┘   │
                           │           │
                           ▼           │
                    ┌──────────────┐   │
                    │    THINK     │   │
                    │   (Claude)   │   │
                    └──────┬───────┘   │
                           │           │
                           ▼           │
                    ┌──────────────┐   │
                    │     ACT      │   │
                    │   (Native)   │   │
                    └──────┬───────┘   │
                           │           │
                           ▼           │
                    ┌──────────────┐   │
                    │    CHECK     │───┘
                    │  (Complete?) │
                    └──────────────┘
```

## Requirements

- macOS 13.0+
- Hammerspoon (this fork)
- Anthropic API key
- Accessibility permissions for Hammerspoon

## Troubleshooting

### "API key not configured"
Make sure to call `hs.claude.configure()` with your API key before using other functions.

### Element not found
- Ensure the element is visible on screen
- Try more specific descriptions
- Check that accessibility is enabled for Hammerspoon

### Clicks not working
- Hammerspoon needs Accessibility permissions
- Check System Preferences → Privacy & Security → Accessibility
- Grant permission to Hammerspoon

### Slow responses
- Claude API calls take 1-5 seconds typically
- Vision calls with screenshots take longer
- Agentic loops make multiple API calls

## License

MIT License - See LICENSE file
