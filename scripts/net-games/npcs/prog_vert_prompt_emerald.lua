--=====================================================
-- prog_vert_prompt_emerald_shop.lua
-- Shop-themed variant of ProgVertPromptRed:
-- - identical flow + option generator
-- - overrides PromptVertical assets ONLY for this NPC instance
--=====================================================

local Talk = require("scripts/net-games/npcs/talk")

Talk.npc({
  area_id = "default",
  object  = "ProgVertPromptEmeraldShop", -- add this object name in Tiled
  name    = "EMERALD SHOP PROG",

  -- Use whatever OW sprite you want here (emerald if you have it)
  -- If you don't have an emerald OW sprite yet, you can temporarily point to red.
  texture_path   = "/server/assets/ow/prog/prog_ow_emerald.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",

  preset = "prog_prompt",
  frame  = "emerald",     -- make sure you have this frame/mug/nameplate mapping in your presets
  mug    = "prog_emerald", -- and this mug too (or swap to one you know exists)
  nameplate = "prog",

  on_interact = function(player_id, _bot_id, bot_name)
    Talk.vert_menu(player_id, bot_name, {
      area_id = "default",
      object  = "ProgVertPromptEmeraldShop",
      preset  = "prog_prompt",
      frame   = "emerald",
      mug     = "prog_emerald",
      nameplate = "prog",
    }, {
      -- ultra-short options spec: count + auto Exit
      options = { count = 99, prefix = "Item ", pad = 2, exit_text = "Exit", exit_id = "exit" },

      -- overrideable content strings live here (NOT in presets)
      texts = {
        open_question = "Welcome! Wanna browse the shop menu?",
        intro_text    = "Take your time. I won't judge your impulse buys.",
        decline_open  = "No worries. Window shopping is still shopping.",

        confirm_format     = 'Buy "%s"?',
        post_select_format = 'You bought "%s".',

        after_yes    = "Nice!{p_1} Anything else catch your eye?",
        after_no     = "Fair. Anything else?",
        exit_goodbye = "Thanks for stopping by!",
      },

      -- This is the ONLY new piece you need for the shop UI skin:
      -- It swaps the menu BG/frame/highlight for this NPC instance only.
      assets = {
        menu_bg       = "/server/assets/net-games/ui/prompt_vert_menu_shop_an.png",
        menu_bg_anim  = "/server/assets/net-games/ui/prompt_vert_menu_an.animation",
        menu_bg_frame = "/server/assets/net-games/ui/prompt_vert_menu_shop_an_frame.png",
        highlight     = "/server/assets/net-games/ui/highlight_shop.png",
      },

      sfx = "card_desc",
      flow = "prog_prompt",
      layout = "prog_prompt_shop",
    })
  end,
})
