-- Reusable animation and interpolation engine

local AnimationEngine = {}
_G.AnimationEngine = AnimationEngine
AnimationEngine.__index = AnimationEngine

AnimationEngine.AnimEnums = require("scripts/net-games/animation-engine/animation-enums")
local MathUtils = require("scripts/net-games/animation-engine/math-utils")

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
local cfg = {
    -- Default interpolation settings
    default_interp_speed = 10, -- units per second
    default_ro_speed = 180, -- degrees per second
    default_color_speed = 5, -- color component change per second
    default_scale_speed = 2, -- scale change per second
    
    -- Easing functions
    easing_functions = MathUtils.easing_functions,
    
    -- Logging
    debug = true,
    log_prefix = "[AnimationEngine] "
}

-- ---------------------------------------------------------------------------
-- State Management
-- ---------------------------------------------------------------------------

local animations = {} -- Active animations by ID
local sequences = {} -- Active sequences by ID
local callbacks = {} -- Scheduled callbacks

local animation_id_counter = 0

local function generate_id()
    animation_id_counter = animation_id_counter + 1
    return "anim_" .. animation_id_counter .. "_" .. math.random(1000, 9999)
end

local function log(message)
    if cfg.debug and message then
        print(cfg.log_prefix .. tostring(message))
    end
end

-- ---------------------------------------------------------------------------
-- Core Interpolation Functions
-- ---------------------------------------------------------------------------

-- Generic interpolation function with support for discrete values
function AnimationEngine.interpolate(start, target, t, easing, discrete)
    local ease_func = cfg.easing_functions[easing] or cfg.easing_functions.linear
    local eased_t = ease_func(t)
    
    -- For instant easing, we want to jump immediately to target for any t > 0
    if easing == "instant" and t > 0 then
        eased_t = 1
    end
    
    -- Create a set of discrete keys for fast lookup
    local discrete_set = {}
    if discrete then
        for _, key in ipairs(discrete) do
            discrete_set[key] = true
        end
    end
    
    if type(start) == "number" and type(target) == "number" then
        return MathUtils.lerp(start, target, eased_t)
    elseif type(start) == "table" and type(target) == "table" then
        local result = {}
        for key, start_value in pairs(start) do
            local target_value = target[key]
            
            -- Check if this key should be discrete
            if discrete_set[key] then
                -- Discrete value: change at the beginning of animation
                if t > 0 then
                    result[key] = target_value or start_value
                else
                    result[key] = start_value
                end
            elseif type(start_value) == "number" and type(target_value) == "number" then
                -- Regular interpolation for numeric values
                result[key] = MathUtils.lerp(start_value, target_value, eased_t)
            else
                -- Non-numeric or mismatched types - set to target immediately
                result[key] = target_value or start_value
            end
        end
        
        -- Also include any keys in target that aren't in start
        for key, target_value in pairs(target) do
            if not start[key] then
                -- Check if this key should be discrete
                if discrete_set[key] then
                    -- Discrete value: change at the beginning of animation
                    if t > 0 then
                        result[key] = target_value
                    end
                else
                    -- Non-numeric or new value - set to target immediately
                    result[key] = target_value
                end
            end
        end
        
        return result
    end
    
    return target or start
end

-- Create a smooth animation between values with looping support
function AnimationEngine.animate(start_values, target_values, duration, options)
    options = options or {}
    local easing = options.easing or "linear"
    local easing_back = options.easing_back or easing -- Optional different easing for the return trip
    local on_update = options.on_update
    local on_complete = options.on_complete
    local loop = options.loop or false -- Can be true (infinite), false (no loop), or a number (loop count)
    local ping_pong = options.ping_pong or false -- If true, alternates between start and target
    local discrete = options.discrete or {} -- Array of keys that should change discretely (not interpolated)
    local id = options.id or generate_id()
    
    -- For instant animations, duration should be effectively 0, but we need to process it
    -- So we'll handle this specially in the update function
    local actual_duration = duration
    if easing == "instant" then
        actual_duration = 0.001 -- Very small duration to trigger immediate update
    end
    
    local max_cycles = nil
    if type(loop) == "number" and loop > 0 then
        max_cycles = loop
        loop = true
    end
    
    local current_cycle = 0
    local phase = 1 -- 1 = forward (start->target), 2 = backward (target->start)
    local original_start_values = {}
    local original_target_values = {}
    
    -- Deep copy original values
    for k, v in pairs(start_values) do
        original_start_values[k] = v
    end
    for k, v in pairs(target_values) do
        original_target_values[k] = v
    end
    
    animations[id] = {
        id = id,
        start_time = os.clock(),
        duration = actual_duration,
        easing = easing,
        easing_back = easing_back,
        start_values = start_values,
        target_values = target_values,
        original_start_values = original_start_values,
        original_target_values = original_target_values,
        discrete = discrete,
        on_update = on_update,
        on_complete = on_complete,
        loop = loop,
        ping_pong = ping_pong,
        max_cycles = max_cycles,
        current_cycle = current_cycle,
        phase = phase,
        current_values = {}
    }
    
    log("Started animation: " .. id .. 
        (loop and " (looping)" or "") .. 
        (#discrete > 0 and " (discrete keys: " .. table.concat(discrete, ", ") .. ")" or "") ..
        (easing == "instant" and " (instant)" or ""))
    
    -- For instant animations, we should immediately trigger one update
    if easing == "instant" then
        -- Force an immediate update
        animations[id].current_values = target_values
        if on_update then
            on_update(target_values, 1.0, phase)
        end
        -- If not looping, complete immediately
        if not loop then
            if on_complete then
                on_complete(target_values, false)
            end
            animations[id] = nil
            log("Completed instant animation: " .. id)
        end
    end
    
    return id
end

-- Update all active animations
function AnimationEngine.update(dt)
    local current_time = os.clock()
    local to_remove = {}
    local to_process = {}
    
    -- First, collect all animations to process
    for id, anim in pairs(animations) do
        to_process[id] = anim
    end
    
    -- Then process them
    for id, anim in pairs(to_process) do
        -- Skip if animation was removed during processing
        if animations[id] == nil then
            goto continue
        end
        
        -- For instant animations, handle specially
        if anim.easing == "instant" then
            -- Set values to target immediately
            anim.current_values = anim.target_values
            
            -- Call update callback
            if anim.on_update then
                anim.on_update(anim.current_values, 1.0, anim.phase)
            end
            
            -- Handle completion
            if anim.loop then
                -- For looping instant animations
                anim.current_cycle = anim.current_cycle + 1
                if anim.max_cycles and anim.current_cycle >= anim.max_cycles then
                    -- Reached max cycles
                    if anim.on_complete then
                        anim.on_complete(anim.current_values, false)
                    end
                    table.insert(to_remove, id)
                    log("Completed instant animation (reached max cycles): " .. id)
                else
                    -- Continue looping
                    anim.start_time = current_time
                end
            else
                -- Not looping, complete the animation
                if anim.on_complete then
                    anim.on_complete(anim.current_values, false)
                end
                table.insert(to_remove, id)
                log("Completed instant animation: " .. id)
            end
            goto continue
        end
        
        local elapsed = current_time - anim.start_time
        local t = MathUtils.clamp01(elapsed / anim.duration)
        
        -- Determine which easing to use based on phase
        local current_easing = anim.phase == 1 and anim.easing or anim.easing_back
        
        -- Determine which values to use based on phase
        local phase_start_values, phase_target_values
        
        if anim.phase == 1 then
            phase_start_values = anim.start_values
            phase_target_values = anim.target_values
        else
            phase_start_values = anim.target_values
            phase_target_values = anim.start_values
        end
        
        -- Interpolate all values with discrete keys support
        anim.current_values = AnimationEngine.interpolate(
            phase_start_values, 
            phase_target_values, 
            t, 
            current_easing,
            anim.discrete
        )
        
        -- Call update callback
        if anim.on_update then
            anim.on_update(anim.current_values, t, anim.phase)
        end
        
        -- Check if complete for current phase
        if t >= 1.0 then
            if anim.phase == 1 then
                -- Completed forward phase
                if anim.ping_pong then
                    -- Start backward phase
                    anim.phase = 2
                    anim.start_time = current_time
                elseif anim.loop then
                    -- Check if we should continue looping
                    if anim.max_cycles and anim.current_cycle + 1 >= anim.max_cycles then
                        -- Reached max cycles
                        if anim.on_complete then
                            anim.on_complete(anim.current_values, false)
                        end
                        table.insert(to_remove, id)
                        log("Completed animation (reached max cycles): " .. id)
                    else
                        -- Continue looping
                        anim.current_cycle = anim.current_cycle + 1
                        anim.start_time = current_time
                    end
                else
                    -- Not looping, complete the animation
                    if anim.on_complete then
                        anim.on_complete(anim.current_values, false)
                    end
                    table.insert(to_remove, id)
                    log("Completed animation: " .. id)
                end
            else
                -- Completed backward phase (ping-pong)
                if anim.loop then
                    -- Check if we should continue looping
                    if anim.max_cycles and anim.current_cycle + 1 >= anim.max_cycles then
                        -- Reached max cycles
                        if anim.on_complete then
                            anim.on_complete(anim.current_values, false)
                        end
                        table.insert(to_remove, id)
                        log("Completed animation (reached max cycles): " .. id)
                    else
                        -- Continue looping
                        anim.current_cycle = anim.current_cycle + 1
                        anim.phase = 1
                        anim.start_time = current_time
                    end
                else
                    -- Not looping, complete the animation
                    if anim.on_complete then
                        anim.on_complete(anim.current_values, false)
                    end
                    table.insert(to_remove, id)
                    log("Completed animation: " .. id)
                end
            end
        end
        
        ::continue::
    end
    
    -- Clean up completed animations
    for _, id in ipairs(to_remove) do
        animations[id] = nil
    end
end

-- Stop an active animation
function AnimationEngine.stop_animation(id)
    if animations[id] then
        if animations[id].on_complete then
            animations[id].on_complete(animations[id].current_values, true) -- true = interrupted
        end
        animations[id] = nil
        log("Stopped animation: " .. id)
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Animation Sequences
-- ---------------------------------------------------------------------------

function AnimationEngine.create_sequence(steps, options)
    options = options or {}
    local id = options.id or generate_id()
    local loop = options.loop or false
    local on_complete = options.on_complete
    
    sequences[id] = {
        id = id,
        steps = steps,
        current_step = 1,
        start_time = os.clock(),
        loop = loop,
        on_complete = on_complete,
        active_animation = nil,
        step_data = {}
    }
    
    log("Created sequence: " .. id)
    return id
end

function AnimationEngine.start_sequence(id)
    local seq = sequences[id]
    if not seq then
        log("Sequence not found: " .. id)
        return false
    end
    
    seq.start_time = os.clock()
    seq.current_step = 1
    seq.active_animation = nil
    
    -- Start first step
    AnimationEngine._execute_sequence_step(id)
    
    log("Started sequence: " .. id)
    return true
end

function AnimationEngine._execute_sequence_step(seq_id)
    local seq = sequences[seq_id]
    if not seq or seq.current_step > #seq.steps then
        return false
    end
    
    local step = seq.steps[seq.current_step]
    step.id = step.id or (seq_id .. "_step_" .. seq.current_step)
    
    -- Store original values for "current" references
    if not seq.step_data[seq.current_step] then
        seq.step_data[seq.current_step] = {}
    end
    
    -- Handle different step types
    if step.type == "delay" then
        seq.next_step_time = os.clock() + step.duration
        seq.active_animation = nil
        
    elseif step.type == "animate" then
        -- Resolve "current" and "original" references
        local start_values = {}
        local target_values = {}
        
        for key, value in pairs(step.start or {}) do
            if type(value) == "string" then
                if value:find("^current%+") then
                    local offset = tonumber(value:match("current%+(.-)$"))
                    start_values[key] = (seq.step_data[seq.current_step][key] or 0) + offset
                elseif value == "current" then
                    start_values[key] = seq.step_data[seq.current_step][key] or 0
                elseif value == "original" then
                    start_values[key] = seq.original_values and seq.original_values[key] or 0
                else
                    start_values[key] = tonumber(value) or value
                end
            else
                start_values[key] = value
            end
        end
        
        for key, value in pairs(step.target or {}) do
            if type(value) == "string" then
                if value:find("^current%+") then
                    local offset = tonumber(value:match("current%+(.-)$"))
                    target_values[key] = (seq.step_data[seq.current_step][key] or 0) + offset
                elseif value == "current" then
                    target_values[key] = seq.step_data[seq.current_step][key] or 0
                elseif value == "original" then
                    target_values[key] = seq.original_values and seq.original_values[key] or 0
                else
                    target_values[key] = tonumber(value) or value
                end
            else
                target_values[key] = value
            end
        end
        
        -- Store start values for future reference
        for key, value in pairs(start_values) do
            seq.step_data[seq.current_step][key] = value
        end
        
        -- Start animation with discrete keys support
        seq.active_animation = AnimationEngine.animate(start_values, target_values, step.duration, {
            easing = step.easing,
            discrete = step.discrete, -- Pass through discrete keys
            on_update = step.on_update,
            on_complete = function(values, interrupted)
                if not interrupted then
                    -- Store final values
                    for key, value in pairs(values) do
                        seq.step_data[seq.current_step][key] = value
                    end
                    AnimationEngine._sequence_step_complete(seq_id)
                end
            end
        })
        
    elseif step.type == "callback" then
        if step.callback then
            step.callback()
        end
        AnimationEngine._sequence_step_complete(seq_id)
    end
    
    return true
end

function AnimationEngine._sequence_step_complete(seq_id)
    local seq = sequences[seq_id]
    if not seq then return end
    
    seq.current_step = seq.current_step + 1
    seq.active_animation = nil
    
    if seq.current_step > #seq.steps then
        -- Sequence complete
        if seq.loop then
            seq.current_step = 1
            AnimationEngine._execute_sequence_step(seq_id)
        else
            if seq.on_complete then
                seq.on_complete()
            end
            sequences[seq_id] = nil
            log("Sequence completed: " .. seq_id)
        end
    else
        -- Move to next step
        AnimationEngine._execute_sequence_step(seq_id)
    end
end

function AnimationEngine.update_sequences(dt)
    local current_time = os.clock()
    
    for seq_id, seq in pairs(sequences) do
        if seq.next_step_time and current_time >= seq.next_step_time then
            seq.next_step_time = nil
            AnimationEngine._sequence_step_complete(seq_id)
        end
    end
end

function AnimationEngine.stop_sequence(id)
    local seq = sequences[id]
    if not seq then return false end
    
    -- Stop any active animation
    if seq.active_animation then
        AnimationEngine.stop_animation(seq.active_animation)
    end
    
    sequences[id] = nil
    log("Stopped sequence: " .. id)
    return true
end

-- ---------------------------------------------------------------------------
-- Discrete-First Animation Helper
-- ---------------------------------------------------------------------------

-- Create animation where discrete values change immediately, then continuous values animate
function AnimationEngine.animate_discrete_first(start_values, target_values, duration, options)
    options = options or {}
    local discrete = options.discrete or {}
    
    -- Create a two-step approach:
    -- 1. First, immediately set discrete values
    -- 2. Then animate continuous values
    
    local step1_complete = false
    local discrete_values_set = false
    
    -- Create the animation with a custom on_update handler
    return AnimationEngine.animate(start_values, target_values, duration, {
        easing = options.easing or "linear",
        easing_back = options.easing_back,
        on_update = function(values, t, phase)
            -- If we haven't set discrete values yet, set them immediately
            if not discrete_values_set and t > 0 then
                discrete_values_set = true
                
                -- Call the original on_update immediately with discrete values set
                if options.on_update then
                    -- Create a copy of values with discrete values already at target
                    local discrete_first_values = {}
                    for k, v in pairs(values) do
                        discrete_first_values[k] = v
                    end
                    
                    -- Set discrete values to target immediately
                    for _, key in ipairs(discrete) do
                        if target_values[key] ~= nil then
                            discrete_first_values[key] = target_values[key]
                        end
                    end
                    
                    options.on_update(discrete_first_values, t, phase)
                end
            elseif options.on_update then
                options.on_update(values, t, phase)
            end
        end,
        on_complete = options.on_complete,
        loop = options.loop,
        ping_pong = options.ping_pong,
        max_cycles = options.max_cycles,
        discrete = discrete
    })
end

-- ---------------------------------------------------------------------------
-- Instant Transition Helpers
-- ---------------------------------------------------------------------------

-- Set value instantly (no animation)
function AnimationEngine.set_to(object, values)
    if not object then return end
    
    for key, value in pairs(values) do
        -- Use appropriate setter method if available
        if key == "x" or key == "y" then
            if object.setPosition then
                object:setPosition(values.x or object.x, values.y or object.y)
            else
                object.x = values.x or object.x
                object.y = values.y or object.y
            end
        elseif key == "scale" then
            if object.setScale then
                object:setScale(value)
            else
                object.scale = value
            end
        elseif key == "angle" then
            if object.setRotation then
                object:setRotation(value)
            else
                object.angle = value
            end
        elseif key == "alpha" then
            if object.setAlpha then
                object:setAlpha(value)
            else
                object.alpha = value
            end
        elseif key == "r" or key == "g" or key == "b" then
            if object.setColor then
                object:setColor(values.r or object.r, values.g or object.g, values.b or object.b)
            else
                object.r = values.r or object.r
                object.g = values.g or object.g
                object.b = values.b or object.b
            end
        else
            -- Set any other property directly
            object[key] = value
        end
    end
end

-- ---------------------------------------------------------------------------
-- Utility Functions
-- ---------------------------------------------------------------------------

-- Schedule a delayed callback
function AnimationEngine.delay(duration, callback)
    local id = "delay_" .. generate_id()
    callbacks[id] = {
        trigger_time = os.clock() + duration,
        callback = callback
    }
    return id
end

-- Update scheduled callbacks
function AnimationEngine.update_callbacks()
    local current_time = os.clock()
    local to_remove = {}
    local to_process = {}
    
    -- First collect all callbacks
    for id, cb in pairs(callbacks) do
        to_process[id] = cb
    end
    
    -- Then process them
    for id, cb in pairs(to_process) do
        if current_time >= cb.trigger_time then
            cb.callback()
            table.insert(to_remove, id)
        end
    end
    
    for _, id in ipairs(to_remove) do
        callbacks[id] = nil
    end
end

-- Get active animation count
function AnimationEngine.get_active_count()
    local count = 0
    for _ in pairs(animations) do count = count + 1 end
    return count
end

-- Get active sequence count
function AnimationEngine.get_sequence_count()
    local count = 0
    for _ in pairs(sequences) do count = count + 1 end
    return count
end

-- Clear all animations
function AnimationEngine.clear_all()
    for id, _ in pairs(animations) do
        AnimationEngine.stop_animation(id)
    end
    
    for id, _ in pairs(sequences) do
        AnimationEngine.stop_sequence(id)
    end
    
    callbacks = {}
    log("Cleared all animations")
end

-- ---------------------------------------------------------------------------
-- Main Update Function (to be called in game loop)
-- ---------------------------------------------------------------------------

Net:on("tick", function (event)
    AnimationEngine.tick(event.delta_time)
end)

function AnimationEngine.tick(dt)
    AnimationEngine.update(dt)
    AnimationEngine.update_sequences(dt)
    AnimationEngine.update_callbacks()
end

-- ---------------------------------------------------------------------------
-- Configuration Setters
-- ---------------------------------------------------------------------------

function AnimationEngine.set_debug(enabled)
    cfg.debug = enabled == true
end

function AnimationEngine.set_interpolation_speeds(position, ro, color, scale)
    if position then cfg.default_interp_speed = position end
    if ro then cfg.default_ro_speed = ro end
    if color then cfg.default_color_speed = color end
    if scale then cfg.default_scale_speed = scale end
end

function AnimationEngine.add_easing_function(name, func)
    if type(func) == "function" then
        cfg.easing_functions[name] = func
    end
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

return AnimationEngine