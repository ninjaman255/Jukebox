--=====================================================
-- prog_basic_dialogue.lua
-- Tiled-spawned NPC that triggers net-games Dialogue
-- (BLACK BOX style + normal THICK font)
--=====================================================

local Direction = require("scripts/libs/direction")
local Dialogue  = require("scripts/net-games/dialogue/dialogue")

local DEBUG = false
local function dbg(msg)
  if DEBUG then print("[prog_basic_dialogue] " .. msg) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id = "default"
local obj_name = "ProgBasicDialogue"

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_basic_dialogue] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "Basic Prog",
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

  -- Face the player (same pattern as hpmem_shop_bot)
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  dbg("interacted by player " .. tostring(player_id))

  Dialogue.start(player_id, {
    "Yoooo! Now that you can see my mouth flap I bet you're excited.",
    "Me too. I can't wait to impliment more features!",
    "Let me know if there's anything else that I can do!",
  }, {
    page_advance = "wait_for_confirm",
    confirm_during_typing = true,

    -- modular control 
ui = {
  box_id = "prog_dialogue_box",
  font = "THIN_BLACK",
  scale = 2.0,
  z = 100,
  typing_speed = 30,
  type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
  type_sfx_min_dt = 0.05,

  backdrop = {
    render_offset_x = 3,
    render_offset_y = 46,
    style = "textbox_panel",
    x = 1,
    y = 209,
    width = 478,
    height = 104,
    padding_x = 16,
    padding_y = 4,
    max_lines = 3,

    indicator = {
      enabled = true,
      width = 2,
      height = 2,
      offset_x = 24,
      offset_y = 26,
      indicator_timer = 0,
      indicator_base_x = nil,
      indicator_base_y = nil,
    }, -- <-- REQUIRED COMMA
  },

  -- mugshot must be HERE (ui.mugshot), not inside ui.backdrop
  mugshot = {
    enabled = true,
    texture_path = "/server/assets/ow/prog/prog_mug.png",
    anim_path = "/server/assets/ow/prog/prog_mug.animation",
    talk_anim_state = "TALK",
    idle_anim_state = "IDLE",
    reserve_w = 40,
    reserve_h = 40,

    offset_x = 6,
    offset_y = -46,

    gap_px = 6,
    sprite_id = 5300,

    z_bias = 50,

  },
},


    on_finish = function()
      print("[prog_basic_dialogue] done")
    end,
  })
end)
