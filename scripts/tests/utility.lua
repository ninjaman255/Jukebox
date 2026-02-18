-- Net.lua
-- Main module that integrates EventEmitter and Async

local Utility = {}

-- Load sub-modules
Utility.EventEmitter = require("scripts/tests/event-emitter")
Utility.Async = require("scripts/tests/async")

-- Shortcut methods
Utility.create_promise = Utility.Async.create_promise
Utility.promisify = Utility.Async.promisify
Utility.await = Utility.Async.await
Utility.run = Utility.Async.run

-- Example usage pattern from the original code
function Utility.create_event_test()
    local emitter = Net.EventEmitter.new()
    
    -- Example of async iteration
    local function start_listening()
        local iter = emitter:async_iter("data")
        
        Utility.run(function()
            for value in Utility.await(iter) do
                print("Received:", value)
            end
        end)
        
        return emitter
    end
    
    return emitter, start_listening
end

-- Helper for multi-value promises
function Utility.resolve_multi(...)
    local args = {...}
    return Utility.create_promise(function(resolve)
        resolve(table.unpack(args))
    end)
end

-- Event-driven promise
function Utility.event_to_promise(emitter, event_name)
    return Utility.create_promise(function(resolve)
        emitter:once(event_name, function(...)
            resolve(...)
        end)
    end)
end

return Utility