--=====================================================
-- prog_vert_prompt_2.lua
-- Vertical prompt demo PROG (basic style, like prog_basic_nameplate)
--
-- Adds:
--   - Mugshot support in the vertical prompt UI
--   - Mugshot support in the follow-up Dialogue (reuse_existing_box)
--   - RED frame dye applied to:
--       * vertical menu frame overlay
--       * textbox frame overlay
--       * nameplate frame overlay
--     (using the same red preset from talk_presets.lua)
--=====================================================

local Direction = require("scripts/libs/direction")
require("scripts/net-games/dialogue/startup")

local Dialogue       = require("scripts/net-games/dialogue/dialogue")
local PromptVertical = require("scripts/net-games/dialogue/prompt_vertical")
local TalkPresets    = require("scripts/net-games/npcs/talk_presets")

--=====================================================
-- Area / placement (must match your TMX object name)
--=====================================================
local area_id  = "default"
local obj_name = "ProgVertPrompt2" -- create a Tiled object with THIS exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_vert_prompt] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

--=====================================================
-- Bot creation (the overworld NPC)
--=====================================================
local bot_id = Net.create_bot({
  name = "OVERKILL PROMPT PROG",
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

--=====================================================
-- Frame dye preset (from talk_presets.lua)
--=====================================================
local function copy_frame_preset(preset)
  if type(preset) ~= "table" then return nil end
  return {
    r = preset.r, g = preset.g, b = preset.b, a = preset.a,
    color_mode = preset.color_mode,
  }
end

local RED_FRAME = copy_frame_preset(TalkPresets.frames.red)

--=====================================================
-- Options builder (menu entries)
--=====================================================
local function build_options()
  local t = {}
  for i = 1, 999 do
    t[#t+1] = { id = i, text = ("Option %02d"):format(i) }
  end
  t[#t+1] = { id = "exit", text = "Exit" }
  return t
end

--=====================================================
-- Shared UI config
-- (So the prompt + follow-up dialogue stay visually identical)
--=====================================================
local function build_ui_config(box_id)
  return {
    box_id = box_id,

    -- Text look/feel
    font = "THIN_BLACK",
    scale = 2.0,
    z = 100,
    typing_speed = 12,
    type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
    type_sfx_min_dt = 0.05,

    --=====================================================
    -- Mugshot
    --=====================================================
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

    --=====================================================
    -- Backdrop (textbox frame)
    --=====================================================
    backdrop = {
      render_offset_x = 3,
      render_offset_y = 46,
      style = "textbox_panel_frame_tint",
      open_seconds = 0.20,

        -- Frame overlay dye (RED) — textbox expects tint on the backdrop table itself
        r = RED_FRAME.r,
        g = RED_FRAME.g,
        b = RED_FRAME.b,
        a = RED_FRAME.a,
        color_mode = RED_FRAME.color_mode,


      -- Screen placement / size
      x = 1,
      y = 209,
      width = 478,
      height = 104,

      -- Text padding / flow
      padding_x = 16,
      padding_y = 4,
      max_lines = 3,

      -- Textbox “continue” indicator (THIS is not the menu cursor)
      indicator = { enabled = true, width = 2, height = 2, offset_x = 24, offset_y = 26 },
    },

    --=====================================================
    -- Nameplate (above textbox)
    --=====================================================
    nameplate = {
      -- Frame overlay dye (RED)
      frame = RED_FRAME,

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
  }
end

--=====================================================
-- Shared menu layout config
--=====================================================
local function build_layout_config()
  return {
    anchor = "textbox",
    offset_x = 1,
    offset_y = -199,

    width = 160,
    height = 64,

    -- Menu frame overlay dye (RED)
    frame = RED_FRAME,

    visible_rows = 5,
    row_height = 14,

    -- NOTE: if you reserve mug space, you usually want a bigger left padding
    -- so the menu text doesn't crowd the mug.
    padding_x = 48,
    padding_y = 4,

    -- Scrollbar is part of the "physical menu" (always fine to show)
    scrollbar_x = 452,
    scrollbar_y = 12,
    scrollbar_h = 126,

    scroll_indicator_h = 12,

    -- Highlight + cursor placement
    highlight_inset_x = 12,
    highlight_inset_y = 3,
    cursor_offset_x = 16,
    cursor_offset_y = 4,
  }
end

--=====================================================
-- Interaction (A/confirm talks to NPC)
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end
  if event.button ~= 0 then return end -- A / confirm

  local player_id = event.player_id
  if Dialogue.is_active(player_id) then return end

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  --=====================================================
  -- Open the vertical prompt menu
  --=====================================================
  PromptVertical.menu(player_id, {
    ui = build_ui_config("prog_vert_prompt_box"),
    layout = build_layout_config(),

    question = "Hey! Select one of my options for... Stuff.",
    options = build_options(),
    default_index = 1,

    cancel_behavior = "jump_to_exit",
    exit_index = 1000,

    keep_textbox = true,

    --=====================================================
    -- When the player selects an option:
    -- Reuse the existing textbox AND keep the mugshot consistent.
    --=====================================================
    on_select = function(choice, index)
      Dialogue.start(player_id, {
        "You picked: " .. tostring(choice.text) .. " (index " .. tostring(index) .. ")",
      }, {
        reuse_existing_box = true,

        -- IMPORTANT: include UI here too, so reuse looks identical
        ui = build_ui_config("prog_vert_prompt_box"),
      })
    end,
  })
end)
