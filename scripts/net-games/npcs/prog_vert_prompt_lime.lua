--=====================================================
-- prog_vert_prompt_lime.lua
--
-- LIME variant of prog_vert_prompt_pink.lua.
--
-- Key requirement: identical in-game flow, but implemented
-- using Talk.lua + TalkVertMenu.lua (reusable wrapper).
--=====================================================

local Direction = require("scripts/libs/direction")
require("scripts/net-games/dialogue/startup")

local Dialogue     = require("scripts/net-games/dialogue/dialogue")
local Talk         = require("scripts/net-games/npcs/talk")
local TalkVertMenu = require("scripts/net-games/npcs/talk_vert_menu")
local TalkPresets = require("scripts/net-games/npcs/talk_presets")

--=====================================================
-- SFX (same as Pink)
--=====================================================
local SFX = {
  DESC        = "/server/assets/net-games/sfx/card_desc.ogg",
  CONFIRM     = "/server/assets/net-games/sfx/card_confirm.ogg",
  DESC_CLOSE  = "/server/assets/net-games/sfx/card_desc_close.ogg",
}

local function play_sfx(player_id, path)
  if not path then return end
  Net.provide_asset_for_player(player_id, path)

  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, path) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(path) end)
  end
end

local function shallow_copy(t)
  local o = {}
  if t then for k, v in pairs(t) do o[k] = v end end
  return o
end

--=====================================================
-- Area / placement (must match your TMX object name)
--=====================================================
local area_id  = "default"
local obj_name = "ProgVertPromptLime" -- Tiled object with THIS exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_vert_prompt_lime] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

--=====================================================
-- Bot creation
--=====================================================
local bot_id = Net.create_bot({
  name = "LIME PROMPT PROG",
  area_id = area_id,
  -- NOTE: mirrors the Pink naming convention (/server/assets/ow/prog/prog_ow_<color>.png)
  texture_path = "/server/assets/ow/prog/prog_ow_lime.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

local BOT_NAME = Net.get_bot_name(bot_id)

--=====================================================
-- Shared Talk config (stable box id + dyed frame + mug)
--=====================================================
local TALK_CFG = {
  area_id = area_id,
  object = obj_name,
  box_id = "prog_vert_lime_box",

  preset = "prog_prompt",
  frame = "lime",
  mug = "prog_lime",
  nameplate = "prog",
}

--=====================================================
-- Menu options
--=====================================================
local function build_options()
  local t = {}
  for i = 1, 40 do
    t[#t + 1] = { id = i, text = ("Lime Option %02d"):format(i) }
  end
  t[#t + 1] = { id = "exit", text = "Exit" }
  return t
end

--=====================================================
-- Interaction
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end
  if event.button ~= 0 then return end -- A / confirm

  local player_id = event.player_id

  -- Global busy guard (prevents prompt/menu spam + close-window softlocks)
  if TalkVertMenu.is_busy(player_id) then return end
  if Dialogue.is_active(player_id) then return end

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  Talk.prompt_yesno(player_id, "Do you wanna check out the vertical menu?", TALK_CFG, BOT_NAME, {
    on_yes = function()
      -- Match Pink: selecting YES to enter the menu plays the desc SFX.
      play_sfx(player_id, SFX.DESC)

      TalkVertMenu.open(player_id, BOT_NAME, TALK_CFG, {
        intro_text = "Awesome. Let me know if there's anything that you like.",
        options = build_options(),
        default_index = 1,
        cancel_behavior = "jump_to_exit",
        exit_index = 41,

        
        layout = TalkPresets.get_vert_menu_layout("prog_prompt"),

        -- Flow mirrors MENU_FLOW in prog_vert_prompt_pink.lua
        flow = {
          keep_menu_open = true,
          lock_dim_alpha = 0.35,
          hide_cursor_when_locked = true,

          confirm = {
            enabled = true,
            text_format = 'Are you sure you want "%s"?',
            skip_ids = { exit = true },
          },

          post_select = {
            enabled = true,
            text_format = 'You got "%s".',
            skip_ids = { exit = true },
          },

          after_yes_text = "Thank you!{p_1} Is there anything else you'd like?",
          after_no_text = "Is there anything else you'd like?",

          exit_goodbye_text = "Thanks for stopping by!",

          sfx = {
            desc = SFX.DESC,
            confirm = SFX.CONFIRM,
            close = SFX.DESC_CLOSE,
          },
        },
      })
    end,

    on_no = function()
      local next_cfg = shallow_copy(TALK_CFG)
      next_cfg.from_prompt = true
      next_cfg.reuse_existing_box = true

      Talk.start(player_id, { "No worries. Maybe next time." }, next_cfg, BOT_NAME)
    end,

    on_cancel = nil,
  })
end)
