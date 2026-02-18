--=====================================================
-- talk.lua
-- Minimal author API for Dialogue NPCs with PROG-default UI
--=====================================================

local Direction = require("scripts/libs/direction")
local Dialogue  = require("scripts/net-games/dialogue/dialogue")
local Presets   = require("scripts/net-games/npcs/talk_presets")
local MenuOptions  = require("scripts/net-games/npcs/menu_options")

local Talk = {}

--=====================================================
-- Small table helpers
--=====================================================
local function shallow_copy(t)
  local o = {}
  if t then for k, v in pairs(t) do o[k] = v end end
  return o
end

local function deep_merge(dst, src)
  if not src then return dst end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deep_merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function normalize_script(lines_or_text)
  if type(lines_or_text) == "string" then
    return { lines_or_text }
  elseif type(lines_or_text) == "table" then
    return lines_or_text
  end
  return { "..." }
end

local function stable_box_id(cfg)
  if cfg.box_id then return tostring(cfg.box_id) end
  local area = tostring(cfg.area_id or "default")
  local obj  = tostring(cfg.object or "npc")
  return "talk_" .. area .. "_" .. obj
end

local function force_indicator_on(player_id, box_id)
  if not (Displayer and Displayer.Text and Displayer.Text.getTextBoxData) then return end
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if bd and bd.backdrop and bd.backdrop.indicator then
    bd.backdrop.indicator.enabled = true
  end
end

local function get_talk_vert_menu()
  -- Lazy require to avoid require-cycle:
  -- talk.lua <-> talk_vert_menu.lua
  return require("scripts/net-games/npcs/talk_vert_menu")
end

--=====================================================
-- build_ui(cfg, bot_name, opts)
-- opts.mode = "dialogue" | "prompt"
--=====================================================
local function build_ui(cfg, bot_name, opts)
  opts = opts or {}

  -- 1) Choose pack (default = prog)
  local pack_key = cfg.preset or cfg.pack or "prog"
  local pack = Presets.packs[pack_key] or Presets.packs.prog

  -- 2) Choose component presets
  local box_key = cfg.box or pack.box or "panel"
  local mug_key = cfg.mug or pack.mug
  local np_key  = cfg.nameplate or pack.nameplate

  local ui = {}

  -- Box (base)
  local box = Presets.boxes[box_key] or Presets.boxes.panel
  deep_merge(ui, shallow_copy(box))

  -- IMPORTANT: keep a real table instance for backdrop (and its nested indicator table)
  ui.backdrop = shallow_copy(box.backdrop)
  deep_merge(ui.backdrop, box.backdrop)

  -- Frame dye optional: switches backdrop style + applies tint values
  -- We ALSO want to propagate this to the nameplate (later), so keep a resolved table.
  local resolved_frame = nil
  if cfg.frame then
    local frame = Presets.frames[cfg.frame] or cfg.frame
    ui.backdrop.style = "textbox_panel_frame_tint"
    if type(frame) == "table" then
      ui.backdrop.r = frame.r
      ui.backdrop.g = frame.g
      ui.backdrop.b = frame.b
      ui.backdrop.a = frame.a
      ui.backdrop.color_mode = frame.color_mode
      resolved_frame = frame
    end
  end

  -- Mugshot
  if mug_key == false then
    ui.mugshot = nil
  elseif mug_key then
    local mug = Presets.mugs[mug_key] or mug_key
    if type(mug) == "table" then
      ui.mugshot = shallow_copy(mug)
    end
  end

  -- Nameplate
  if np_key == false then
    ui.nameplate = nil
  elseif np_key then
    local np = Presets.nameplates[np_key] or np_key
    if type(np) == "table" then
      ui.nameplate = shallow_copy(np)
      ui.nameplate.text = ui.nameplate.text or bot_name

      -- NEW: if textbox frame dye was requested, apply same dye to nameplate overlay frame
      -- (your nameplate.lua reads ui.nameplate.frame.{r,g,b,a,color_mode})
      if resolved_frame then
        ui.nameplate.frame = ui.nameplate.frame or {}
        ui.nameplate.frame.r = resolved_frame.r
        ui.nameplate.frame.g = resolved_frame.g
        ui.nameplate.frame.b = resolved_frame.b
        ui.nameplate.frame.a = resolved_frame.a
        ui.nameplate.frame.color_mode = resolved_frame.color_mode
      end
    end
  end

  -- Stable box id (prompt + dialogue reuse)
  ui.box_id = stable_box_id(cfg)

  -- Per-NPC overrides (last)
  if cfg.ui then
    deep_merge(ui, cfg.ui)

    -- If someone overwrote nameplate, ensure text is still sane unless explicitly set
    if ui.nameplate and ui.nameplate.text == nil then
      ui.nameplate.text = bot_name
    end

    -- Keep stable id unless explicitly overwritten
    ui.box_id = ui.box_id or stable_box_id(cfg)
  end

  -- =====================================================
  -- INDICATOR SAFETY:
  -- Some configs accidentally replace backdrop without carrying indicator.
  -- We restore the preset indicator unless the author explicitly disabled it.
  -- =====================================================
  if ui.backdrop then
    local base_ind = box and box.backdrop and box.backdrop.indicator

    if ui.backdrop.indicator == nil and base_ind then
      ui.backdrop.indicator = shallow_copy(base_ind)
    end

    if ui.backdrop.indicator and ui.backdrop.indicator.enabled == nil then
      ui.backdrop.indicator.enabled = true
    end
  end

  return ui
end

--=====================================================
-- Vertical menu helpers (author-facing API)
--=====================================================

local function get_pack_from_cfg(cfg)
  local pack_key = cfg.preset or cfg.pack or "prog"
  return Presets.packs[pack_key] or Presets.packs.prog
end

local function resolve_layout(cfg, menu_cfg)
  local pack = get_pack_from_cfg(cfg)
  local v = menu_cfg.layout
  if v == nil then v = pack.vert_menu_layout end

  if type(v) == "string" then
    return Presets.get_vert_menu_layout(v) or {}
  elseif type(v) == "table" then
    return v
  end
  return {}
end

local function resolve_flow(cfg, menu_cfg)
  local pack = get_pack_from_cfg(cfg)
  local v = menu_cfg.flow
  if v == nil then v = pack.vert_menu_flow end

  local base = {}
  if type(v) == "string" then
    base = Presets.get_vert_menu_flow(v) or {}
  elseif type(v) == "table" then
    base = shallow_copy(v)
  end

  base.confirm = base.confirm or {}
  base.post_select = base.post_select or {}
  base.sfx = base.sfx or {}

  return base
end

local function resolve_sfx(cfg, menu_cfg)
  -- menu_cfg.sfx can be:
  --   - string key into Presets.sfx_sets
  --   - table {desc,confirm,close}
  --   - nil => pack default
  local pack = get_pack_from_cfg(cfg)
  local v = menu_cfg.sfx
  if v == nil then v = pack.vert_menu_sfx_set end

  if type(v) == "string" then
    return shallow_copy((Presets.sfx_sets and Presets.sfx_sets[v]) or {})
  elseif type(v) == "table" then
    return shallow_copy(v)
  end
  return {}
end

local function resolve_options(menu_cfg)
  -- menu_cfg.options can be:
  --   - full PromptVertical options array (already built)
  --   - { count = N, prefix=..., pad=..., start=..., exit_text=..., exit_id=... }
  --   - { list = { "A","B" }, exit_text=..., exit_id=... }
  local o = menu_cfg.options

  if type(o) ~= "table" then
    return { { id = "exit", text = "Exit" } }
  end

  if o.count then
    return MenuOptions.count(tonumber(o.count) or 1, o)
  end

  if o.list then
    return MenuOptions.list(o.list, o)
  end

  -- assume caller gave a real PromptVertical options array
  return o
end

local function infer_exit_index(options, explicit_exit_index)
  if explicit_exit_index then return explicit_exit_index end
  -- Prefer an option whose id == "exit" if present
  for i = #options, 1, -1 do
    if options[i] and options[i].id == "exit" then
      return i
    end
  end
  -- fallback: last option
  return #options
end


--=====================================================
-- Talk API (what authors should use)
--=====================================================

-- Talk.start(player_id, script, cfg, bot_name)
-- Most callers won't use this directly; Talk.npc() does.
function Talk.start(player_id, script, cfg, bot_name, extra_opts)
  cfg = cfg or {}
  local ui = build_ui(cfg, bot_name or (cfg.name or ""))
  local lines = normalize_script(script)

  local o = {
    page_advance = cfg.page_advance or "wait_for_confirm",
    confirm_during_typing = (cfg.confirm_during_typing ~= false),
    cancel_behavior = cfg.cancel_behavior or "battle_network",

    -- These matter mainly when chaining from prompts
    from_prompt = (cfg.from_prompt == true),
    reuse_existing_box = (cfg.reuse_existing_box == true),

    ui = ui,
    on_finish = cfg.on_finish,
    debug = cfg.debug,
  }

  if extra_opts then
    deep_merge(o, extra_opts)
  end

  -- Ensure indicator is ON if reusing existing box from prompt
  if o.from_prompt and o.reuse_existing_box and ui and ui.box_id then
    force_indicator_on(player_id, ui.box_id)
  end

  return Dialogue.start(player_id, lines, o)
end

-- Talk.prompt_yesno(player_id, question, cfg, bot_name, handlers)
-- handlers = { on_yes = fn, on_no = fn, on_cancel = fn }
function Talk.prompt_yesno(player_id, question, cfg, bot_name, handlers)
  cfg = cfg or {}
  handlers = handlers or {}
  local ui = build_ui(cfg, bot_name or (cfg.name or ""), { mode = "prompt" })

  return Dialogue.prompt_yesno(player_id, {
    question = question or "Continue?",
    cancel_behavior = cfg.prompt_cancel_behavior or cfg.cancel_behavior or "select_no",
    ui = ui,
    on_yes = handlers.on_yes,
    on_no = handlers.on_no,
    on_cancel = handlers.on_cancel,
  })
end

-- Talk.vert_menu(player_id, bot_name, cfg, menu_cfg)
-- Highest-level vertical menu wrapper:
-- - prompts yes/no to open (optional)
-- - opens TalkVertMenu with preset defaults
-- - allows full override of layout/flow/sfx/ui/mug/frame
function Talk.vert_menu(player_id, bot_name, cfg, menu_cfg)
  cfg = cfg or {}
  menu_cfg = menu_cfg or {}

  -- Guard: if either Dialogue or menu wrapper is busy, do nothing.
  if Dialogue.is_active(player_id) then return end
  local TalkVertMenu = get_talk_vert_menu()
  if TalkVertMenu.is_busy and TalkVertMenu.is_busy(player_id) then return end

  local ui = build_ui(cfg, bot_name or (cfg.name or ""), { mode = "prompt" })

  local options = resolve_options(menu_cfg)
  local exit_index = infer_exit_index(options, menu_cfg.exit_index)

  local layout = resolve_layout(cfg, menu_cfg)
  local flow = resolve_flow(cfg, menu_cfg)
  local sfx = resolve_sfx(cfg, menu_cfg)

  -- Apply SFX defaults into flow.sfx but allow caller to override per-call
  flow.sfx = flow.sfx or {}
  for k, v in pairs(sfx) do
    if flow.sfx[k] == nil then
      flow.sfx[k] = v
    end
  end

  -- Text/content:
  -- Back-compat + improved author ergonomics.
  --
  -- Authors may provide strings in either:
  --   A) Top-level keys (older call sites):
  --        menu_cfg.open_question, menu_cfg.intro_text
  --   B) A single menu_cfg.texts table (preferred):
  --        texts.open_question
  --        texts.open_yes (or texts.intro_text)
  --        texts.open_no  (or texts.decline_open)
  --        texts.confirm_format, texts.post_select_format, ...
  --
  -- This keeps NPC scripts readable and avoids jumping around.
  local texts = menu_cfg.texts or {}

  local function pick_text(...)
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "string" and v ~= "" then
        return v
      end
    end
    return nil
  end

  -- Alias support for author-friendly naming.
  -- (We keep both to preserve compatibility with existing NPC scripts.)
  local open_question_text = pick_text(menu_cfg.open_question, texts.open_question)
  local open_yes_text      = pick_text(menu_cfg.intro_text, texts.open_yes, texts.intro_text)
  local open_no_text       = pick_text(texts.open_no, texts.decline_open)

  flow.confirm = flow.confirm or {}
  flow.post_select = flow.post_select or {}

  if flow.confirm.text_format == nil then
    flow.confirm.text_format = texts.confirm_format or 'Are you sure you want "%s"?'
  end

  if flow.post_select.text_format == nil then
    flow.post_select.text_format = texts.post_select_format or 'You got "%s".'
  end

  if flow.after_yes_text == nil then
    flow.after_yes_text = texts.after_yes
  end
  if flow.after_no_text == nil then
    flow.after_no_text = texts.after_no
  end
  if flow.exit_goodbye_text == nil then
    flow.exit_goodbye_text = texts.exit_goodbye
  end

local function open_menu()
  TalkVertMenu.open(player_id, bot_name or (cfg.name or ""), cfg, {
    intro_text = open_yes_text or "...",
    options = options,
    default_index = menu_cfg.default_index or 1,
    cancel_behavior = menu_cfg.cancel_behavior or "jump_to_exit",
    exit_index = exit_index,

    layout = layout,
    flow = flow,

    assets = menu_cfg.assets,
  })
end


  -- Optional open prompt. If menu_cfg.open_question is nil/false, open immediately.
  local q = open_question_text
  if q == nil then q = "Do you wanna check out the vertical menu?" end


  if q == false then
    open_menu()
    return
  end

  Talk.prompt_yesno(player_id, q, cfg, bot_name, {
    on_yes = function()
      -- Pink/Lime parity: opening the menu plays the DESC sfx once
      local path = flow and flow.sfx and flow.sfx.desc
      if path then
        Net.provide_asset_for_player(player_id, path)
        if Net.play_sound_for_player then
          pcall(function() Net.play_sound_for_player(player_id, path) end)
        elseif Net.play_sound then
          pcall(function() Net.play_sound(path) end)
        end
      end

      open_menu()
    end,


    on_no = function()
      if type(menu_cfg.on_decline_open) == "function" then
        -- If caller supplied a handler, they own it (but they should use from_prompt+reuse_existing_box if they show text)
        menu_cfg.on_decline_open()
        return
      end

      -- Default decline behavior:
      -- If author provided a decline line (texts.open_no OR texts.decline_open), show it safely chained from the prompt.
      if open_no_text then
        local next_cfg = shallow_copy(cfg)
        next_cfg.from_prompt = true
        next_cfg.reuse_existing_box = true
        Talk.start(player_id, { open_no_text }, next_cfg, bot_name)
      end
      -- If no decline text and no handler: do nothing (clean close).
    end,

    on_cancel = function()
      if type(menu_cfg.on_cancel_open) == "function" then
        menu_cfg.on_cancel_open()
      end
    end,
  })

end


-- Talk.prompt_then_talk(player_id, question, yes_script, no_script, cfg, bot_name)
function Talk.prompt_then_talk(player_id, question, yes_script, no_script, cfg, bot_name)
  cfg = cfg or {}

  return Talk.prompt_yesno(player_id, question, cfg, bot_name, {
    on_yes = function()
      local next_cfg = shallow_copy(cfg)
      next_cfg.from_prompt = true
      next_cfg.reuse_existing_box = true
      Talk.start(player_id, yes_script, next_cfg, bot_name)
    end,
    on_no = function()
      local next_cfg = shallow_copy(cfg)
      next_cfg.from_prompt = true
      next_cfg.reuse_existing_box = true
      Talk.start(player_id, no_script, next_cfg, bot_name)
    end,
    on_cancel = cfg.on_cancel,
  })
end

--=====================================================
-- Talk.npc(cfg)
-- Minimal NPC wiring with sane defaults.
--
-- Authors should only need:
--   cfg.area_id, cfg.object, (optional) cfg.name, cfg.lines
--
-- Optional:
--   cfg.preset / cfg.box / cfg.mug / cfg.nameplate / cfg.frame
--   cfg.ui overrides (mugshot off, tweak offsets, etc.)
--   cfg.prompt = { question, yes_lines, no_lines }
--=====================================================
function Talk.npc(cfg)
  assert(cfg and cfg.object, "[Talk.npc] cfg.object required (Tiled object name)")

  local area_id  = cfg.area_id or "default"
  local obj_name = cfg.object

  local bot_pos = Net.get_object_by_name(area_id, obj_name)
  assert(bot_pos, "[Talk.npc] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

  local bot_id = Net.create_bot({
    name = cfg.name or obj_name,
    area_id = area_id,
    texture_path = cfg.texture_path or "/server/assets/ow/prog/prog_ow.png",
    animation_path = cfg.animation_path or "/server/assets/ow/prog/prog_ow.animation",
    x = bot_pos.x,
    y = bot_pos.y,
    z = bot_pos.z or 0,
    direction = cfg.direction or Direction.Down,
    solid = (cfg.solid ~= false),
  })

  local BOT_NAME = Net.get_bot_name(bot_id)

  Net:on("actor_interaction", function(event)
    if event.actor_id ~= bot_id then return end

    local player_id = event.player_id
    if Dialogue.is_active(player_id) then return end

    -- Face the player
    local player_pos = Net.get_player_position(player_id)
    Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

    -- Custom handler override (advanced users)
    if type(cfg.on_interact) == "function" then
      cfg.on_interact(player_id, bot_id, BOT_NAME)
      return
    end

    -- Prompt flow (optional)
    if cfg.prompt then
      local p = cfg.prompt
      Talk.prompt_then_talk(
        player_id,
        p.question or "Continue?",
        p.yes_lines or p.on_yes_lines or { "..." },
        p.no_lines  or p.on_no_lines  or { "..." },
        cfg,
        BOT_NAME
      )
      return
    end

    -- Normal dialogue
    local lines = cfg.lines or cfg.text or { "..." }
    Talk.start(player_id, lines, cfg, BOT_NAME)
  end)

  return bot_id
end

--=====================================================
-- Internal: expose UI builder for wrappers (vert menu, etc.)
--=====================================================
function Talk._build_ui(cfg, bot_name, opts)
  return build_ui(cfg, bot_name, opts)
end


return Talk
