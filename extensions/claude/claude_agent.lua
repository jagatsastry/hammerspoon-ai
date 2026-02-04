--- === hs.claude.agent ===
---
--- Agentic loop for complex task execution
---
--- Implements the observe-think-act cycle for tasks that require
--- visual feedback and adaptive decision making.

local json = require("hs.json")
local timer = require("hs.timer")

local api = require("hs.claude.api")
local prompts = require("hs.claude.prompts")
local vision = require("hs.claude.vision")
local actions = require("hs.claude.actions")
local parser = require("hs.claude.parser")

local module = {}

-- Private state
local config = {
    maxIterations = 35,      -- Maximum agentic loop iterations (increased for complex tasks)
    actionDelay = 0.5,       -- seconds between actions
    observationDelay = 0.5,  -- seconds to wait before observing (for UI to settle)
    maxRetries = 3,          -- max retries for failed actions
    historyLimit = 10        -- number of history entries to include in prompts
}

--- hs.claude.agent.configure(options)
--- Function
--- Configure agent settings
---
--- Parameters:
---  * options - A table with:
---    * maxIterations - Maximum agentic loop iterations (default: 20)
---    * actionDelay - Delay between actions in seconds (default: 0.5)
---    * observationDelay - Delay before observing in seconds (default: 0.3)
---
--- Returns:
---  * None
function module.configure(options)
    if options.maxIterations then config.maxIterations = options.maxIterations end
    if options.actionDelay then config.actionDelay = options.actionDelay end
    if options.observationDelay then config.observationDelay = options.observationDelay end
end

-- Internal: Format history for LLM
local function formatHistory(history)
    if #history == 0 then
        return "(No history yet)"
    end

    local lines = {}
    local start = math.max(1, #history - 9)  -- Keep last 10 entries

    for i = start, #history do
        local entry = history[i]
        local prefix = entry.type == "observation" and "OBSERVED" or "ACTION"
        table.insert(lines, string.format("%d. [%s] %s", i, prefix, entry.content))
    end

    return table.concat(lines, "\n")
end

-- Internal: Plan next action using Claude
local function planNextAction(goal, history, callback)
    local historyText = formatHistory(history)

    local prompt = string.format([[Goal: %s

History:
%s

Based on the current screen state and goal, what is the next action?
If the goal is achieved, respond with {"complete": true, "reasoning": "..."}
Otherwise respond with the next action.]], goal, historyText)

    api.message({
        messages = {
            { role = "user", content = prompt }
        },
        system = prompts.AGENT_PLANNER
    }, function(response, err)
        if err then
            callback(nil, err)
            return
        end

        -- Extract JSON from response
        local jsonStr = parser.extractJson(response.text)
        if not jsonStr then
            callback({
                action = "",
                params = {},
                reasoning = "Could not parse LLM response",
                isComplete = false
            }, nil)
            return
        end

        local ok, data = pcall(json.decode, jsonStr)
        if not ok then
            callback({
                action = "",
                params = {},
                reasoning = "JSON parse error",
                isComplete = false
            }, nil)
            return
        end

        if data.complete then
            callback({
                action = "",
                params = {},
                reasoning = data.reasoning or "Goal completed",
                isComplete = true
            }, nil)
        else
            callback({
                action = data.action or "",
                params = data.params or {},
                reasoning = data.reasoning or "",
                isComplete = false
            }, nil)
        end
    end)
end

-- Internal: Execute a single action
local function executeAction(action, params, callback)
    -- Handle click_element specially - requires vision
    if action == "click_element" then
        local description = params.description
        if not description then
            callback({ success = false, error = "No element description provided" })
            return
        end

        vision.findElement(description, function(coords, err)
            if err then
                callback({ success = false, error = err, action = action, params = params })
                return
            end

            local success, actionErr = actions.click(coords.logicalX, coords.logicalY)
            callback({
                success = success,
                error = actionErr,
                action = action,
                params = {
                    description = description,
                    x = coords.logicalX,
                    y = coords.logicalY
                }
            })
        end)
    else
        -- Direct action execution
        local success, err = actions.execute(action, params)
        callback({
            success = success,
            error = err,
            action = action,
            params = params
        })
    end
end

-- Internal: Execute sequential steps
local function executeSequential(steps, callback)
    local results = {}
    local index = 1

    local function executeNext()
        if index > #steps then
            callback({
                success = true,
                message = "All steps completed successfully",
                steps = results,
                iterations = 1
            })
            return
        end

        local step = steps[index]
        executeAction(step.action, step.params, function(result)
            table.insert(results, result)

            if not result.success then
                callback({
                    success = false,
                    message = string.format("Failed at step: %s", step.action),
                    steps = results,
                    iterations = 1,
                    error = result.error
                })
                return
            end

            index = index + 1

            -- Delay between actions
            timer.doAfter(config.actionDelay, executeNext)
        end)
    end

    executeNext()
end

-- Internal: Execute agentic loop
local function executeAgentic(goal, initialSteps, callback)
    local history = {}
    local results = {}
    local iteration = 0

    -- Execute initial non-observation steps first
    local function executeInitialSteps(stepIndex)
        if stepIndex > #initialSteps then
            -- Start agentic loop
            agenticLoop()
            return
        end

        local step = initialSteps[stepIndex]
        -- Only execute non-click_element steps initially
        if step.action ~= "click_element" then
            executeAction(step.action, step.params, function(result)
                table.insert(results, result)
                table.insert(history, {
                    type = "action",
                    content = string.format("%s: %s -> %s",
                        step.action,
                        json.encode(step.params),
                        result.success and "success" or "failed: " .. (result.error or "")),
                    timestamp = os.time()
                })

                timer.doAfter(config.actionDelay, function()
                    executeInitialSteps(stepIndex + 1)
                end)
            end)
        else
            executeInitialSteps(stepIndex + 1)
        end
    end

    -- Main agentic loop
    function agenticLoop()
        if iteration >= config.maxIterations then
            callback({
                success = false,
                message = "Max iterations reached without completing goal",
                steps = results,
                iterations = iteration
            })
            return
        end

        iteration = iteration + 1

        -- OBSERVE: Wait for UI to settle, then capture screen
        timer.doAfter(config.observationDelay, function()
            vision.describeScreen(function(observation, obsErr)
                if obsErr then
                    observation = "Failed to observe screen: " .. obsErr
                end

                table.insert(history, {
                    type = "observation",
                    content = observation,
                    timestamp = os.time()
                })

                -- THINK: Plan next action
                planNextAction(goal, history, function(nextAction, planErr)
                    if planErr then
                        callback({
                            success = false,
                            message = "Planning failed: " .. planErr,
                            steps = results,
                            iterations = iteration,
                            error = planErr
                        })
                        return
                    end

                    -- CHECK: Is goal achieved?
                    if nextAction.isComplete then
                        callback({
                            success = true,
                            message = nextAction.reasoning,
                            steps = results,
                            iterations = iteration
                        })
                        return
                    end

                    -- ACT: Execute the planned action
                    executeAction(nextAction.action, nextAction.params, function(result)
                        table.insert(results, result)

                        table.insert(history, {
                            type = "action",
                            content = string.format("%s: %s -> %s",
                                nextAction.action,
                                json.encode(nextAction.params),
                                result.success and "success" or "failed: " .. (result.error or "")),
                            timestamp = os.time()
                        })

                        -- Continue loop
                        timer.doAfter(config.actionDelay, agenticLoop)
                    end)
                end)
            end)
        end)
    end

    -- Start with initial steps
    executeInitialSteps(1)
end

--- hs.claude.agent.execute(command, callback)
--- Function
--- Executes a natural language command (async)
---
--- Parameters:
---  * command - Natural language command string
---  * callback - Function called with (result, error)
---    * result is a table with:
---      * success - boolean
---      * message - completion message
---      * steps - array of action results
---      * iterations - number of iterations used
---
--- Returns:
---  * None
function module.execute(command, callback)
    -- Parse intent
    parser.parse(command, function(intent, parseErr)
        if parseErr then
            callback({
                success = false,
                message = "Failed to parse command",
                steps = {},
                iterations = 0,
                error = parseErr
            })
            return
        end

        -- Choose execution mode
        if intent.requiresObservation then
            executeAgentic(intent.goal or command, intent.steps, callback)
        else
            executeSequential(intent.steps, callback)
        end
    end)
end

--- hs.claude.agent.executeSimple(steps, callback)
--- Function
--- Executes a pre-parsed list of steps (async)
---
--- Parameters:
---  * steps - Array of {action, params} tables
---  * callback - Function called with (result)
---
--- Returns:
---  * None
function module.executeSimple(steps, callback)
    executeSequential(steps, callback)
end

--- hs.claude.agent.executeWithVision(goal, callback)
--- Function
--- Executes a goal using the full agentic loop (async)
---
--- Parameters:
---  * goal - Goal description string
---  * callback - Function called with (result)
---
--- Returns:
---  * None
function module.executeWithVision(goal, callback)
    executeAgentic(goal, {}, callback)
end

return module
