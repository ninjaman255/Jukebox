--=====================================================
-- prog_talk_dialogue.lua
-- Example: PROG-style prompt that branches into dialogue
-- Uses NEW Talk.npc + presets + purple frame dye
--=====================================================

require("scripts/net-games/framework")

local Talk = require("scripts/net-games/npcs/talk")

-- EDIT THESE TWO if needed:
local AREA_ID = "default"              -- your map/area id
local OBJECT  = "prog_talk_prompt_npc" -- Tiled object name for this NPC

Talk.npc({
  area_id = AREA_ID,
  object  = OBJECT,

  -- Bot display name (also becomes the nameplate text by default)
  name = "PROG",

  -- Use your PROG UI defaults
  preset = "prog_prompt",

  -- Dye the textbox frame overlay purple (uses textbox_panel_frame_tint)
  frame = "purple",

  -- Optional: override anything instantly if you want
  -- ui = {
  --   mugshot = { enabled = false },
  -- },

  -- Prompt flow (Yes/No)
  prompt = {
    question = "Want to see the purple UI prompt in action?",

    yes_lines = {
      "Nice.",
      "This is the YES branch.",
      "Typing speed + open timing should match the PROG defaults.",
      "{end_page}And it should reuse the same textbox (no flicker).",
    },

    no_lines = {
      "All good.",
      "This is the NO branch.",
      "B should behave like BN prompt cancel: selects No, then confirms No.",
    },
  },
})

return true
