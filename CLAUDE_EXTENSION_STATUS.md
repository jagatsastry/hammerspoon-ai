# hs.claude Extension - Current Status

## Overview

The `hs.claude` Hammerspoon extension has been fully adapted from the Python `macos-automation-agent` project. All core functionalities have been ported to Lua.

## Completed Work

### Files Created/Updated

| File | Purpose | Status |
|------|---------|--------|
| `extensions/claude/claude.lua` | Main module entry point | Complete |
| `extensions/claude/claude_api.lua` | Claude API client with vision support | Complete |
| `extensions/claude/claude_vision.lua` | Screen capture + compression + analysis | Complete |
| `extensions/claude/claude_actions.lua` | Native automation actions (click, type, etc.) | Complete |
| `extensions/claude/claude_parser.lua` | Intent parsing + complexity classification | Complete |
| `extensions/claude/claude_agent.lua` | Agentic loop (observe → think → act) | Complete |
| `extensions/claude/claude_prompts.lua` | System prompts for LLM | Complete |
| `extensions/claude/claude_coordinates.lua` | Retina coordinate transformations | Complete |
| `extensions/claude/install.sh` | Development installation script | Complete |
| `extensions/claude/test_claude.lua` | Unit tests | Complete |
| `extensions/claude/README.md` | Documentation | Complete |

### Features Ported from Python Project

1. **Image Compression** (`claude_vision.lua`)
   - Progressive JPEG quality reduction (85 → 70 → 55 → 40 → 30)
   - Automatic resize fallback if still too large
   - Stays under Anthropic's 5MB API limit

2. **Media Type Detection** (`claude_api.lua`)
   - Auto-detects image format from base64 data (JPEG, PNG, GIF, WebP)
   - Passes correct `media_type` to Claude API

3. **Complexity Classification** (`claude_parser.lua`)
   - `classifyComplexity()` - Quick heuristic to determine if task needs vision
   - `normalizeAppName()` - Maps user-friendly names to macOS app names
   - `normalizeUrl()` - Converts partial URLs/site names to full URLs

4. **Comprehensive Search URL Patterns** (`claude_prompts.lua`)
   - YouTube, Google, GitHub, Reddit, Amazon, Wikipedia search
   - Google Flights, Hotels, Maps, Shopping, News, Images
   - OpenTable, Fandango, Ticketmaster for bookings

5. **Action Library** (`claude_actions.lua`)
   - `activateApp`, `quitApp`, `openUrl`
   - `click`, `doubleClick`, `rightClick`, `moveTo`
   - `typeText`, `pressKey`, `scroll`
   - `selectAll`, `copy`, `paste`, `cut`, `undo`, `clearField`
   - `getFrontmostApp`, `isAppRunning`
   - AppleScript variants for reliability

6. **Agentic Loop** (`claude_agent.lua`)
   - Observe → Think → Act → Check cycle
   - Max 35 iterations
   - History tracking for context
   - Sequential execution for simple tasks

## Installation

Files have been copied to `~/.hammerspoon/hs/` via `install.sh`.

### Required init.lua Configuration

```lua
-- hs.claude extension setup
local preload = function(m) return function() return require(m) end end
package.preload['hs.claude.api']         = preload 'hs.claude_api'
package.preload['hs.claude.vision']      = preload 'hs.claude_vision'
package.preload['hs.claude.actions']     = preload 'hs.claude_actions'
package.preload['hs.claude.parser']      = preload 'hs.claude_parser'
package.preload['hs.claude.agent']       = preload 'hs.claude_agent'
package.preload['hs.claude.prompts']     = preload 'hs.claude_prompts'
package.preload['hs.claude.coordinates'] = preload 'hs.claude_coordinates'

-- Configure Claude
hs.claude = require("hs.claude")
hs.claude.configure({
    apiKey = os.getenv("ANTHROPIC_API_KEY")
})
```

## What Was Being Attempted

**Testing the extension** - I was trying to:
1. Check if Hammerspoon CLI (`hs`) is available - **Not found**
2. Check if Hammerspoon.app is installed - **Not installed**
3. Check for Lua interpreter to run tests - **Not installed**
4. Install Lua via Homebrew to validate syntax - **Interrupted**

## Next Steps to Test

### Option 1: Build Hammerspoon from Source
```bash
cd /Users/jagatp/workspace/hammerspoon-ai
pod install
open Hammerspoon.xcodeproj
# Build with Cmd+B in Xcode
```

### Option 2: Install Hammerspoon Release
```bash
brew install --cask hammerspoon
```

### Option 3: Install Lua for Syntax Validation
```bash
brew install lua
cd /Users/jagatp/workspace/hammerspoon-ai/extensions/claude
lua -e "dofile('test_claude.lua').runAllTests()"
```

### Option 4: Test in Hammerspoon Console
After Hammerspoon is running:
1. Open Hammerspoon Console
2. Run: `hs.claude.configure({ apiKey = os.getenv("ANTHROPIC_API_KEY") })`
3. Run: `hs.claude.execute("Open Safari", function(r) print(r.success) end)`

## API Usage Examples

```lua
-- Simple command (no vision)
hs.claude.execute("Open Safari", function(result)
    print(result.success)
end)

-- Complex command (uses vision)
hs.claude.execute("Search YouTube for cooking tutorials and click the most popular video", function(result)
    print(result.message)
    print("Iterations:", result.iterations)
end)

-- Describe current screen
hs.claude.describe(function(description, err)
    print(description)
end)

-- Find and click element
hs.claude.click("the red Subscribe button", function(success, err)
    print("Clicked:", success)
end)

-- Ask question about screen
hs.claude.ask("What video is playing?", function(answer, err)
    print(answer)
end)

-- Check condition
hs.claude.check("Is Safari open?", function(result, err)
    print("Safari open:", result)
end)
```

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
- Hammerspoon (this fork or official)
- Anthropic API key (`ANTHROPIC_API_KEY` environment variable)
- Accessibility permissions for Hammerspoon
