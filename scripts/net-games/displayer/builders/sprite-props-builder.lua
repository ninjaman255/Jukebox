local boom = require("scripts/boom/main")

local SpritePropsBuilder = {}
SpritePropsBuilder.__index = SpritePropsBuilder

function SpritePropsBuilder:new()
    local o = {
        props = {}
    }
    setmetatable(o, self)
    return o
end

function SpritePropsBuilder:build_sprite_atlas(texture_path, anim_path)
    if texture_path ~= nil then 
        self.props.texture_path = texture_path 
    end
    if anim_path ~= nil then 
        self.props.anim_path = anim_path
        -- Parse Animation File
        local parsedAnim = boom.load(anim_path)
        if parsedAnim ~= nil then 
            self.props.animation_states = parsedAnim.states
        end
    end
    return self
end

function SpritePropsBuilder:build_position(x, y, z)
    if x ~= nil then self.props.x = x end
    if y ~= nil then self.props.y = y end
    if z ~= nil then self.props.z = z end
    return self
end

function SpritePropsBuilder:build_scale(sx, sy)
    if sx == nil and sy == nil then
        self.props.sx = 2.0
        self.props.sy = 2.0
    else
        if sx ~= nil then self.props.sx = sx end
        if sy ~= nil then self.props.sy = sy end
    end
    return self
end

function SpritePropsBuilder:build_tint(a, r, g, b, color_mode)
    if a ~= nil then self.props.a = a end
    if r ~= nil then self.props.r = r end
    if g ~= nil then self.props.g = g end
    if b ~= nil then self.props.b = b end
    if color_mode ~= nil then
        if color_mode == 0 or color_mode == 1 or color_mode == 2 then
            self.props.color_mode = color_mode
        else
            print("Warning: color_mode must be 0, 1, or 2. Got: " .. tostring(color_mode))
        end
    end
    return self
end

function SpritePropsBuilder:build_origin(ox, oy)
    if ox ~= nil then self.props.ox = ox end
    if oy ~= nil then self.props.oy = oy end
    return self
end

function SpritePropsBuilder:build_rotation(ro)
    if ro ~= nil then self.props.ro = ro end
    return self
end

function SpritePropsBuilder:set_any_prop(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        local tbl = args[1]
        for k, v in pairs(tbl) do
            self.props[k] = v
        end
    elseif #args % 2 == 0 then
        for i = 1, #args, 2 do
            self.props[args[i]] = args[i+1]
        end
    end
    return self
end

function SpritePropsBuilder:build()
    return self.props
end

return SpritePropsBuilder