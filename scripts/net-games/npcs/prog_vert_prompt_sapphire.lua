--=====================================================
-- prog_vert_prompt_sapphire.lua
-- Flow:
--   Interact ->
--     YES/NO prompt: "Do you wanna check out the vertical menu?"
--       YES ->
--         SAME textbox becomes:
--           "Awesome. Let me know if there's anything that you like."
--         Vertical menu opens while that line prints,
--         and menu control unlocks after printing finishes.
--       NO ->
--         short line (same textbox)
--
-- Assumes prompt_vertical.lua supports reuse_existing_box reset.
--=====================================================

local Direction = require("scripts/libs/direction")
require("scripts/net-games/dialogue/startup")

local Dialogue       = require("scripts/net-games/dialogue/dialogue")
local Prompt         = require("scripts/net-games/dialogue/prompt")
local PromptVertical = require("scripts/net-games/dialogue/prompt_vertical")
local TalkPresets    = require("scripts/net-games/npcs/talk_presets")

--=====================================================
-- Area / placement (must match your TMX object name)
--=====================================================
local area_id  = "default"
local obj_name = "ProgVertPromptSapphire" -- Tiled object with THIS exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_vert_prompt_sapphire] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

--=====================================================
-- Bot creation
--=====================================================
local bot_id = Net.create_bot({
  name = "SAPPHIRE PROMPT PROG",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow_sapphire.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

local BOT_NAME = Net.get_bot_name(bot_id)

--=====================================================
-- Presets
--=====================================================
local SAPPHIRE_FRAME = TalkPresets.frames.sapphire
local SAPPHIRE_MUG   = TalkPresets.mugs.prog_sapphire

local function copy_frame_preset(preset)
  if type(preset) ~= "table" then return nil end
  return {
    r = preset.r, g = preset.g, b = preset.b, a = preset.a,
    color_mode = preset.color_mode,
  }
end

local FRAME = copy_frame_preset(SAPPHIRE_FRAME)

--=====================================================
-- Menu options
--=====================================================
local function build_options()
  local t = {}
  for i = 1, 40 do
    t[#t+1] = { id = i, text = ("Sapphire Option %02d"):format(i) }
  end
  t[#t+1] = { id = "exit", text = "Exit" }
  return t
end

--=====================================================
-- Shared UI config (textbox + nameplate + mug)
--=====================================================
local function build_ui_config(box_id)
  return {
    box_id = box_id,

    font = "THIN_BLACK",
    scale = 2.0,
    z = 100,
    typing_speed = 12,
    type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
    type_sfx_min_dt = 0.05,

    mugshot = {
      enabled = true,
      texture_path = SAPPHIRE_MUG.texture_path,
      anim_path = SAPPHIRE_MUG.anim_path,
      talk_anim_state = SAPPHIRE_MUG.talk_anim_state,
      idle_anim_state = SAPPHIRE_MUG.idle_anim_state,
      reserve_w = SAPPHIRE_MUG.reserve_w,
      reserve_h = SAPPHIRE_MUG.reserve_h,
      offset_x  = SAPPHIRE_MUG.offset_x,
      offset_y  = SAPPHIRE_MUG.offset_y,
      gap_px    = SAPPHIRE_MUG.gap_px,
      sprite_id = SAPPHIRE_MUG.sprite_id,
      z_bias    = SAPPHIRE_MUG.z_bias,
    },

    -- Textbox frame tint (same as your dye system)
    backdrop = {
      render_offset_x = 3,
      render_offset_y = 46,

      style = "textbox_panel_frame_tint",
      open_seconds = 0.20,
      close_seconds = 0.25,

      r = FRAME.r,
      g = FRAME.g,
      b = FRAME.b,
      a = FRAME.a,
      color_mode = FRAME.color_mode,

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
      },
    },

    -- Nameplate frame dye
    nameplate = {
      frame = FRAME,

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
-- Vertical menu layout (frame overlay dye uses layout.frame)
--=====================================================
local function build_layout_config()
  return {
    anchor = "textbox",
    offset_x = 1,
    offset_y = -199,

    width = 160,
    height = 64,

    frame = FRAME,

    visible_rows = 5,
    row_height = 14,
    padding_x = 48,
    padding_y = 4,

    scrollbar_x = 452,
    scrollbar_y = 12,
    scrollbar_h = 126,

    scroll_indicator_h = 12,

    highlight_inset_x = 12,
    highlight_inset_y = 3,
    cursor_offset_x = 16,
    cursor_offset_y = 4,
  }
end

--=====================================================
-- Open the vertical menu.
-- NOTE: reuse_existing_box=true is what forces the textbox text to change
-- from the YES/NO prompt into the new "Awesome..." line.
--=====================================================
local function open_vertical_menu(player_id, intro_text)
  PromptVertical.menu(player_id, {
    reuse_existing_box = true,

    ui = build_ui_config("prog_vert_sapphire_box"),
    layout = build_layout_config(),

    question = intro_text or "Pick anything you like.",
    options = build_options(),
    default_index = 1,

    cancel_behavior = "jump_to_exit",
    exit_index = 41,

    keep_textbox = true,

    on_select = function(choice, index)
      Dialogue.start(player_id, {
        "You picked: " .. tostring(choice.text) .. " (index " .. tostring(index) .. ")",
      }, {
        reuse_existing_box = true,
        ui = build_ui_config("prog_vert_sapphire_box"),
      })
    end,
  })
end

--=====================================================
-- Interaction
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end
  if event.button ~= 0 then return end -- A / confirm

  local player_id = event.player_id
  if Dialogue.is_active(player_id) then return end

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  Prompt.yesno(player_id, {
    ui = build_ui_config("prog_vert_sapphire_box"),
    question = "Do you wanna check out the vertical menu?",

    on_yes = function()
      open_vertical_menu(player_id, "Awesome. Let me know if there's anything that you like.")
    end,

    on_no = function()
      Dialogue.start(player_id, {
        "No worries. Maybe next time.",
      }, {
        reuse_existing_box = true,
        ui = build_ui_config("prog_vert_sapphire_box"),
        from_prompt = true,
      })
    end,

    cancel_behavior = "select_no",
  })
end)
