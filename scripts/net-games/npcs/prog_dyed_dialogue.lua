local Talk = require("scripts/net-games/npcs/talk")

Talk.npc({
  object = "ProgDyedDialogue",  -- Tiled object name
  name   = "Dyed Prog",

  box    = "panel",
  mug    = "prog",
  frame  = "lime", -- this triggers textbox_panel_frame_tint + tint values

  lines = {
    "Hey!{p_0.5} Look at that!",
    "Dyed frames!",
    "What a neat trick...",
  },
  ui = { nameplate = { debug = false } }

})
