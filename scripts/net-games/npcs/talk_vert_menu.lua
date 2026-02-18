--=====================================================
-- talk_vert_menu.lua
-- Talk-mode wrapper for PromptVertical that fully mirrors
-- the working ProgVertPromptPink flow (but reusable).
--
-- What this module guarantees (Pink parity):
-- 1) One stable Talk textbox (same box_id) is reused for:
--    - initial intro line (question)
--    - confirm yes/no prompts
--    - post-select text
--    - "Thank you! ... anything else?" line
--    - exit goodbye line
-- 2) Menu stays visible while confirm/post text happens.
-- 3) Menu locking matches Pink:
--    - cursor hidden while locked (optional)
--    - non-selected dim alpha (optional)
-- 4) Exit behavior matches Pink:
--    - only plays close sfx once
--    - closes ONLY the menu (keeps textbox alive)
--    - defers goodbye until PromptVertical finalizes close
--    - then closes textbox cleanly, with input lock during close anim
-- 5) Anti-mash protections to avoid the "closing window" softlock.
--
-- Public API:
--   TalkVertMenu.open(player_id, bot_name, talk_cfg, menu_cfg)
--   TalkVertMenu.is_busy(player_id) -> bool
--=====================================================

local Talk          = require("scripts/net-games/npcs/talk")
local TalkPresets   = require("scripts/net-games/npcs/talk_presets")

local Dialogue      = require("scripts/net-games/dialogue/dialogue")
local Prompt        = require("scripts/net-games/dialogue/prompt")
local PromptVertical= require("scripts/net-games/dialogue/prompt_vertical")

local Displayer     = require("scripts/net-games/displayer/displayer")
local Input         = require("scripts/net-games/input/input")

local TalkVertMenu = {}

--=====================================================
-- Internal state (per-player)
--=====================================================

-- pending_ack[player_id] = {
--   box_id = "...",
--   ui = <Talk UI table>,
--   menu = <PromptVertical menu instance> | nil,
--   phase = 1 or 2,
--   choice_id = ...,
--   choice_text = "...",
--   flow = <flow table>
-- }
local pending_ack = {}

-- exit_pending[player_id] = { box_id=..., ui=..., flow=... }
-- Defer goodbye until PromptVertical fully finalizes close
-- (it may disable indicator during finalization when keep_textbox=true).
local exit_pending = {}

-- confirm_pending[player_id] = { box_id=..., ui=..., menu=..., flow=..., choice_id=..., choice_text=... }
-- Defer opening YES/NO confirm by 1 tick to avoid textbox clear/position race.
local confirm_pending = {}

-- goodbye_closing[player_id] = { box_id=... }
-- Keep input locked until textbox is fully removed (post-close animation).
local goodbye_closing = {}

local TICK_ATTACHED = false

--=====================================================
-- Small helpers
--=====================================================

local function play_sfx(player_id, path)
  if not path then return end
  Net.provide_asset_for_player(player_id, path)

  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, path) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(path) end)
  end
end

local function set_menu_locked(menu, locked)
  if not menu then return end
  if type(menu.set_locked) == "function" then
    menu:set_locked(locked == true)
  end
end

local function set_textbox_indicator(ui, enabled)
  if not (ui and ui.backdrop and ui.backdrop.indicator) then return end
  ui.backdrop.indicator.enabled = enabled and true or false
end

local function reset_box_text(player_id, box_id, ui, text, indicator_enabled)
  -- Match Pink: don't flicker nameplate when reusing the same box
  local ops = {
    page_advance = "wait_for_confirm",
    auto_advance_seconds = 999999,
    confirm_during_typing = true,
    type_sfx_path = ui.type_sfx_path,
    type_sfx_min_dt = ui.type_sfx_min_dt,
    mugshot = ui.mugshot,
    wrap_opts = { allow_leading_spaces = true },
    nameplate = nil,
  }

  if indicator_enabled ~= nil then
    set_textbox_indicator(ui, indicator_enabled)
  end

  if Displayer.Text.reset_text_box then
    Displayer.Text.reset_text_box(
      player_id, box_id, text,
      ui.x or 8, ui.y or 110, ui.w or 224, ui.h or 42,
      ui.font or "THIN_BLACK", ui.scale or 2.0, ui.z or 100,
      ui.backdrop,
      ui.typing_speed or 12,
      ops
    )
  else
    Displayer.Text:resetTextBox(
      player_id, box_id, text,
      ui.x or 8, ui.y or 110, ui.w or 224, ui.h or 42,
      ui.font or "THIN_BLACK", ui.scale or 2.0, ui.z or 100,
      ui.backdrop,
      ui.typing_speed or 12,
      ops
    )
  end
end

local function resolve_frame(frame_key_or_table)
  if not frame_key_or_table then return nil end
  if type(frame_key_or_table) == "table" then
    return frame_key_or_table
  end
  return TalkPresets.frames[frame_key_or_table] or nil
end

local function apply_default_layout_frame(talk_cfg, layout)
  layout = layout or {}
  if layout.frame ~= nil then return layout end

  local f = resolve_frame(talk_cfg and talk_cfg.frame)
  if f then
    -- PromptVertical expects {r,g,b,a,color_mode}
    layout.frame = {
      r = f.r, g = f.g, b = f.b, a = f.a,
      color_mode = f.color_mode,
    }
  end
  return layout
end

--=====================================================
-- Tick loop (Pink-parity behavior)
--=====================================================

local function ensure_tick()
  if TICK_ATTACHED then return end
  TICK_ATTACHED = true

  Net:on("tick", function()
    --=====================================================
    -- Keep input locked until textbox is FULLY removed
    --=====================================================
    for player_id, g in pairs(goodbye_closing) do
      local box_id = g.box_id

      if Net.lock_player_input then
        pcall(function() Net.lock_player_input(player_id) end)
      end

      Input.consume(player_id)
      Input.swallow(player_id, 0.05)

      local bd = Displayer.Text.getTextBoxData(player_id, box_id)
      if not bd then
        goodbye_closing[player_id] = nil

        if Net.unlock_player_input then
          pcall(function() Net.unlock_player_input(player_id) end)
        end

        -- One more swallow so release doesn't instantly re-trigger interaction
        Input.consume(player_id)
        Input.clear_require_release(player_id, { "confirm", "cancel" })
        Input.require_release(player_id, { "confirm", "cancel" })
        Input.swallow(player_id, 0.12)
      end
    end

    --=====================================================
    -- Deferred EXIT goodbye (only after PromptVertical finalizes)
    --=====================================================
    for player_id, ex in pairs(exit_pending) do
      if not (PromptVertical.instances and PromptVertical.instances[player_id]) then
        local box_id = ex.box_id
        local ui = ex.ui
        local flow = ex.flow

        reset_box_text(player_id, box_id, ui, (flow.exit_goodbye_text or "Thanks for stopping by!"), true)

        pending_ack[player_id] = {
          box_id = box_id,
          ui = ui,
          menu = nil,
          phase = 1,
          choice_id = "exit",
          choice_text = "exit",
          flow = flow,
        }

        exit_pending[player_id] = nil

        -- Prevent carry-press from instantly confirming goodbye
        Input.consume(player_id)
        Input.clear_require_release(player_id, { "confirm", "cancel" })
        Input.swallow(player_id, 0.10)
      end
    end    --=====================================================
    -- Deferred CONFIRM yes/no (open on next tick)
    --=====================================================
    for player_id, c in pairs(confirm_pending) do
      -- Only fire while the menu instance still exists (player didn't exit)
      if PromptVertical.instances and PromptVertical.instances[player_id] then
        confirm_pending[player_id] = nil

        local box_id = c.box_id
        local ui = c.ui
        local menu = c.menu
        local flow = c.flow
        local choice_id = c.choice_id
        local choice_text = c.choice_text

        -- Keep the menu locked while confirm is up
        set_menu_locked(menu, true)

        local qfmt = flow.confirm.text_format or 'Are you sure you want "%s"?'
        Prompt.yesno(player_id, {
          ui = ui,
          reuse_existing_box = true,
          question = string.format(qfmt, choice_text),

          on_yes = function()
            play_sfx(player_id, flow.sfx.confirm)
            -- This runs the same path as "no-confirm" selections
            local fmt = flow.post_select.text_format or 'You got "%s".'
            reset_box_text(player_id, box_id, ui, string.format(fmt, choice_text), true)

            pending_ack[player_id] = {
              box_id = box_id,
              ui = ui,
              menu = menu,
              phase = 1,
              choice_id = choice_id,
              choice_text = choice_text,
              flow = flow,
            }
          end,

          on_no = function()
            play_sfx(player_id, flow.sfx.close)

            -- Prompt may have unlocked input; relock because menu is still visible+locked
            if Net.lock_player_input then
              pcall(function() Net.lock_player_input(player_id) end)
            end

            reset_box_text(
              player_id,
              box_id,
              ui,
              (flow.after_no_text or flow.after_text or "Is there anything else you'd like?"),
              false
            )

            pending_ack[player_id] = {
              box_id = box_id,
              ui = ui,
              menu = menu,
              phase = 2,
              choice_id = choice_id,
              choice_text = choice_text,
              flow = flow,
            }
          end,

          cancel_behavior = "select_no",
        })

        return
      else
        -- Menu was closed before we got here
        confirm_pending[player_id] = nil
      end
    end


    --=====================================================
    -- Pending ACK phases (post-select / after-text / exit close) (post-select / after-text / exit close)
    --=====================================================
    for player_id, p in pairs(pending_ack) do
      local st = Displayer.Text.getTextBoxState(player_id, p.box_id)

      if not st then
        pending_ack[player_id] = nil
      else
        -- Pink: keep player locked while pending ack is active
        if Net.lock_player_input then
          pcall(function() Net.lock_player_input(player_id) end)
        end

        -- While printing, allow confirm to fast-forward
        if st == "printing" then
          if Input.pop(player_id, "confirm") then
            Displayer.Text.advance_text_box(player_id, p.box_id)
            Input.consume(player_id)
            Input.require_release(player_id, { "confirm" })
          end

        elseif st == "waiting" then
          -- Phase 2 auto-returns to menu when it finishes printing (waiting)
          if p.phase == 2 then
            set_textbox_indicator(p.ui, false)
            if p.menu then
              set_menu_locked(p.menu, false)
            end
            pending_ack[player_id] = nil

          -- Phase 1: confirm advances
          elseif Input.pop(player_id, "confirm") then
            Input.consume(player_id)
            Input.clear_require_release(player_id, { "confirm", "cancel" })
            Input.swallow(player_id, 0.10)

            if p.choice_id == "exit" then
              -- Start closing animation
              Displayer.Text.closeTextBox(player_id, p.box_id)
              pending_ack[player_id] = nil

              -- Do NOT unlock here. Keep input locked until textbox is removed.
              goodbye_closing[player_id] = { box_id = p.box_id }

              -- Eat carry-press so we can't re-interact during the close window
              Input.consume(player_id)
              Input.clear_require_release(player_id, { "confirm", "cancel" })
              Input.require_release(player_id, { "confirm", "cancel" })
              Input.swallow(player_id, 0.12)
              return
            end

            -- Phase 1 confirm -> show after_text (NO indicator) then auto-return
            reset_box_text(
              player_id,
              p.box_id,
              p.ui,
              (p.flow.after_yes_text or p.flow.after_text or "Thank you!{p_1} Is there anything else you'd like?"),

              false
            )
            p.phase = 2
          end
        end
      end
    end
  end)
end

--=====================================================
-- Busy guard: use this from NPC scripts to prevent re-entrant spam
--=====================================================
function TalkVertMenu.is_busy(player_id)
  if not player_id then return false end

  if goodbye_closing[player_id] then return true end
  if pending_ack[player_id] then return true end
  if exit_pending[player_id] then return true end

  if Prompt.instances and Prompt.instances[player_id] then return true end
  if PromptVertical.instances and PromptVertical.instances[player_id] then return true end
  if Dialogue.is_active and Dialogue.is_active(player_id) then return true end

  return false
end

--=====================================================
-- Public API
--=====================================================
-- TalkVertMenu.open(player_id, bot_name, talk_cfg, menu_cfg)
--
-- talk_cfg: same config "shape" used by Talk.npc / Talk.start / Talk.prompt_yesno
--   (preset, frame, ui overrides, box_id, area_id/object for stable id, etc.)
--
-- menu_cfg:
--   intro_text (string)      -- the line that prints while menu opens
--   options (array)          -- { {id=..., text=...}, ... } or strings
--   default_index (number)
--   cancel_behavior (string) -- prompt_vertical cancel behavior
--   exit_id (default "exit")
--   exit_index (number | nil)
--   layout (table)           -- PromptVertical layout config
--   flow (table):
--     keep_menu_open (bool default true)
--     lock_dim_alpha (number default 0.35)
--     hide_cursor_when_locked (bool default true)
--
--     confirm = { enabled=true, text_format='Are you sure you want "%s"?', skip_ids = { exit=true } }
--     post_select = { enabled=true, text_format='You got "%s".', skip_ids = { exit=true } }
--
--     after_text (string default 'Thank you!...')
--     exit_goodbye_text (string default 'Thanks for stopping by!')
--
--     sfx = { desc=..., confirm=..., close=... }  -- optional
function TalkVertMenu.open(player_id, bot_name, talk_cfg, menu_cfg)
  ensure_tick()

  talk_cfg = talk_cfg or {}
  menu_cfg = menu_cfg or {}

  -- Build Talk UI ONCE (stable box_id + preset + frame dye + nameplate/mug)
  -- Mode "prompt" ensures prompt-like defaults are applied the same way Talk does.
  local ui = Talk._build_ui(talk_cfg, bot_name or (talk_cfg.name or ""), { mode = "prompt" })
  local box_id = ui.box_id

  -- Default flow mirrors Pink (nested confirm/post tables)
  local flow = menu_cfg.flow or {}
  flow.confirm = flow.confirm or {}
  flow.post_select = flow.post_select or {}
  flow.sfx = flow.sfx or {}

  local exit_id = menu_cfg.exit_id or "exit"

  local confirm_skip = flow.confirm.skip_ids or {}
  local post_skip = flow.post_select.skip_ids or {}

  local layout = apply_default_layout_frame(talk_cfg, menu_cfg.layout or {})

  PromptVertical.menu(player_id, {
    reuse_existing_box = true,
    keep_textbox = true,

    ui = ui,
    layout = layout,

    assets = menu_cfg.assets,


    question = tostring(menu_cfg.intro_text or "Choose:"),
    options = menu_cfg.options or { { id = exit_id, text = "Exit" } },
    default_index = tonumber(menu_cfg.default_index or 1) or 1,

    cancel_behavior = menu_cfg.cancel_behavior or "jump_to_exit",
    exit_index = menu_cfg.exit_index and tonumber(menu_cfg.exit_index) or nil,

    keep_menu_open = (flow.keep_menu_open ~= false),
    selection_behavior = "callback_only",

    lock_dim_alpha = tonumber(flow.lock_dim_alpha or 0.35) or 0.35,
    hide_cursor_when_locked = (flow.hide_cursor_when_locked ~= false),

    on_choose = function(choice, index, menu)
      -- Ensure menu uses the current lock params (Pink does this each selection)
      if menu then
        menu.lock_dim_alpha = tonumber(flow.lock_dim_alpha or 0.35) or 0.35
        menu.hide_cursor_when_locked = (flow.hide_cursor_when_locked ~= false)
      end

      local choice_id = (choice and choice.id) or index
      local choice_text = tostring(choice and choice.text or "???")

      --=====================================================
      -- EXIT path (Pink parity: only close sfx once, defer goodbye)
      --=====================================================
      if choice_id == exit_id then
        play_sfx(player_id, flow.sfx.close)

        exit_pending[player_id] = {
          box_id = box_id,
          ui = ui,
          flow = flow,
        }

        -- Close ONLY the menu; keep textbox alive for goodbye line
        PromptVertical.close(player_id, "exit", { keep_textbox = true })
        return
      end

      --=====================================================
      -- Regular selection path
      --=====================================================
      play_sfx(player_id, flow.sfx.desc)
      set_menu_locked(menu, true)

      local function do_post_text_then_ack()
        if flow.post_select.enabled == false then
          set_menu_locked(menu, false)
          return
        end
        if post_skip[choice_id] then
          set_menu_locked(menu, false)
          return
        end

        local fmt = flow.post_select.text_format or 'You got "%s".'
        reset_box_text(player_id, box_id, ui, string.format(fmt, choice_text), true)

        pending_ack[player_id] = {
          box_id = box_id,
          ui = ui,
          menu = menu,
          phase = 1,
          choice_id = choice_id,
          choice_text = choice_text,
          flow = flow,
        }
      end

      --=====================================================
      -- Confirm gate (Pink parity)
      --=====================================================
      local confirm_enabled = (flow.confirm.enabled ~= false)
      if (not confirm_enabled) or confirm_skip[choice_id] then
        do_post_text_then_ack()
        return
      end

      local qfmt = flow.confirm.text_format or 'Are you sure you want "%s"?'

      -- Defer opening YES/NO confirm by 1 tick to avoid textbox clear/position race.
      confirm_pending[player_id] = {
        box_id = box_id,
        ui = ui,
        menu = menu,
        flow = flow,
        choice_id = choice_id,
        choice_text = choice_text,
      }
      return
end,
  })
end

return TalkVertMenu
