-- scripts/net-games/dialogue/dialogue.lua
require("scripts/net-games/framework")

local Displayer = require("scripts/net-games/displayer/displayer")
local Input     = require("scripts/net-games/input/input")
local C         = require("scripts/net-games/dialogue/constants")
local Prompt    = require("scripts/net-games/dialogue/prompt")
local PromptVertical = require("scripts/net-games/dialogue/prompt_vertical")


local Dialogue = {}
Dialogue.instances = {}

local LISTENER_ATTACHED = false

--=====================================================
-- Input lock helper (correct ONB signatures)
--=====================================================
local function set_input_locked(player_id, locked)
  if not Net then
    print("[Dialogue] Net is nil; cannot lock input")
    return false
  end

  if locked then
    if Net.lock_player_input then
      local ok = pcall(function()
        Net.lock_player_input(player_id)
      end)
      if not ok then
        print("[Dialogue] input lock FAIL via Net.lock_player_input")
      end
      return ok
    end
    print("[Dialogue] WARNING: Net.lock_player_input missing")
    return false
  else
    if Net.unlock_player_input then
      local ok = pcall(function()
        Net.unlock_player_input(player_id)
      end)
      if not ok then
        print("[Dialogue] input unlock FAIL via Net.unlock_player_input")
      end
      return ok
    end
    print("[Dialogue] WARNING: Net.unlock_player_input missing")
    return false
  end
end

local function ensure_listener()
  if LISTENER_ATTACHED then return end
  LISTENER_ATTACHED = true
  Input.attach_virtual_input_listener()
end


local function default_opts()
  return {
    x = 8, y = 110, w = 224, h = 42,
    font = "THICK",
    scale = 2.0,
    z = 100,
    typing_speed = 30,

    page_advance = C.PageAdvance.WAIT_FOR_CONFIRM,
    advance_delay = 2.0,
    confirm_during_typing = true,

    input_mode = C.InputMode.DIALOGUE_OWNS_INPUT,
    cancel_behavior = "battle_network",

    debug = false,
  }
end

local function merge(a, b)
  if not b then return a end
  for k, v in pairs(b) do a[k] = v end
  return a
end

local function mk_box_id(player_id, ui)
  if ui and ui.box_id then
    return tostring(ui.box_id)
  end
  return "ng_dialogue_" .. tostring(player_id)
end

local function close_instance(player_id, reason)
  local inst = Dialogue.instances[player_id]
  if not inst then return end

  -- If we're already closing, don't spam close calls.
  if inst.closing then
    return
  end

  inst.closing = true
  inst.close_reason = reason

  if inst.box_id then
    Displayer.Text.closeTextBox(player_id, inst.box_id, {
      caller = "Dialogue.close_instance",
      reason = reason,
    })
  end

  -- IMPORTANT:
  -- Do NOT unlock input here. We keep the player locked until the textbox is fully removed.
  -- That prevents mash-A reopens during the closing animation.

  -- swallow to prevent carry-press closes / reopens
  Input.consume(player_id)
  Input.swallow(player_id, 0.10)

  if inst.opts and inst.opts.debug then
    print("[Dialogue] begin-close player=" .. tostring(player_id) .. " reason=" .. tostring(reason))
  end
end

local function attach_tick()
  if Dialogue._tick_attached then return end
  Dialogue._tick_attached = true

  Net:on("tick", function(event)
    for player_id, inst in pairs(Dialogue.instances) do
      -- IMPORTANT:
      -- getTextBoxState() returns "completed" even if the box no longer exists.
      -- getTextBoxData() is the true existence check.
      local bd = Displayer.Text.getTextBoxData(player_id, inst.box_id)
      local state = Displayer.Text.getTextBoxState(player_id, inst.box_id)

      -- Textbox is fully gone ? NOW unlock input and clear instance
      if not bd then
        -- Fire on_complete exactly once when the textbox is fully removed
        if inst.on_complete and not inst._on_complete_ran then
          inst._on_complete_ran = true
          pcall(inst.on_complete)
        end

        if inst.opts and inst.opts.input_mode == C.InputMode.DIALOGUE_OWNS_INPUT then
          set_input_locked(player_id, false)
        end
        Dialogue.instances[player_id] = nil

      else
        -- While closing animation is running, eat all input
        if inst.closing then
          Input.consume(player_id)
          Input.swallow(player_id, 0.05)

        else
          -- Prevent confirm carry when entering WAITING
          if state == "waiting" and inst.last_state ~= "waiting" then
            Input.consume(player_id)
            Input.swallow(player_id, 0.08)
          end
          inst.last_state = state

          -- CANCEL (B)
          if Input.pop(player_id, "cancel") then
            local beh = (inst.opts and inst.opts.cancel_behavior) or "battle_network"

            -- Legacy behavior if you explicitly ask for it
            if beh == "close_dialogue" then
              close_instance(player_id, "cancel")

            -- Battle Network behavior:
            -- - while printing: acts like confirm-fast-forward
            -- - while waiting/completed: does nothing
            elseif beh == "battle_network" then
              if state == "printing" then
                if inst.opts.confirm_during_typing then
                  Displayer.Text.advance_text_box(player_id, inst.box_id)
                end
              else
                -- waiting/completed: do nothing
                -- (we already popped it, so it can't queue)
              end

            -- Fully ignore B if desired
            elseif beh == "ignore" then
              -- do nothing
            end

          -- CONFIRM (A)
          elseif Input.pop(player_id, "confirm") then
            if state == "printing" then
              if inst.opts.confirm_during_typing then
                Displayer.Text.advance_text_box(player_id, inst.box_id)
              end

            elseif state == "waiting" then
              Displayer.Text.advance_text_box(player_id, inst.box_id)

              -- If advancing caused removal or completion, begin close
              local bd2 = Displayer.Text.getTextBoxData(player_id, inst.box_id)
              local st2 = Displayer.Text.getTextBoxState(player_id, inst.box_id)
              if not bd2 or st2 == "completed" then
                close_instance(player_id, "finish")
              end

            elseif state == "completed" then
              close_instance(player_id, "finish")
            end
          end
        end
      end
    end
  end)
end


--=====================================================
-- Public API
--=====================================================

function Dialogue.is_active(player_id)
  return Dialogue.instances[player_id] ~= nil
end

function Dialogue.prompt_yesno(player_id, opts)
  return Prompt.yesno(player_id, opts)
end

function Dialogue.prompt_menu(player_id, opts)
  return PromptVertical.menu(player_id, opts)
end

function Dialogue.start(player_id, script, opts)
  ensure_listener()
  attach_tick()
  if _G and _G.NG_TEXTBOX_DEBUG then
    print("[TBDBG] Dialogue.start player=" .. tostring(player_id) .. " active=" .. tostring(Dialogue.instances[player_id] ~= nil))
  end

  if Dialogue.instances[player_id] then
    close_instance(player_id, "cancel")
  end

  local o = merge(default_opts(), opts or {})

  if o.input_mode == C.InputMode.DIALOGUE_OWNS_INPUT then
    local ok = set_input_locked(player_id, true)
    if o.debug then
      print("[Dialogue] set_input_locked(true) => " .. tostring(ok))
    end
  end

  -- swallow the interaction press so it doesn't instantly advance
  -- (but allow callers like prompts to opt out)
  if not o.from_prompt then
    Input.consume(player_id)
    Input.swallow(player_id, 0.10)
  end

  -- normalize script/pages into one text blob (net-games Displayer handles paging internally)
  local pages = {}
  if type(script) == "string" then
    pages = { script }
  elseif type(script) == "table" then
    if script.pages then
      for _, p in ipairs(script.pages) do
        table.insert(pages, p.text or "")
      end
    else
      for _, p in ipairs(script) do
        table.insert(pages, tostring(p))
      end
    end
  else
    pages = { "" }
  end

  local full_text = table.concat(pages, "\n")

  --=====================================================
  -- UI passthrough (NPC can control sizing/styling)
  -- opts.ui (preferred) or opts.textbox (alias)
  --=====================================================
  local ui = o.ui or o.textbox or nil

  if ui then
    if ui.font         then o.font = ui.font end
    if ui.scale        then o.scale = ui.scale end
    if ui.z            then o.z = ui.z end
    if ui.typing_speed then o.typing_speed = ui.typing_speed end
    if ui.type_sfx_path   then o.type_sfx_path = ui.type_sfx_path end
    if ui.type_sfx_min_dt then o.type_sfx_min_dt = ui.type_sfx_min_dt end

    if ui.backdrop then
      if ui.backdrop.x then
        o.x = ui.backdrop.x + (ui.backdrop.padding_x or 0)
      end
      if ui.backdrop.y then
        o.y = ui.backdrop.y + (ui.backdrop.padding_y or 0)
      end
      if ui.backdrop.width then
        o.w = ui.backdrop.width - ((ui.backdrop.padding_x or 0) * 2)
      end
      if ui.backdrop.height then
        o.h = ui.backdrop.height - ((ui.backdrop.padding_y or 0) * 2)
      end
    end
  end

  if o.debug then
    print("[Dialogue] ui.font=" .. tostring(ui and ui.font) .. " -> o.font=" .. tostring(o.font))
  end

  local box_id = mk_box_id(player_id, ui)
  local backdrop = (ui and (ui.backdrop or ui.backdrop_config)) or nil

  -- If requested, reuse an existing box instead of creating a new one
  local reuse = (o.reuse_existing_box == true)
  local existing_bd = Displayer.Text.getTextBoxData(player_id, box_id)
  local can_reuse = reuse and existing_bd ~= nil and existing_bd.marked_for_removal ~= true

  local created

  local ops = {
    page_advance = o.page_advance,
    auto_advance_seconds = o.advance_delay,
    confirm_during_typing = o.confirm_during_typing,
    type_sfx_path = o.type_sfx_path,
    type_sfx_min_dt = o.type_sfx_min_dt,
    mugshot = (ui and ui.mugshot) or nil,

    -- IMPORTANT:
    -- Passing nameplate during reuse causes Nameplate:attach() to erase + restart the animation.
    -- So: only set nameplate when we are creating a new textbox.
    nameplate = nil,
  }

  if not can_reuse then
    ops.nameplate = (ui and ui.nameplate) or nil
  end


  if can_reuse and Displayer.Text.reset_text_box then
    created = Displayer.Text.reset_text_box(
      player_id, box_id, full_text,
      o.x, o.y, o.w, o.h,
      o.font, o.scale, o.z,
      backdrop,
      o.typing_speed,
      ops
    )
  else
    -- Create textbox (prefer snake_case wrapper if present, otherwise call createTextBox)
    if Displayer.Text.create_text_box then
      created = Displayer.Text.create_text_box(
        player_id, box_id, full_text,
        o.x, o.y, o.w, o.h,
        o.font, o.scale, o.z,
        backdrop,
        o.typing_speed,
        ops
      )
    else
      created = Displayer.Text.createTextBox(
        player_id, box_id, full_text,
        o.x, o.y, o.w, o.h,
        o.font, o.scale, o.z,
        backdrop,
        o.typing_speed,
        ops
      )
    end
  end

  -- SAFETY: If the textbox didn't actually register in TextDisplay,
  -- don't leave the player locked in an invisible dialogue.
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if not bd then
    if o.input_mode == C.InputMode.DIALOGUE_OWNS_INPUT then
      set_input_locked(player_id, false)
    end
    return nil
  end

  Dialogue.instances[player_id] = {
    player_id = player_id,
    box_id = box_id,
    opts = o,
    script = script,
    ui = ui,
    closing = false,

    -- Goal_1_5: allow callers to run logic after the dialogue fully ends
    on_complete = o.on_complete,
    _on_complete_ran = false,
  }


  if o.debug then
    print("[Dialogue] start OK player=" .. tostring(player_id) .. " box_id=" .. tostring(box_id) .. " reuse=" .. tostring(can_reuse))
  end

  return box_id
end


function Dialogue.close(player_id)
  close_instance(player_id, "cancel")
end

return Dialogue
