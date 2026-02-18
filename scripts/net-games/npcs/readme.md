============================================================
NET-GAMES NPC AUTHORING GUIDE
(Simple, Practical, Zero Nonsense)
============================================================

This guide explains how to author NPCs in net-games using the
Talk system — from the most basic dialogue NPC to fully featured
vertical menu NPCs.

This is written as a HOW-TO, not engine documentation.
You should be able to skim this and immediately start scripting.

------------------------------------------------------------
CORE IDEA
------------------------------------------------------------

You do NOT write everything from scratch.

You choose a level of complexity and stop when it fits your NPC.

There is no “wrong” level.
More complex layers only exist to save time and prevent bugs.

------------------------------------------------------------
THE FOUR NPC LEVELS
------------------------------------------------------------

1) Simple dialogue NPC  
2) Yes / No prompt NPC  
3) Vertical menu NPC  
4) Fully condensed vertical menu NPC  

Each level builds on the previous one.

------------------------------------------------------------
MENTAL MODEL (IMPORTANT)
------------------------------------------------------------

Think in layers:

- Talk.lua  
  Handles dialogue flow, prompts, safety, and input.

- TalkPresets.lua  
  Defines look, feel, timing, fonts, and defaults.

- TalkVertMenu.lua  
  Owns all vertical menu behavior and edge cases.

- NPC scripts  
  Define content, options, and reactions.

NPC scripts should focus on:
- What the NPC says
- What choices exist
- What happens when chosen

NPC scripts should NOT focus on:
- Input guards
- Menu math
- Sound plumbing
- UI lifecycle bugs

------------------------------------------------------------
AUTHORING RULE (VERY IMPORTANT)
------------------------------------------------------------

All author-facing dialogue lives in ONE place:

  texts = { ... }

This keeps NPC scripts readable top-to-bottom.
You should never have to scroll around to understand dialogue.

------------------------------------------------------------
LEVEL 1: SIMPLE DIALOGUE NPC
------------------------------------------------------------

Use this when:
- NPC only talks
- No prompts
- No menus

Example:

------------------------------------------------------------
Talk.start(player_id, {
  "Hey.",
  "I'm just here to talk.",
  "Nothing fancy.",
}, cfg, bot_name)
------------------------------------------------------------

Rules:
- Text order = read order
- Talk handles indicators and input
- You control the content only

------------------------------------------------------------
LEVEL 2: YES / NO PROMPT NPC
------------------------------------------------------------

Use this when:
- NPC asks a question
- Player chooses Yes or No

Example structure:

------------------------------------------------------------
Talk.prompt_yesno(player_id, "Wanna proceed?", cfg, bot_name, {
  on_yes = function()
    Talk.start(player_id, { "Nice choice." }, cfg, bot_name)
  end,

  on_no = function()
    local next_cfg = shallow_copy(cfg)
    next_cfg.from_prompt = true
    next_cfg.reuse_existing_box = true

    Talk.start(player_id, { "Maybe next time." }, next_cfg, bot_name)
  end,
})
------------------------------------------------------------

Critical rule:
If dialogue follows a prompt, always set:
- from_prompt = true
- reuse_existing_box = true

This prevents indicator and input bugs.

------------------------------------------------------------
LEVEL 3: VERTICAL MENU NPC
------------------------------------------------------------

Use this when:
- NPC opens a menu
- Menu options matter
- Confirm and exit behavior matters

At this level, menus exist but require more wiring.
This is fine for custom or experimental NPCs.

------------------------------------------------------------
LEVEL 4: FULLY CONDENSED VERTICAL MENU NPC
------------------------------------------------------------

This is the recommended default.

Use this when:
- You want minimal code
- You want safety by default
- You want everything readable at a glance

Example:

------------------------------------------------------------
Talk.vert_menu(player_id, bot_name, cfg, {
  options = {
    count = 40,
    prefix = "Red Option ",
    pad = 2,
    exit_text = "Exit",
    exit_id = "exit",
  },

  texts = {
    open_question = "Do you wanna check out the vertical menu?",
    intro_text    = "Pick whatever you like.",
    decline_open  = "No worries. Maybe next time.",

    confirm_format     = 'Are you sure you want "%s"?',
    post_select_format = 'You got "%s".',

    after_yes    = "Anything else?",
    after_no     = "All good?",
    exit_goodbye = "Thanks for stopping by!",
  },

  sfx    = "card_desc",
  layout = "prog_prompt",
  flow   = "prog_prompt",
})
------------------------------------------------------------

What this gives you automatically:
- Menu generation
- Exit handling
- Confirm prompts
- Post-select text
- Safe input timing
- Menu reopen logic
- Proper sound playback

------------------------------------------------------------
MENU OPTIONS
------------------------------------------------------------

COUNT-BASED MENU:

------------------------------------------------------------
options = {
  count = 10,
  prefix = "Option ",
  pad = 2,
  exit_text = "Exit",
}
------------------------------------------------------------

LIST-BASED MENU:

------------------------------------------------------------
options = {
  list = { "Potion", "Antidote", "Escape Rope" },
  exit_text = "Exit",
}
------------------------------------------------------------

Exit is always auto-added.
You never need to calculate indices.

------------------------------------------------------------
SFX USAGE
------------------------------------------------------------

Preset-based (recommended):

------------------------------------------------------------
sfx = "card_desc"
------------------------------------------------------------

Custom paths:

------------------------------------------------------------
sfx = {
  desc    = "/server/assets/net-games/sfx/open.ogg",
  confirm = "/server/assets/net-games/sfx/confirm.ogg",
  close   = "/server/assets/net-games/sfx/close.ogg",
}
------------------------------------------------------------

------------------------------------------------------------
OVERRIDES (ESCAPE HATCH)
------------------------------------------------------------

You may override layout, flow, or behavior if needed.
Doing so does NOT disable the wrapper.

------------------------------------------------------------
COMMON RULES (MEMORIZE THESE)
------------------------------------------------------------

1) Object name must match the Tiled object
2) Dialogue lives in texts = { }
3) Presets control visuals, not dialogue
4) Use condensed menus unless you need custom behavior
5) Chain dialogue after prompts properly
6) Readability matters more than cleverness

------------------------------------------------------------
FINAL NOTE
------------------------------------------------------------

If an NPC script feels hard to read,
the structure is wrong.

If you’re writing boilerplate,
a higher-level layer already exists.

Keep scripts boring.
Let the system do the hard work.

============================================================
END OF GUIDE
============================================================
