--=====================================================
-- prog_talk_colors.lua
-- PROG talk NPCs: one per frame dye color
-- Tiled object names must be: prog_{color}
--=====================================================

require("scripts/net-games/framework")

local Talk = require("scripts/net-games/npcs/talk")

local AREA_ID = "default"

local OW_COLOR_DIR = "/server/assets/ow/prog/"

local function ow(color)
  return OW_COLOR_DIR .. "prog_ow_" .. color .. ".png"
end


--=====================================================
-- prog_default
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_default",
  name    = "DEFAULT PROG",
  preset  = "prog_prompt",
  lines = {
    "{end_page}DEFAULT PROG ONLINE{p_2}",
    "{end_line} ",
    "SIR,{p_2.2} This is the very definition of overkill.{p_0.2}.{p_0.4}.{p_0.8}",
    "{end_page}BUT LETS TAKE A LOOK SHALL WE?!",
  },
})

--=====================================================
-- prog_lime
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_lime",
  name    = "LIME PROG",
  preset  = "prog_prompt",
  frame   = "lime",
  texture_path = ow("lime"),
  mug = "prog_lime", 
  lines = {
    "LIME PROG ONLINE.",
    "Everything is GO.{p_0.2} Fast.{p_0.2} Clean.{p_0.2} Alive.",
    "{end_page}If you need momentum, borrow mine.",
  },
})

--=====================================================
-- prog_red (PROMPT)
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_red",
  name    = "RED PROG",
  preset  = "prog_prompt",
  frame   = "red",
  texture_path = ow("red"),
  mug = "prog_red", 
  prompt = {
    question = "RED PROG READY. PUSH HARD?",

    yes_lines = {
      "Yes confirmed.",
      "We move fast.",
      "We break things on purpose.",
      "{end_page}If it matters, we do it now.",
    },

    no_lines = {
      "Copy that.",
      "Holding position.",
      "{end_page}Pressure stays on standby.",
    },
  },
})

--=====================================================
-- prog_purple
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_purple",
  name    = "PURPLE PROG",
  preset  = "prog_prompt",
  frame   = "purple",
  texture_path = ow("purple"),
  mug = "prog_purple", 
  lines = {
    "PURPLE PROG speaking.",
    "Mystery is just data wearing a cloak.",
    "{end_page}Keep staring.{p_0.2} Patterns confess eventually.",
  },
})

--=====================================================
-- prog_turquoise
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_turquoise",
  name    = "TURQUOISE PROG",
  preset  = "prog_prompt",
  frame   = "turquoise",
  texture_path = ow("turquoise"),
  mug = "prog_turquoise", 
  lines = {
    "TURQUOISE PROG online.",
    "Breathe.{p_0.3} Smooth inputs.{p_0.3} Smooth outputs.",
    "{end_page}No rush. We still win.",
  },
})

--=====================================================
-- prog_pink
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_pink",
  name    = "PRETTY PINK PROG",
  preset  = "prog_prompt",
  frame   = "pink",
  texture_path = ow("pink"),
  mug = "prog_pink", 
  lines = {
    "PINK PROG reporting in.",
    "I made the UI cute so the bugs feel bad about existing.",
    "{end_page}It's working.{p_0.2} You're allowed to be proud.",
  },
})

--=====================================================
-- prog_emerald
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_emerald",
  name    = "EMERALD PROG",
  preset  = "prog_prompt",
  frame   = "emerald",
  texture_path = ow("emerald"),
  mug = "prog_emerald", 
  lines = {
    "EMERALD PROG operational.",
    "Stable.{p_0.2} Grounded.{p_0.2} Built to last.",
    "{end_page}We don't just ship.{p_0.2} We endure.",
  },
})

--=====================================================
-- prog_sapphire
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_sapphire",
  name    = "SAPPHIRE PROG",
  preset  = "prog_prompt",
  frame   = "sapphire",
  texture_path = ow("sapphire"),
  mug = "prog_sapphire", 
  lines = {
    "SAPPHIRE PROG here.",
    "Cool head.{p_0.2} Clear eyes.{p_0.2} Clean diff.",
    "{end_page}If it looks haunted, we log it until it apologizes.",
  },
})

--=====================================================
-- prog_yellow
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_yellow",
  name    = "YELLOW PROG",
  preset  = "prog_prompt",
  frame   = "yellow",
  texture_path = ow("yellow"),
  mug = "prog_yellow", 
  lines = {
    "YELLOW PROG online.",
    "Good news:{p_0.2} it's bright for a reason.",
    "{end_page}Spot the issue.{p_0.2} Tag it.{p_0.2} Fix it.{p_0.2} Celebrate.",
  },
})

--=====================================================
-- prog_orange
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_orange",
  name    = "SAFETY ORANGE PROG",
  preset  = "prog_prompt",
  frame   = "orange",
  texture_path = ow("orange"),
  mug = "prog_orange", 
  lines = {
    "ORANGE PROG active.",
    "I run hot.{p_0.2} I move fast.{p_0.2} I break walls.",
    "{end_page}Point me at the problem and stand back.",
  },
})

--=====================================================
-- prog_charcoal_grey (PROMPT)
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_charcoal_grey",
  name    = "GREY PROG",
  preset  = "prog_prompt",
  frame   = "charcoal_grey",
  texture_path = ow("charcoal_grey"),
  mug = "prog_charcoal_grey", 

  prompt = {
    question = "CHARCOAL PROG READY. SHIP NOW?",

    yes_lines = {
      "Confirmed.",
      "No noise.",
      "No drama.",
      "{end_page}We ship.",
    },

    no_lines = {
      "Understood.",
      "Holding for clarity.",
      "{end_page}Signal stays clean.",
    },
  },
})

--=====================================================
-- prog_white
--=====================================================
Talk.npc({
  area_id = AREA_ID,
  object  = "prog_white",
  name    = "WHITE PROG",
  preset  = "prog_prompt",
  frame   = "white",
  texture_path = ow("white"),
  mug = "prog_white", 
  lines = {
    "WHITE PROG reporting.",
    "Baseline check:{p_0.2} no tricks.{p_0.2} no tint lies.",
    "{end_page}If this breaks, something else is VERY wrong.",
  },
})

return true
