-- animation-enums.lua (enhanced)
local AnimationEnums = {}
_G.AnimationEnums = AnimationEnums
AnimationEnums.__index = AnimationEnums

AnimationEnums.easing_function_names = {
    instant = "instant",
    linear = "linear",
    ease_in = "ease_in",
    ease_out = "ease_out",
    ease_in_out = "ease_in_out",
    smoothstep = "smoothstep",
    smootherstep = "smootherstep",
    elastic_in = "elastic_in",
    elastic_out = "elastic_out",
    bounce_out = "bounce_out",
    bounce_in = "bounce_in",
    elastic_in_out = "elastic_in_out",
    square = "square",
    cubic = "cubic"
}

-- Animation type enums
AnimationEnums.animation_types = {
    SUMMON = "summon",
    SET = "set",
    POSITION_CHANGE = "position_change",
    ATTACK = "attack",
    SLIDE = "slide",
    BOB = "bob",
    PULSE = "pulse",
    SHAKE = "shake",
    FADE = "fade",
    TINT = "tint",
    COLOR_PULSE = "color_pulse"
}

-- Animation property enums
AnimationEnums.animation_properties = {
    POSITION_X = "x",
    POSITION_Y = "y",
    SCALE = "scale",
    SCALE_X = "scaleX",
    SCALE_Y = "scaleY",
    ROTATION = "rotation",
    ALPHA = "alpha",
    COLOR_R = "r",
    COLOR_G = "g",
    COLOR_B = "b",
    COLOR_A = "a"
}

-- Animation direction enums
AnimationEnums.directions = {
    UP = "up",
    DOWN = "down",
    LEFT = "left",
    RIGHT = "right",
    IN = "in",
    OUT = "out"
}

-- Animation trigger enums
AnimationEnums.triggers = {
    ON_CLICK = "on_click",
    ON_HOVER = "on_hover",
    ON_SHOW = "on_show",
    ON_HIDE = "on_hide",
    ON_COMPLETE = "on_complete",
    ON_START = "on_start"
}

return {
    EasingFns = AnimationEnums.easing_function_names,
    AnimationTypes = AnimationEnums.animation_types,
    Properties = AnimationEnums.animation_properties,
    Directions = AnimationEnums.directions,
    Triggers = AnimationEnums.triggers
}