#!/bin/bash
# Install hs.claude extension for development
# This script copies files to ~/.hammerspoon for use without rebuilding Hammerspoon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HS_DIR="${HOME}/.hammerspoon"
HS_EXT_DIR="${HS_DIR}/hs"

echo "Installing hs.claude extension to ${HS_EXT_DIR}..."

# Create directory if needed
mkdir -p "${HS_EXT_DIR}"

# Copy all lua files
cp "${SCRIPT_DIR}/claude.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_api.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_vision.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_actions.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_parser.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_agent.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_prompts.lua" "${HS_EXT_DIR}/"
cp "${SCRIPT_DIR}/claude_coordinates.lua" "${HS_EXT_DIR}/"

echo "Files copied successfully."
echo ""
echo "Add the following to your ~/.hammerspoon/init.lua:"
echo ""
cat << 'EOF'
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

-- Optional: Add hotkey
hs.hotkey.bind({"cmd", "shift"}, "A", function()
    local button, text = hs.dialog.textPrompt("Claude", "Command:", "", "Run", "Cancel")
    if button == "Run" and text ~= "" then
        hs.alert.show("Executing...")
        hs.claude.execute(text, function(result)
            hs.alert.show(result.success and "Done!" or result.message)
        end)
    end
end)
EOF
echo ""
echo "Then reload Hammerspoon config (Cmd+Shift+R in console)"
