-- math-utils.lua
-- Reusable mathematical and easing functions

local MathUtils = {}
_G.MathUtils = MathUtils
MathUtils.__index = MathUtils

-- ---------------------------------------------------------------------------
-- Core Math Functions
-- ---------------------------------------------------------------------------

-- Clamp a value between 0 and 1
function MathUtils.clamp01(t)
    return t < 0 and 0 or (t > 1 and 1 or t)
end

-- Linear interpolation between a and b
function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Quadratic bezier curve calculation
function MathUtils.quadratic_bezier(p0, p1, p2, t)
    local u = 1 - t
    return u*u*p0.x + 2*u*t*p1.x + t*t*p2.x, 
           u*u*p0.y + 2*u*t*p1.y + t*t*p2.y
end

-- Cubic bezier curve calculation
function MathUtils.cubic_bezier(p0, p1, p2, p3, t)
    local u = 1 - t
    return u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
           u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
end

-- Map a value from one range to another
function MathUtils.map(value, in_min, in_max, out_min, out_max)
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

-- Normalize a value to 0-1 range
function MathUtils.normalize(value, min, max)
    return (value - min) / (max - min)
end

-- Round a number to specified decimal places
function MathUtils.round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Check if two numbers are approximately equal
function MathUtils.approximately(a, b, epsilon)
    epsilon = epsilon or 0.001
    return math.abs(a - b) < epsilon
end

-- Degrees to radians conversion
function MathUtils.deg_to_rad(degrees)
    return degrees * (math.pi / 180)
end

-- Radians to degrees conversion
function MathUtils.rad_to_deg(radians)
    return radians * (180 / math.pi)
end

-- Get the sign of a number (-1, 0, or 1)
function MathUtils.sign(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0 end
end

-- ---------------------------------------------------------------------------
-- Easing Functions
-- ---------------------------------------------------------------------------

MathUtils.easing_functions = {
    -- Returns 1 for any t > 0, meaning immediate transition to target
    instant = function(t)
        return t > 0 and 1 or 0
    end,
    
    linear = function(t) return t end,
    
    square = function(t) return t*t end,
    
    cubic = function(t) return t*t*t end,
    
    ease_in = function(t) return t * t end,
    
    ease_out = function(t) return t * (2 - t) end,
    
    ease_in_out = function(t)
        if t < 0.5 then
            return 2 * t * t
        else
            return -1 + (4 - 2 * t) * t
        end
    end,
    
    smoothstep = function(t) return t * t * (3 - 2 * t) end,
    
    smootherstep = function(t) return t * t * t * (t * (6 * t - 15) + 10) end,
    
    -- Elastic easing functions
    elastic_in = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4
        return -(2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
    end,
    
    elastic_out = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4
        return 2^(-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end,
    
    bounce_out = function(t)
        if t < 1 / 2.75 then
            return 7.5625 * t * t
        elseif t < 2 / 2.75 then
            t = t - 1.5 / 2.75
            return 7.5625 * t * t + 0.75
        elseif t < 2.5 / 2.75 then
            t = t - 2.25 / 2.75
            return 7.5625 * t * t + 0.9375
        else
            t = t - 2.625 / 2.75
            return 7.5625 * t * t + 0.984375
        end
    end,
    
    bounce_in = function(t)
        t = 1 - t
        if t < 1 / 2.75 then
            return 1 - 7.5625 * t * t
        elseif t < 2 / 2.75 then
            t = t - 1.5 / 2.75
            return 1 - (7.5625 * t * t + 0.75)
        elseif t < 2.5 / 2.75 then
            t = t - 2.25 / 2.75
            return 1 - (7.5625 * t * t + 0.9375)
        else
            t = t - 2.625 / 2.75
            return 1 - (7.5625 * t * t + 0.984375)
        end
    end,
    
    elastic_in_out = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4

        if t < 0.5 then
            t = t * 2  -- Scale t to [0, 1]
            return -0.5 * (2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
        else
            t = (t - 0.5) * 2  -- Scale t to [0, 1]
            return 0.5 * (2^(-10 * t)) * math.sin((t - s) * (2 * math.pi) / p) + 0.5
        end
    end,
    
    -- Additional easing functions
    sine_in = function(t)
        return 1 - math.cos((t * math.pi) / 2)
    end,
    
    sine_out = function(t)
        return math.sin((t * math.pi) / 2)
    end,
    
    sine_in_out = function(t)
        return -(math.cos(math.pi * t) - 1) / 2
    end,
    
    circ_in = function(t)
        return 1 - math.sqrt(1 - t * t)
    end,
    
    circ_out = function(t)
        t = t - 1
        return math.sqrt(1 - t * t)
    end,
    
    circ_in_out = function(t)
        t = t * 2
        if t < 1 then
            return -(math.sqrt(1 - t * t) - 1) / 2
        else
            t = t - 2
            return (math.sqrt(1 - t * t) + 1) / 2
        end
    end,
    
    back_in = function(t)
        local s = 1.70158
        return t * t * ((s + 1) * t - s)
    end,
    
    back_out = function(t)
        local s = 1.70158
        t = t - 1
        return t * t * ((s + 1) * t + s) + 1
    end,
    
    back_in_out = function(t)
        local s = 1.70158 * 1.525
        t = t * 2
        if t < 1 then
            return 0.5 * (t * t * ((s + 1) * t - s))
        else
            t = t - 2
            return 0.5 * (t * t * ((s + 1) * t + s) + 2)
        end
    end
}

-- Apply easing function by name
function MathUtils.ease(t, easing_name)
    local ease_func = MathUtils.easing_functions[easing_name]
    if ease_func then
        return ease_func(t)
    end
    return t  -- Default to linear if easing not found
end

-- Apply easing and clamp between 0 and 1
function MathUtils.ease_clamped(t, easing_name)
    return MathUtils.clamp01(MathUtils.ease(t, easing_name))
end

-- ---------------------------------------------------------------------------
-- Animation Math Functions
-- ---------------------------------------------------------------------------

-- Calculate progress based on elapsed time and duration
function MathUtils.calculate_progress(elapsed_time, duration)
    if duration <= 0 then return 1 end
    return MathUtils.clamp01(elapsed_time / duration)
end

-- Interpolate between two values with easing
function MathUtils.interpolate_with_easing(start, target, t, easing_name)
    local eased_t = MathUtils.ease_clamped(t, easing_name)
    return MathUtils.lerp(start, target, eased_t)
end

-- Interpolate between two colors with easing
function MathUtils.interpolate_color(start_r, start_g, start_b, start_a,
                                    target_r, target_g, target_b, target_a,
                                    t, easing_name)
    local eased_t = MathUtils.ease_clamped(t, easing_name)
    return MathUtils.lerp(start_r, target_r, eased_t),
           MathUtils.lerp(start_g, target_g, eased_t),
           MathUtils.lerp(start_b, target_b, eased_t),
           MathUtils.lerp(start_a, target_a, eased_t)
end

-- Calculate shake offset for screen shake effects
function MathUtils.calculate_shake_offset(time, frequency, intensity, decay)
    decay = decay or 1
    local current_intensity = intensity * decay
    local x = math.sin(time * frequency * math.pi * 2) * current_intensity
    local y = math.cos(time * frequency * math.pi * 2) * current_intensity * 0.7
    return x, y
end

-- Calculate pulse value for pulsing effects
function MathUtils.calculate_pulse(time, frequency, min_value, max_value)
    local normalized = (math.sin(time * frequency * math.pi * 2) + 1) / 2
    return MathUtils.lerp(min_value, max_value, normalized)
end

-- ---------------------------------------------------------------------------
-- Geometric Functions
-- ---------------------------------------------------------------------------

-- Calculate distance between two points
function MathUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Calculate squared distance (faster, avoids sqrt)
function MathUtils.distance_squared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

-- Calculate angle between two points in radians
function MathUtils.angle_between(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- Calculate angle between two points in degrees
function MathUtils.angle_between_degrees(x1, y1, x2, y2)
    return MathUtils.rad_to_deg(MathUtils.angle_between(x1, y1, x2, y2))
end

-- Calculate midpoint between two points
function MathUtils.midpoint(x1, y1, x2, y2)
    return (x1 + x2) / 2, (y1 + y2) / 2
end

-- Check if point is within rectangle
function MathUtils.point_in_rect(px, py, rect_x, rect_y, rect_width, rect_height)
    return px >= rect_x and px <= rect_x + rect_width and
           py >= rect_y and py <= rect_y + rect_height
end

-- ---------------------------------------------------------------------------
-- Random Functions
-- ---------------------------------------------------------------------------

-- Random float between min and max
function MathUtils.random_float(min, max)
    return min + math.random() * (max - min)
end

-- Random integer between min and max (inclusive)
function MathUtils.random_int(min, max)
    return math.floor(MathUtils.random_float(min, max + 1))
end

-- Random sign (-1 or 1)
function MathUtils.random_sign()
    return math.random() < 0.5 and -1 or 1
end

-- Random element from array
function MathUtils.random_element(array)
    if #array == 0 then return nil end
    return array[math.random(1, #array)]
end

-- ---------------------------------------------------------------------------
-- Table Operations
-- ---------------------------------------------------------------------------

-- Deep copy a table
function MathUtils.deep_copy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = MathUtils.deep_copy(v)
        end
        copy[k] = v
    end
    return copy
end

-- Merge two tables (second table overwrites first)
function MathUtils.merge_tables(t1, t2)
    local result = MathUtils.deep_copy(t1)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = MathUtils.merge_tables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

return MathUtils