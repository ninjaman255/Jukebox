--=====================================================
-- prog_vert_prompt_red.lua
-- Max-condensed example:
-- - no Net:on in this file
-- - no TalkVertMenu.open in this file
-- - no SFX table in this file
-- - no exit_index math in this file
-- - full content control remains here
--=====================================================

local Talk = require("scripts/net-games/npcs/talk")

Talk.npc({
  area_id = "default",
  object  = "ProgVertPromptRed", -- add this object name in Tiled
  name    = "RED PROMPT PROG",

  texture_path   = "/server/assets/ow/prog/prog_ow_red.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",

  preset = "prog_prompt",
  frame  = "red",
  mug    = "prog_red",
  nameplate = "prog", 

  on_interact = function(player_id, _bot_id, bot_name)
    Talk.vert_menu(player_id, bot_name, {
      area_id = "default",
      object  = "ProgVertPromptRed",
      preset  = "prog_prompt",
      frame   = "red",
      mug     = "prog_red",
      nameplate = "prog",
    }, {
      -- ultra-short options spec: count + auto Exit
      options = { count = 99, prefix = "Red Option ", pad = 2, exit_text = "Exit", exit_id = "exit" },

      -- overrideable content strings live here (NOT in presets)
      -- (Preferred author format: keep *all* text in one place.)
      texts = {
        open_question = "Do you wanna check out the vertical menu?",
        intro_text    = "Awesome. Let me know if there's anything that you like.",
        decline_open  = "No worries. Maybe next time.",

        confirm_format     = 'Are you sure you want "%s"?',
        post_select_format = 'You got "%s".',

        after_yes    = "Thank you!{p_1} Is there anything else you'd like?",
        after_no     = "No worries. Anything else?",
        exit_goodbye = "Thanks for stopping by!",
      },

      sfx = "card_desc",
      flow = "prog_prompt",
      layout = "prog_prompt",
    })
  end,
})
