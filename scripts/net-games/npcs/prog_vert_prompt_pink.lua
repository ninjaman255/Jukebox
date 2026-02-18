--=====================================================
-- prog_vert_prompt_pink.lua
--
-- Goal_1_5 target flow:
--   Interact ->
--     YES/NO prompt: "Do you wanna check out the vertical menu?"
--       YES ->
--         SAME textbox becomes the intro line you pass into open_vertical_menu(...),
--         vertical menu opens while that line prints,
--         and menu control unlocks after printing finishes.
--
-- Menu selection flow (Goal_1_5):
--   Select choice -> menu locks (cursor hidden, non-selected dim, input frozen)
--     -> YES/NO confirm prompt (textbox UI) while menu remains visible+locked
--       NO  -> unlock menu, return to menu
--       YES -> optional post-text while still locked
--             then unlock menu and return to menu (or close if configured)
--
-- Engine expectations:
--   prompt_vertical.lua provides menu:set_locked(bool) and a "keep open" selection path
--   (e.g. opts.selection_behavior="callback_only" + on_choose(choice, idx, menu))
--=====================================================

local Direction = require("scripts/libs/direction")
require("scripts/net-games/dialogue/startup")

local Dialogue       = require("scripts/net-games/dialogue/dialogue")
local Prompt         = require("scripts/net-games/dialogue/prompt")
local PromptVertical = require("scripts/net-games/dialogue/prompt_vertical")
local TalkPresets    = require("scripts/net-games/npcs/talk_presets")
local Displayer      = require("scripts/net-games/displayer/displayer")
local Input          = require("scripts/net-games/input/input")

--=====================================================
-- SFX
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
    pcall(function()
      Net.play_sound_for_player(player_id, path)
    end)
  elseif Net.play_sound then
    pcall(function()
      Net.play_sound(path)
    end)
  end
end

-- pending_ack[player_id] = {
--   box_id = "...",
--   menu = <PromptMenuInstance> | nil,
--   phase = 1 or 2,
--   choice_text = "...",
-- }
local pending_ack = {}

-- exit_pending[player_id] = { box_id = "..." }
-- Used to defer EXIT goodbye until PromptVertical fully finalizes close
-- (PromptVertical finalize disables indicator when keep_textbox=true).
local exit_pending = {}

-- goodbye_closing[player_id] = { box_id = "..." }
-- Used to keep input locked until the goodbye textbox is fully removed (post-close animation).
local goodbye_closing = {}


--=====================================================
-- Area / placement (must match your TMX object name)
--=====================================================
local area_id  = "default"
local obj_name = "ProgVertPromptPink" -- Tiled object with THIS exact name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_vert_prompt_pink] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

--=====================================================
-- Bot creation
--=====================================================
local bot_id = Net.create_bot({
  name = "PINK PROMPT PROG",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow_pink.png",
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
local PINK_FRAME = TalkPresets.frames.pink
local PINK_MUG   = TalkPresets.mugs.prog_pink

local function copy_frame_preset(preset)
  if type(preset) ~= "table" then return nil end
  return {
    r = preset.r, g = preset.g, b = preset.b, a = preset.a,
    color_mode = preset.color_mode,
  }
end

local FRAME = copy_frame_preset(PINK_FRAME)

--=====================================================
-- Menu options
--=====================================================
local function build_options()
  local t = {}
  for i = 1, 40 do
    t[#t + 1] = { id = i, text = ("Pink Option %02d"):format(i) }
  end
  t[#t + 1] = { id = "exit", text = "Exit" }
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
      texture_path = PINK_MUG.texture_path,
      anim_path = PINK_MUG.anim_path,
      talk_anim_state = PINK_MUG.talk_anim_state,
      idle_anim_state = PINK_MUG.idle_anim_state,
      reserve_w = PINK_MUG.reserve_w,
      reserve_h = PINK_MUG.reserve_h,
      offset_x  = PINK_MUG.offset_x,
      offset_y  = PINK_MUG.offset_y,
      gap_px    = PINK_MUG.gap_px,
      sprite_id = PINK_MUG.sprite_id,
      z_bias    = PINK_MUG.z_bias,
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

local function reset_box_text(player_id, box_id, ui, text, indicator_enabled)
  local ops = {
    page_advance = "wait_for_confirm",
    auto_advance_seconds = 999999,
    confirm_during_typing = true,
    type_sfx_path = ui.type_sfx_path,
    type_sfx_min_dt = ui.type_sfx_min_dt,
    mugshot = ui.mugshot,
    wrap_opts = { allow_leading_spaces = true },

    -- IMPORTANT: avoid nameplate "close/open" flicker when reusing the box
    nameplate = nil,
  }

  local bd = ui.backdrop
  if bd and bd.indicator and indicator_enabled ~= nil then
    bd.indicator.enabled = indicator_enabled and true or false
  end

  if Displayer.Text.reset_text_box then
    Displayer.Text.reset_text_box(
      player_id, box_id, text,
      ui.x or 8, ui.y or 110, ui.w or 224, ui.h or 42,
      ui.font or "THIN_BLACK", ui.scale or 2.0, ui.z or 100,
      bd,
      ui.typing_speed or 12,
      ops
    )
  else
    -- camelCase fallback (if your Displayer exposes it this way)
    Displayer.Text:resetTextBox(
      player_id, box_id, text,
      ui.x or 8, ui.y or 110, ui.w or 224, ui.h or 42,
      ui.font or "THIN_BLACK", ui.scale or 2.0, ui.z or 100,
      bd,
      ui.typing_speed or 12,
      ops
    )
  end
end

-- (kept for debugging / legacy callsites; not relied on for indicator correctness)
local function set_textbox_indicator(player_id, box_id, enabled)
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if not bd or not bd.backdrop then return end
  bd.backdrop.indicator = bd.backdrop.indicator or {}
  bd.backdrop.indicator.enabled = enabled and true or false
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

    -- menu text intro animation
    text_intro_enabled = true,
    text_intro_frames = 24,
    text_intro_stagger_frames = 16,
    text_intro_slide_px = 8,

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
-- Menu-flow config (NPC-specific; matches Goal_1_5 intent)
--=====================================================
local MENU_FLOW = {
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

  close_on_exit = true,
}

--=====================================================
-- Helpers: safe lock/unlock
--=====================================================
local function set_menu_locked(menu, locked)
  if not menu then return end
  if type(menu.set_locked) == "function" then
    menu:set_locked(locked)
  end
end

local function set_menu_lock_params(menu)
  if not menu then return end
  menu.lock_dim_alpha = MENU_FLOW.lock_dim_alpha
  menu.hide_cursor_when_locked = MENU_FLOW.hide_cursor_when_locked
end

--=====================================================
-- Tick: handle pending ACK flow + deferred EXIT goodbye
--=====================================================
Net:on("tick", function()
  --=====================================================
  -- Goodbye close: keep input locked until textbox is fully removed
  --=====================================================
  for player_id, g in pairs(goodbye_closing) do
    local box_id = g.box_id or "prog_vert_pink_box"

    -- While closing exists, stay locked and swallow inputs
    if Net.lock_player_input then
      pcall(function() Net.lock_player_input(player_id) end)
    end
    Input.consume(player_id)
    Input.swallow(player_id, 0.05)

    -- True "done" check: textbox data no longer exists
    local bd = Displayer.Text.getTextBoxData(player_id, box_id)
    if not bd then
      goodbye_closing[player_id] = nil

      if Net.unlock_player_input then
        pcall(function() Net.unlock_player_input(player_id) end)
      end

      -- One more swallow so the release doesn't instantly re-trigger interaction
      Input.consume(player_id)
      Input.clear_require_release(player_id, { "confirm", "cancel" })
      Input.require_release(player_id, { "confirm", "cancel" })
      Input.swallow(player_id, 0.12)
    end
  end

  -- Fire deferred EXIT goodbye only after PromptVertical fully finalized close.
  for player_id, ex in pairs(exit_pending) do
    if not (PromptVertical.instances and PromptVertical.instances[player_id]) then
      local box_id = ex.box_id or "prog_vert_pink_box"
      local ui = build_ui_config(box_id)

      reset_box_text(player_id, box_id, ui, "Thanks for stopping by!", true)

      pending_ack[player_id] = { box_id = box_id, menu = nil, phase = 1, choice_text = "exit" }
      exit_pending[player_id] = nil

      -- prevent carry-press from immediately confirming the goodbye
      Input.consume(player_id)
      Input.clear_require_release(player_id, { "confirm", "cancel" })
      Input.swallow(player_id, 0.10)
    end
  end

  for player_id, p in pairs(pending_ack) do
    local st = Displayer.Text.getTextBoxState(player_id, p.box_id)

    if not st then
      pending_ack[player_id] = nil
    else
      -- Keep player locked while pending ack is active
      if Net.lock_player_input then
        pcall(function() Net.lock_player_input(player_id) end)
      end

      -- Phase 2 ("Cool...") auto-return to menu when it finishes printing.
      if p.phase == 2 and st == "waiting" then
        -- indicator should be off for this line
        set_textbox_indicator(player_id, p.box_id, false)

        if p.menu and type(p.menu.set_locked) == "function" then
          p.menu:set_locked(false)
        end

        pending_ack[player_id] = nil
      end

      -- While printing, allow confirm to fast-forward
      if st == "printing" then
        if Input.pop(player_id, "confirm") then
          Displayer.Text.advance_text_box(player_id, p.box_id)
          Input.consume(player_id)
          Input.require_release(player_id, { "confirm" })
        end

      -- When waiting (indicator), confirm advances the ack phase
      elseif st == "waiting" then
        if Input.pop(player_id, "confirm") then
          Input.consume(player_id)
          Input.clear_require_release(player_id, { "confirm", "cancel" })
          Input.swallow(player_id, 0.10)

          local box_id = p.box_id

          if p.choice_text == "exit" then
            -- Start closing animation
            Displayer.Text.closeTextBox(player_id, box_id)
            pending_ack[player_id] = nil

            -- DO NOT unlock here. Keep input locked until the textbox is fully removed.
            goodbye_closing[player_id] = { box_id = box_id }

            -- Eat carry-press so we can't re-interact during the close window
            Input.consume(player_id)
            Input.clear_require_release(player_id, { "confirm", "cancel" })
            Input.require_release(player_id, { "confirm", "cancel" })
            Input.swallow(player_id, 0.12)
            return
          end

          -- Phase 1 confirm -> show "Cool..." (NO indicator) then auto-return
          local ui = build_ui_config(box_id)
          reset_box_text(player_id, box_id, ui, "Thank you!{p_1} Is there anything else you'd like?", false)
          p.phase = 2
        end
      end
    end
  end
end)

--=====================================================
-- Open the vertical menu (Goal_1_5: keep textbox, reuse existing box)
--=====================================================
local function open_vertical_menu(player_id, intro_text)
  local box_id = "prog_vert_pink_box"

  PromptVertical.menu(player_id, {
    reuse_existing_box = true,
    keep_textbox = true,

    ui = build_ui_config(box_id),
    layout = build_layout_config(),

    question = assert(intro_text, "open_vertical_menu requires intro_text"),
    options = build_options(),
    default_index = 1,

    cancel_behavior = "jump_to_exit",
    exit_index = 41,

    keep_menu_open = MENU_FLOW.keep_menu_open,
    selection_behavior = "callback_only",

    lock_dim_alpha = MENU_FLOW.lock_dim_alpha,
    hide_cursor_when_locked = MENU_FLOW.hide_cursor_when_locked,

    on_choose = function(choice, index, menu)
      set_menu_lock_params(menu)

      -- EXIT behavior (Exit should ONLY play close SFX)
      if choice and choice.id == "exit" then
        play_sfx(player_id, SFX.DESC_CLOSE)

        -- Defer goodbye until PromptVertical finalize completes (it disables indicator).
        exit_pending[player_id] = { box_id = box_id }

        if MENU_FLOW.close_on_exit then
          -- Close ONLY the menu; keep textbox alive.
          PromptVertical.close(player_id, "exit", { keep_textbox = true })
        end

        return
      end

      -- SFX: selecting a normal (non-exit) option
      play_sfx(player_id, SFX.DESC)


      -- Lock menu immediately (visual + input)
      set_menu_locked(menu, true)

      local choice_text = tostring(choice and choice.text or "???")

      local skip_confirm = false
      if choice and choice.id and MENU_FLOW.confirm.skip_ids[choice.id] then
        skip_confirm = true
      end

      local function do_post_text_then_return()
        local skip_post = false
        if choice and choice.id and MENU_FLOW.post_select.skip_ids[choice.id] then
          skip_post = true
        end

        if not MENU_FLOW.post_select.enabled or skip_post then
          set_menu_locked(menu, false)
          return
        end

        local ui = build_ui_config(box_id)
        reset_box_text(player_id, box_id, ui, MENU_FLOW.post_select.text_format:format(choice_text), true)

        pending_ack[player_id] = { box_id = box_id, menu = menu, phase = 1, choice_text = choice_text }
      end

      if not MENU_FLOW.confirm.enabled or skip_confirm then
        do_post_text_then_return()
        return
      end

      Prompt.yesno(player_id, {
        ui = build_ui_config(box_id),
        reuse_existing_box = true,
        question = MENU_FLOW.confirm.text_format:format(choice_text),

        on_yes = function()
          -- SFX: confirm
          play_sfx(player_id, SFX.CONFIRM)
          do_post_text_then_return()
        end,

        on_no = function()
          -- SFX: close/deny
          play_sfx(player_id, SFX.DESC_CLOSE)

          -- Prompt might have unlocked input; re-lock because menu is still up
          if Net.lock_player_input then
            pcall(function() Net.lock_player_input(player_id) end)
          end

          local ui = build_ui_config(box_id)
          reset_box_text(player_id, box_id, ui, "Is there anything else you'd like?", false)

          pending_ack[player_id] = { box_id = box_id, menu = menu, phase = 2 }
        end,

        cancel_behavior = "select_no",
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

  -- If the goodbye textbox is still closing, ignore interaction (prevents mash-A softlock window)
  if goodbye_closing[player_id] then return end
  local st = Displayer.Text.getTextBoxState(player_id, "prog_vert_pink_box")
  if st == "closing" then return end

  -- Prevent re-entrant interaction spam from force-replacing prompts/menus
  if pending_ack[player_id] then return end
  if exit_pending[player_id] then return end
  if Prompt.instances and Prompt.instances[player_id] then return end
  if PromptVertical.instances and PromptVertical.instances[player_id] then return end

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  Prompt.yesno(player_id, {
    ui = build_ui_config("prog_vert_pink_box"),
    question = "Do you wanna check out the vertical menu?",

    on_yes = function()
      play_sfx(player_id, SFX.DESC)
      open_vertical_menu(player_id, "Awesome. Let me know if there's anything that you like.")
    end,

    on_no = function()
      Dialogue.start(player_id, {
        "No worries. Maybe next time.",
      }, {
        reuse_existing_box = true,
        ui = build_ui_config("prog_vert_pink_box"),
        from_prompt = true,
      })
    end,

    cancel_behavior = "select_no",
  })
end)
