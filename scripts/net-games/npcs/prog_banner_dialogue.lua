--=====================================================
-- prog_banner_dialogue.lua
-- Tiled-spawned NPC that triggers net-games Marquee
--=====================================================

local Direction = require("scripts/libs/direction")
local Displayer  = require("scripts/net-games/displayer/displayer")

local DEBUG = true
local function dbg(msg)
  if DEBUG then print("[prog_banner_dialogue] " .. msg) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id = "default"
local obj_name = "ProgBannerDialogue"

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_banner_dialogue] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "Banner Prog",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

dbg("LOADED bot_id=" .. tostring(bot_id))

--=====================================================
-- Per-player guard so they can't spam re-trigger
--=====================================================
local marquee_active = {}

--=====================================================
-- Interaction handler
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end
  local player_id = event.player_id

  if marquee_active[player_id] then
    return
  end
  marquee_active[player_id] = true

  -- Face the player (same pattern as hpmem_shop_bot)
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  local marquee_id = "prog_marquee"

  -- Creator-facing / modular control lives HERE:
  -- tweak x/y/width/height/padding to taste per NPC
  local backdrop = {
    x = 0,
    y = 0,
    width = 240,
    height = 30,
    padding_x = 6,
    padding_y = 0,

    -- loop controls already supported by your TextDisplay
    loops = "once",            -- nil/true = infinite; "once"/false = 1; number = N
    keep_backdrop = false,     -- remove backdrop when done
    on_finish = function(pid, id)
      dbg("marquee finished for player " .. tostring(pid))
      marquee_active[pid] = false
      -- safety cleanup (text chars should already be erased by on_finish path)
      -- but this ensures nothing lingers if something changed later:
      pcall(function() Displayer.Text.removeText(pid, id) end)
    end,
  }

  -- NOTE: your current signature is (player_id, marquee_id, text, y, font, scale, z, speed, backdrop)
  Displayer.Text.drawMarqueeText(
    player_id,
    marquee_id,
    "Yo! I hope you like what I've got done so far. This is BANNER mode. set inside the NPC. I pretty much am addicted at this point. :)",
    0,              -- y is ignored/overridden when backdrop exists (your current implementation centers it)
    "THICK",        -- or "THICK_BLACK" if your font table supports it
    2.0,
    100,
    "medium",
    backdrop
  )
end)

-- Clean up guard on disconnect
Net:on("player_disconnect", function(event)
  marquee_active[event.player_id] = nil
end)
