--=====================================================
-- prog_prompt_dialogue_shared_box.lua
-- Tiled-spawned NPC that shows a YES/NO prompt,
-- then follows up with Dialogue.start,
-- reusing the same textbox UI (no close/recreate).
--=====================================================

local Direction = require("scripts/libs/direction")
local Dialogue  = require("scripts/net-games/dialogue/dialogue")

local DEBUG = false
local function dbg(msg)
  if DEBUG then print("[prog_prompt_dialogue_shared_box] " .. tostring(msg)) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id  = "default"
local obj_name = "ProgPromptDialogue" -- create a Tiled object with this exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_prompt_dialogue_shared_box] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "Prompt Prog.EXE",
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
-- Shared box id (prompt and dialogue MUST match this)
--=====================================================
local SHARED_BOX_ID = "prog_prompt_shared_box"

--=====================================================
-- Shared UI base (clone of prog_basic_dialogue.lua settings)
--=====================================================
local function basic_prog_ui(box_id)
  return {
    box_id = box_id,
    font = "THIN_BLACK",
    scale = 2.0,
    z = 100,
    typing_speed = 12,
    type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
    type_sfx_min_dt = 0.05,
    nameplate = {
      text = BOT_NAME,
      anchor = "above",
      align = "left",
      gap_x = 6,
      gap_y = 59,
      dur = 0.20,
      close_dur = 0.20,
      bob_amp = 1.2,
      bob_speed = 2
    },

    backdrop = {
      close_seconds = 0.25,
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

      -- Leave indicator enabled in UI.
      -- Prompt.lua toggles it dynamically when Yes/No selector is visible.
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
  }
end

-- Two helpers so you can tweak prompt vs dialogue later without collateral damage
-- NOTE: both return the SAME box_id now, so prompt and dialogue reuse the textbox.
local function prog_ui_prompt()
  local ui = basic_prog_ui(SHARED_BOX_ID)
  ui.backdrop.indicator.enabled = true
  return ui
end

local function prog_ui_dialogue()
  local ui = basic_prog_ui(SHARED_BOX_ID)
  ui.backdrop.indicator.enabled = true
  return ui
end

--=====================================================
-- Interaction handler
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end

  local player_id = event.player_id
  if Dialogue.is_active(player_id) then
    return
  end

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  Dialogue.prompt_yesno(player_id, {
    question = "Like what you see?",
    cancel_behavior = "select_no",

    -- Prompt opens the textbox using SHARED_BOX_ID
    ui = prog_ui_prompt(),

    on_yes = function()
      Dialogue.start(player_id, {
        "GLAD TO HEAR IT! {p_2}",
        "I've got so much more in store!",
      }, {
        from_prompt = true,
        reuse_existing_box = true, -- IMPORTANT: do reset, not create
        page_advance = "wait_for_confirm",
        confirm_during_typing = true,

        -- Dialogue reuses the same SHARED_BOX_ID textbox
        ui = prog_ui_dialogue(),
      })
    end,

    on_no = function()
      Dialogue.start(player_id, {
        "Awh man. :(",
        "I can understand why though. This can be quite buggy!!!",
      }, {
        from_prompt = true,
        reuse_existing_box = true, -- IMPORTANT: do reset, not create
        page_advance = "wait_for_confirm",
        confirm_during_typing = true,
        ui = prog_ui_dialogue(),
      })
    end,

    on_cancel = function()
      -- Silent cancel
    end,
  })
end)
