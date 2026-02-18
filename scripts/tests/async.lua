-- Async.lua
-- Async/await and Promise utilities for Lua

local Async = {}

-- Promise states
local PROMISE_STATE = {
    PENDING = "pending",
    FULFILLED = "fulfilled",
    REJECTED = "rejected"
}

-- Create a new Promise
function Async.create_promise(executor)
    local promise = {
        state = PROMISE_STATE.PENDING,
        value = nil,
        error = nil,
        on_fulfilled = {},
        on_rejected = {}
    }
    
    local function resolve(...)
        if promise.state ~= PROMISE_STATE.PENDING then return end
        
        promise.state = PROMISE_STATE.FULFILLED
        promise.value = {...}
        
        -- Call all fulfillment handlers
        for _, handler in ipairs(promise.on_fulfilled) do
            handler(...)
        end
        
        promise.on_fulfilled = {}
        promise.on_rejected = {}
    end
    
    local function reject(error)
        if promise.state ~= PROMISE_STATE.PENDING then return end
        
        promise.state = PROMISE_STATE.REJECTED
        promise.error = error
        
        -- Call all rejection handlers
        for _, handler in ipairs(promise.on_rejected) do
            handler(error)
        end
        
        promise.on_fulfilled = {}
        promise.on_rejected = {}
    end
    
    -- Add promise methods (defined with colon syntax)
    function promise:and_then(on_fulfilled, on_rejected)
        if self.state == PROMISE_STATE.FULFILLED then
            if on_fulfilled then
                on_fulfilled(table.unpack(self.value))
            end
        elseif self.state == PROMISE_STATE.REJECTED then
            if on_rejected then
                on_rejected(self.error)
            end
        else
            if on_fulfilled then
                table.insert(self.on_fulfilled, on_fulfilled)
            end
            if on_rejected then
                table.insert(self.on_rejected, on_rejected)
            end
        end
        return self
    end
    
    -- Try to execute the executor
    local success, err = pcall(function()
        executor(resolve, reject)
    end)
    
    if not success then
        reject(err)
    end
    
    return promise
end

-- Convert a coroutine to a promise
function Async.promisify(coroutine_func)
    return Async.create_promise(function(resolve, reject)
        local co = coroutine.create(coroutine_func)
        
        local function step(...)
            local success, result = coroutine.resume(co, ...)
            
            if not success then
                reject(result)
                return
            end
            
            if coroutine.status(co) == "dead" then
                resolve(result)
            else
                -- If the coroutine yielded a promise, wait for it
                if type(result) == "table" and result.and_then then
                    result:and_then(
                        function(...) step(...) end,
                        function(err) reject(err) end
                    )
                else
                    step(result)
                end
            end
        end
        
        step()
    end)
end

-- Await a promise inside a coroutine
function Async.await(promise_or_iterator)
    -- Check if it's an iterator (from EventEmitter.async_iter)
    if type(promise_or_iterator) == "function" then
        local result = promise_or_iterator()
        
        if type(result) == "function" then
            -- It's an async iterator waiting for resolution
            return coroutine.yield(result)
        else
            -- It's a regular iterator return
            return result
        end
    end
    
    -- It's a promise
    if promise_or_iterator.state == PROMISE_STATE.FULFILLED then
        return table.unpack(promise_or_iterator.value)
    elseif promise_or_iterator.state == PROMISE_STATE.REJECTED then
        error(promise_or_iterator.error)
    else
        -- Promise is pending, yield and wait
        return coroutine.yield(function(resolve, reject)
            promise_or_iterator:and_then(
                function(...)
                    resolve(...)
                end,
                function(err)
                    reject(err)
                end
            )
        end)
    end
end

-- Utility function to run async code
function Async.run(main_function)
    local promise = Async.promisify(coroutine.create(main_function))
    return promise
end

-- Helper for creating validation functions
function Async.create_validator(expected_values, error_message)
    return function(...)
        local args = {...}
        for i, expected in ipairs(expected_values) do
            if args[i] ~= expected then
                error(error_message)
            end
        end
    end
end

return Async