--=====================================================
-- prog_vert_prompt_charcoal_grey.lua
--
-- New NPC that mirrors Lime/Pink vertical menu flow,
-- but uses the new helpers:
--   - npc_api.lua (bind interaction + guards + face + sfx)
--   - menu_options.lua (count/list -> options table)
--=====================================================

local NPC         = require("scripts/net-games/npcs/npc_api")
local MenuOptions = require("scripts/net-games/npcs/menu_options")

local Direction   = require("scripts/libs/direction")

local Talk         = require("scripts/net-games/npcs/talk")
local TalkVertMenu = require("scripts/net-games/npcs/talk_vert_menu")
local TalkPresets  = require("scripts/net-games/npcs/talk_presets")

--=====================================================
-- SFX (same set as Pink/Lime)
--=====================================================
local SFX = {
  DESC        = "/server/assets/net-games/sfx/card_desc.ogg",
  CONFIRM     = "/server/assets/net-games/sfx/card_confirm.ogg",
  DESC_CLOSE  = "/server/assets/net-games/sfx/card_desc_close.ogg",
}

--=====================================================
-- Area / placement (must match your TMX object name)
--=====================================================
local area_id  = "default"
local obj_name = "ProgVertPromptCharcoalGrey" -- add this object name in Tiled

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_vert_prompt_charcoal_grey] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

--=====================================================
-- Bot creation
--=====================================================
local bot_id = Net.create_bot({
  name = "GREY PROMPT PROG",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow_charcoal_grey.png",
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
  box_id = "prog_vert_charcoal_box",

  preset = "prog_prompt",
  frame = "charcoal_grey",      -- frame dye exists in presets
  mug = "prog_charcoal_grey",   -- mug key exists in presets
  nameplate = "prog",
}

--=====================================================
-- Options (40 + Exit)
--=====================================================
local OPTIONS = MenuOptions.count(40, {
  prefix = "Grey Option ",
  pad = 2,
  exit_text = "Exit",
  exit_id = "exit",
})

local EXIT_INDEX = 41

--=====================================================
-- Interaction
--=====================================================
NPC.bind_confirm_interaction(bot_id, bot_pos, function(player_id)
  Talk.prompt_yesno(player_id, "Do you wanna check out the vertical menu?", TALK_CFG, BOT_NAME, {
    on_yes = function()
      -- Match Pink/Lime: opening menu plays DESC
      NPC.play_sfx(player_id, SFX.DESC)

      TalkVertMenu.open(player_id, BOT_NAME, TALK_CFG, {
        intro_text = "Understood. Select an entry.",
        options = OPTIONS,
        default_index = 1,
        cancel_behavior = "jump_to_exit",
        exit_index = EXIT_INDEX,

        -- Use the same known-good layout preset (Pink parity)
        layout = TalkPresets.get_vert_menu_layout("prog_prompt"),

        -- Same flow behavior as Lime/Pink
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

          -- YES vs NO follow-up lines (the bug you fixed)
          after_yes_text = "Confirmed.{p_0.2} Thank you.",
          after_no_text  = "Understood.",

          exit_goodbye_text = "Signal closed.",

          sfx = {
            desc = SFX.DESC,
            confirm = SFX.CONFIRM,
            close = SFX.DESC_CLOSE,
          },
        },
      })
    end,

    on_no = function()
      local next_cfg = {
        area_id = TALK_CFG.area_id,
        object = TALK_CFG.object,
        box_id = TALK_CFG.box_id,
        preset = TALK_CFG.preset,
        frame = TALK_CFG.frame,
        mug = TALK_CFG.mug,
        nameplate = TALK_CFG.nameplate,
      }

      next_cfg.from_prompt = true
      next_cfg.reuse_existing_box = true

      Talk.start(player_id, { "No worries. Maybe next time." }, next_cfg, BOT_NAME)
    end,

  })
end, { face = true })
