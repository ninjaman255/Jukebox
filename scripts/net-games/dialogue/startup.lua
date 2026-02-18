-- server/scripts/net-games/dialogue/startup.lua
print("[net-games dialogue/startup] LOADING...")
-- =====================================================
-- Textbox debug master switch
-- =====================================================
_G.NG_TEXTBOX_DEBUG = false          -- set false to disable
_G.NG_TEXTBOX_DEBUG_TRACE = false   -- set true if you want stack traces (spammy)

local Displayer = require("scripts/net-games/displayer/displayer")
local Input     = require("scripts/net-games/input/input")

assert(Displayer:init() and Displayer:isValid(), "[net-games dialogue/startup] Displayer failed to init")
Input.attach_virtual_input_listener()

-- Configure shared backdrop sprite used by marquee + text boxes
local td = Displayer:_getSubsystem("TextDisplaySystem")

td.backdrop_sprite = td.backdrop_sprite or {}
td.backdrop_sprite.texture_path = "/server/assets/net-games/displayer/marquee-backdrop.png"
td.backdrop_sprite.anim_path    = nil
td.backdrop_sprite.sprite_id    = 9001

print("[net-games dialogue/startup] READY")
return true
