--=====================================================
-- prog_basic_nameplate_dialogue.lua
-- Like prog_basic_dialogue.lua, but with a BN-style nameplate.
--=====================================================

local Direction = require("scripts/libs/direction")
local Dialogue  = require("scripts/net-games/dialogue/dialogue")

local DEBUG = false
local function dbg(msg)
  if DEBUG then print("[prog_basic_nameplate_dialogue] " .. tostring(msg)) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id  = "default"
local obj_name = "ProgBasicNameplateDialogue" -- create a Tiled object with this exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_basic_nameplate_dialogue] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "PROG.EXE",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

local BOT_NAME = Net.get_bot_name(bot_id)

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

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  dbg("interacted by player " .. tostring(player_id))

  Dialogue.start(player_id, {
    "HEY HEY! New stuff is cooking. {p_2}",
    'Next up: "color ramped dying" (because plain dying is so last patch.) {p_2}',
    'And a brand new "CANDY UI" textbox theme... coming SOON! {p_2}',
    "Stick around. This prog's about to get deliciously illegal. {end_page}",
  }, {
    page_advance = "wait_for_confirm",
    confirm_during_typing = true,

    ui = {
      box_id = "prog_dialogue_nameplate_box",
      font = "THIN_BLACK",
      scale = 2.0,
      z = 100,
      typing_speed = 12,
      type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
      type_sfx_min_dt = 0.05,

      -- ? Nameplate (same pattern you used in prog_prompt_dialogue.lua)
      nameplate = {
        text = BOT_NAME,
        anchor = "above",
        align = "left",
        gap_x = 6,
        gap_y = 59,
        dur = 0.20,
        close_dur = 0.20,
        bob_amp = 1.2,
        bob_speed = 2,
      },

      backdrop = {
        render_offset_x = 3,
        render_offset_y = 46,
        style = "textbox_panel",
        open_seconds = 0.20,
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
        },
      },

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
      dbg("done")
    end,
  })
end)
