--=====================================================
-- prog_dramatic_dialogue.lua
-- Tiled-spawned NPC that triggers net-games Dialogue
-- (BLACK BOX style + normal THICK font)
--=====================================================

local Direction = require("scripts/libs/direction")
local Dialogue  = require("scripts/net-games/dialogue/dialogue")

local DEBUG = true
local function dbg(msg)
  if DEBUG then print("[prog_basic_dialogue] " .. msg) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id = "default"
local obj_name = "ProgDramaticDialogue"

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_dramatic_dialogue] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "Dramatic Prog",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow.png", -- change if needed
  animation_path = "/server/assets/ow/prog/prog_ow.animation", -- change if needed
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

dbg("LOADED bot_id=" .. tostring(bot_id))

--=====================================================
-- Interaction handler
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end

  local player_id = event.player_id
  if Dialogue.is_active(player_id) then
    -- already in dialogue; ignore retriggers
    return
  end

  dbg("interacted by player " .. tostring(player_id))

  -- Face the player (same pattern as hpmem_shop_bot)
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  Dialogue.start(player_id, {
    "Now, for my favorite addition.{p_2}",
    "",
    "If you're looking for drama,{p_1.5} it's.{p_2}.{p_3}.{p_1}",
    "",
    "\"RIGHT HERE BABY\"!",
    "",
    "",
    "Clever, isn't it?",
    "I need coffee :,)",
  }, {
    page_advance = "wait_for_confirm",
    confirm_during_typing = true,

    ui = {
      box_id = "prog_dialogue_box",
      font = "THICK",
      scale = 2.0,
      z = 100,
      typing_speed = 30,
      type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
      type_sfx_min_dt = 0.05,
      -- Creator-facing / modular control lives HERE:
      -- not sure if this is intentional, but I noticed a 1/2 pixel offset for the main textboxes built into ONB.
      -- This is set to compensate for that.
      backdrop = {
        style = "black_box", -- NOTE: basic = black box

        x = 1,
        y = 209, -- this right here leaves us at exactly 4.5 "in game" pixels above the bottom of the screen- identical to built in UI.
        width = 478,
        height = 104,
        padding_x = 16,
        padding_y = 16,
        max_lines = 3,

        indicator = {
          enabled = true,
          width = 2,      -- use your coordinate space (these are “double” style units)
          height = 2,
          offset_x = 24,
          offset_y = 24,
          -- bobbing control (no animation file)
          indicator_timer = 0,
          indicator_base_x = nil,
          indicator_base_y = nil,
        }
      }
    },

    on_finish = function()
      print("[prog_basic_dialogue] done")
    end,
  })
end)
