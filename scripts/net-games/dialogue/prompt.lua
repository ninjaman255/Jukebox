-- scripts/net-games/dialogue/prompt.lua
-- YES/NO prompt helper for net-games Dialogue (fixed + clean)

local Displayer  = require("scripts/net-games/displayer/displayer")
local Input      = require("scripts/net-games/input/input")
local FontSystem = require("scripts/net-games/displayer/font-system")


local Prompt = {}
Prompt.instances = {}
Prompt._tick_attached = false

-- Dedicated sprite id ONLY for the selector cursor (do NOT reuse textbox indicator sprite id)
local SELECTOR_SPRITE_ID = 5200

local CURSOR_MOVE_SFX_PATH = "/server/assets/net-games/sfx/cursor_move.ogg"
local function play_cursor_move_sfx(player_id)
  Net.provide_asset_for_player(player_id, CURSOR_MOVE_SFX_PATH)

  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, CURSOR_MOVE_SFX_PATH) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(player_id, CURSOR_MOVE_SFX_PATH) end)
  end
end



local LISTENER_ATTACHED = false
local function ensure_listener()
  if LISTENER_ATTACHED then return end
  LISTENER_ATTACHED = true
  Input.attach_virtual_input_listener()
end

local function set_input_locked(player_id, locked)
  if locked then
    if Net.lock_player_input then pcall(function() Net.lock_player_input(player_id) end) end
  else
    if Net.unlock_player_input then pcall(function() Net.unlock_player_input(player_id) end) end
  end
end

local function mk_id(player_id)
  return "ng_prompt_" .. tostring(player_id)
end

local function ensure_tick()
  if Prompt._tick_attached then return end
  Prompt._tick_attached = true

  Net:on("tick", function(event)
    for player_id, inst in pairs(Prompt.instances) do
      local state = Displayer.Text.getTextBoxState(player_id, inst.box_id)
      if not state then
        Prompt.close(player_id, "textbox_missing")
      else
        inst:update(event.delta_time or 0)
      end
    end
  end)
end

--========================
-- Selector cursor drawing
--========================
local function ensure_selector_cursor_allocated(player_id)
  Net.provide_asset_for_player(player_id, "/server/assets/net-games/text_cursor.png")
  Net.provide_asset_for_player(player_id, "/server/assets/net-games/text_cursor.animation")

  Net.player_alloc_sprite(player_id, SELECTOR_SPRITE_ID, {
    texture_path = "/server/assets/net-games/text_cursor.png",
    anim_path    = "/server/assets/net-games/text_cursor.animation",
    anim_state   = "CURSOR_RIGHT",
  })
end

local function selector_draw(player_id, draw_id, x, y, z, scale)
  ensure_selector_cursor_allocated(player_id)

  Net.player_draw_sprite(player_id, SELECTOR_SPRITE_ID, {
    id = draw_id,
    x = x,
    y = y,
    z = z,
    sx = scale,
    sy = scale,
    anim_state = "CURSOR_RIGHT",
  })
end

local function selector_erase(player_id, draw_id)
  Net.player_erase_sprite(player_id, draw_id)
end

--========================
-- UI normalize (padding)
--========================
local function normalize_ui(ui)
  local o = {
    box_id = ui.box_id,
    font  = ui.font or "THIN_BLACK",
    scale = ui.scale or 2.0,
    z     = ui.z or 100,

    x = ui.x or 8,
    y = ui.y or 110,
    w = ui.w or 224,
    h = ui.h or 42,

    backdrop = ui.backdrop or ui.backdrop_config or nil,
    mugshot  = ui.mugshot or nil,
    nameplate = ui.nameplate,


    typing_speed = ui.typing_speed or 99999,
    type_sfx_path = ui.type_sfx_path,
    type_sfx_min_dt = ui.type_sfx_min_dt,
  }

  if o.backdrop then
    local px = o.backdrop.padding_x or 0
    local py = o.backdrop.padding_y or 0
    if o.backdrop.x      then o.x = o.backdrop.x + px end
    if o.backdrop.y      then o.y = o.backdrop.y + py end
    if o.backdrop.width  then o.w = o.backdrop.width  - (px * 2) end
    if o.backdrop.height then o.h = o.backdrop.height - (py * 2) end
  end

  return o
end

--========================
-- Text building (auto paginate, reserve options line)
--========================
local OPTIONS_INDENT = "       " -- 7 spaces

local function join_lines(lines)
  return table.concat(lines, "\n")
end

local function build_yesno_text_from_wrapped(question_lines, _max_lines_per_page)
  -- Locked “official” layout:
  -- line 1-2 = question text
  -- line 3   = "Yes    No"
  local MAX_LINES_PER_PAGE = 3
  local ROOM = 2 -- lines available for question before options

  local pages = {}
  local chunk = {}

  for i = 1, #question_lines do
    table.insert(chunk, question_lines[i])

    -- Flush question-only pages when we have more lines coming.
    if #chunk >= ROOM and i < #question_lines then
      table.insert(pages, join_lines(chunk))
      chunk = {}
    end
  end

  -- Final page: pad so options ALWAYS end up on line 3
  while #chunk < ROOM do
    table.insert(chunk, "")
  end

  table.insert(chunk, OPTIONS_INDENT .. "Yes    No")
  table.insert(pages, join_lines(chunk))

  -- formfeed => new page
  return table.concat(pages, "\f")
end


local function options_visible_on_current_page(player_id, box_id)
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if not bd or not bd.pages then return false end

  local p = bd.current_page or 1
  local page = bd.pages[p]
  if not page then return false end

  for i = 1, #page do
    if tostring(page[i] or ""):find("Yes") then
      return true
    end
  end

  return false
end

--========================
-- Cursor placement
--========================
local function yesno_cursor_pos(player_id, box_id, ui_norm, selection)
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if not bd then
    return 20, 120
  end

  local scale  = bd.scale or ui_norm.scale or 2.0
  local font   = bd.font  or ui_norm.font  or "THIN_BLACK"
  local line_h = bd._line_height_px or (12 * scale)

  local options_line = 2
  local curp = bd.current_page or 1

  if bd.pages and bd.pages[curp] then
    local lines = bd.pages[curp]
    for i = 1, #lines do
      local s = tostring(lines[i] or "")
      if s:find("Yes") then
        options_line = i
        break
      end
    end
  end

  local base_x = bd.inner_x or ((bd.x or 0) + (bd.padding_x or 0))
  local base_y = bd.inner_y or ((bd.y or 0) + (bd.padding_y or 0))

  if bd.line_x_offsets and bd.line_x_offsets[options_line] then
    base_x = base_x + bd.line_x_offsets[options_line]
  end

  local options_y = base_y + ((options_line - 1) * line_h)

  local yes_prefix = OPTIONS_INDENT
  local no_prefix  = OPTIONS_INDENT .. "Yes    "

  local yes_x = base_x + FontSystem:getTextWidth(yes_prefix, font, scale)
  local no_x  = base_x + FontSystem:getTextWidth(no_prefix,  font, scale)

  local cursor_h = 13 * scale
  local left_of_word = 6 * scale
  local down_in_line = 9 * scale

  local target_x = (selection == 1) and yes_x or no_x
  local cx = target_x - left_of_word
  local cy = options_y + down_in_line + ((line_h - cursor_h) * 0.5)

  return cx, cy
end

--========================
-- Instance
--========================
local PromptInstance = {}
PromptInstance.__index = PromptInstance

function PromptInstance:new(player_id, opts)
  local o = setmetatable({}, self)

  o.player_id = player_id
  o.box_id = (opts and opts.ui and opts.ui.box_id) or mk_id(player_id)

  o.ui = normalize_ui((opts and opts.ui) or {})
  o.question  = (opts and opts.question) or "Continue?"
  o.on_yes    = (opts and opts.on_yes) or function() end
  o.on_no     = (opts and opts.on_no) or function() end
  o.on_cancel = (opts and opts.on_cancel) or function() end

  -- cancel_behavior:
  --   "select_no" (default): B moves to No, then B confirms No
  --   "close"              : legacy behavior (B closes prompt + on_cancel)
  --   "ignore"             : B does nothing
  o.cancel_behavior = (opts and opts.cancel_behavior) or "select_no"
  o.reuse_existing_box = (opts and opts.reuse_existing_box == true)


  o.ready_for_input = false
  o.selection = 1
  o.cursor_id = o.box_id .. "_selcursor"
  o.cursor_phase = 0
  o.cursor_base_x = nil
  o.cursor_base_y = nil


  o:render_initial()
  return o
end

function PromptInstance:render_initial()
  local ui = self.ui
  local player_id = self.player_id

  -- Helper: shallow copy so we can safely override open/close seconds for the temp wrap box
  local function copy_table(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
  end

  -- PASS 1: render question-only into a TEMP box_id to let TextDisplay wrap for this geometry
  local question_only = tostring(self.question or "Continue?")
  local tmp_box_id = self.box_id .. "__wraptmp"

  -- Kill any leftover temp box from a prior run (only affects temp)
  Displayer.Text.removeTextBox(player_id, tmp_box_id)

  -- IMPORTANT: temp box should NOT animate (prevents open flicker during wrap-measure)
  local tmp_backdrop = copy_table(ui.backdrop)
  tmp_backdrop.open_seconds = 0
  tmp_backdrop.close_seconds = 0

  local tmp_ops = {
    page_advance = "auto_advance",
    auto_advance_seconds = 999999,
    confirm_during_typing = false,
    type_sfx_path = ui.type_sfx_path,
    type_sfx_min_dt = ui.type_sfx_min_dt,
    mugshot = ui.mugshot,
    wrap_opts = { allow_leading_spaces = true },

    -- also force no open wait from opts (TextDisplay reads opts.open_seconds first)
    open_seconds = 0,
    close_seconds = 0,
  }

  if Displayer.Text.create_text_box then
    Displayer.Text.create_text_box(
      player_id, tmp_box_id, question_only,
      ui.x, ui.y, ui.w, ui.h,
      ui.font, ui.scale, ui.z,
      tmp_backdrop,
      ui.typing_speed,
      tmp_ops
    )
  else
    Displayer.Text.createTextBox(
      player_id, tmp_box_id, question_only,
      ui.x, ui.y, ui.w, ui.h,
      ui.font, ui.scale, ui.z,
      tmp_backdrop,
      ui.typing_speed,
      tmp_ops
    )
  end

  local bd = Displayer.Text.getTextBoxData(player_id, tmp_box_id)

  local q_lines = {}
  if bd and bd.pages then
    for p = 1, #bd.pages do
      for l = 1, #bd.pages[p] do
        table.insert(q_lines, tostring(bd.pages[p][l] or ""))
      end
    end
  end
  if #q_lines == 0 then q_lines = { question_only } end

  local max_lines = 3
  if ui.backdrop and ui.backdrop.max_lines then
    max_lines = tonumber(ui.backdrop.max_lines) or 3
  end

  local text = build_yesno_text_from_wrapped(q_lines, max_lines)

  -- Remove the TEMP box only (never touch the real prompt box yet)
  Displayer.Text.removeTextBox(player_id, tmp_box_id)

  -- PASS 2: create the real prompt box ONCE (this is the one the player sees)
  
    -- SAFETY: if the real prompt box_id already exists for ANY reason,
  -- do NOT "create" over it (createTextBox can collision-ignore and leave stale state).
  -- If caller wants reuse: reset. Otherwise: remove then create clean.
  local existing_real = Displayer.Text.getTextBoxData(player_id, self.box_id)
  if existing_real then
    if self.reuse_existing_box then
      -- we'll reset a few lines below using the normal reset path
    else
      Displayer.Text.removeTextBox(player_id, self.box_id)
    end
  end

  -- If you want open animation here, it should come from ui.backdrop.open_seconds
  local ops = {
    page_advance = "wait_for_confirm",
    auto_advance_seconds = 999999,
    confirm_during_typing = true,
    type_sfx_path = ui.type_sfx_path,
    type_sfx_min_dt = ui.type_sfx_min_dt,
    mugshot = ui.mugshot,
    nameplate = ui.nameplate,
    wrap_opts = { allow_leading_spaces = true },
  }

  -- If we're reusing an existing textbox, don't reapply the nameplate (prevents flicker)
  if self.reuse_existing_box then
    ops.nameplate = nil
  end

  if self.reuse_existing_box then
    -- ALWAYS reset-in-place when reusing
    if Displayer.Text.reset_text_box then
      Displayer.Text.reset_text_box(
        player_id, self.box_id, text,
        ui.x, ui.y, ui.w, ui.h,
        ui.font, ui.scale, ui.z,
        ui.backdrop,
        ui.typing_speed,
        ops
      )
    else
      Displayer.Text.resetTextBox(
        player_id, self.box_id, text,
        ui.x, ui.y, ui.w, ui.h,
        ui.font, ui.scale, ui.z,
        ui.backdrop,
        ui.typing_speed,
        ops
      )
    end
  else
    -- ALWAYS create clean (we removed any existing box above)
    if Displayer.Text.create_text_box then
      Displayer.Text.create_text_box(
        player_id, self.box_id, text,
        ui.x, ui.y, ui.w, ui.h,
        ui.font, ui.scale, ui.z,
        ui.backdrop,
        ui.typing_speed,
        ops
      )
    else
      Displayer.Text.createTextBox(
        player_id, self.box_id, text,
        ui.x, ui.y, ui.w, ui.h,
        ui.font, ui.scale, ui.z,
        ui.backdrop,
        ui.typing_speed,
        ops
      )
    end
  end
end
 


function PromptInstance:render_cursor()
  local ui = self.ui
  local player_id = self.player_id

  local cx, cy = yesno_cursor_pos(player_id, self.box_id, ui, self.selection)
  self.cursor_base_x = cx
  self.cursor_base_y = cy

  -- draw once immediately (no erase needed every time)
  selector_draw(player_id, self.cursor_id, cx, cy, ui.z + 2, ui.scale)
end

function PromptInstance:update(dt)
  local player_id = self.player_id
  local st = Displayer.Text.getTextBoxState(player_id, self.box_id)

  -- Toggle the textbox "next" indicator:
  -- show it while paging prompt text, hide it when Yes/No is visible.
  local bd = Displayer.Text.getTextBoxData(player_id, self.box_id)
  if bd and bd.backdrop and bd.backdrop.indicator then
    bd.backdrop.indicator.enabled = not options_visible_on_current_page(player_id, self.box_id)
  end

  -- While typing: allow "hold confirm" to fast-forward (like normal dialogue),
  -- and ALSO clear the confirm edge so it can't later auto-select YES.
  if st == "printing" then
    -- never allow movement keys to queue
    Input.pop(player_id, "left")
    Input.pop(player_id, "right")
    Input.pop(player_id, "up")
    Input.pop(player_id, "down")
    Input.pop(player_id, "cancel")

    if Input.is_down(player_id, "confirm") then
      -- Clear the one-shot edge if it exists (prevents carry-press into YES)
      Input.pop(player_id, "confirm")

      -- Fast-forward (TextDisplay now stops at next {p_#} pause boundary)
      Displayer.Text.advance_text_box(player_id, self.box_id)
    end

    return
  end

  if not self.ready_for_input then
    -- While options are NOT visible, never allow directional input to queue
    Input.pop(player_id, "left")
    Input.pop(player_id, "right")
    Input.pop(player_id, "up")
    Input.pop(player_id, "down")

    -- Become ready ONLY when the options line is actually visible
    if (st == "waiting" or st == "completed") and options_visible_on_current_page(player_id, self.box_id) then
      self.ready_for_input = true

      -- Avoid carry-press: if they're holding ANY relevant key, force release
      local held = {}
      if Input.is_down(player_id, "left")    then table.insert(held, "left")    end
      if Input.is_down(player_id, "right")   then table.insert(held, "right")   end
      if Input.is_down(player_id, "up")      then table.insert(held, "up")      end
      if Input.is_down(player_id, "down")    then table.insert(held, "down")    end
      if Input.is_down(player_id, "confirm") then table.insert(held, "confirm") end

      if #held > 0 then
        Input.consume(player_id)
        Input.require_release(player_id, held)
      end

      self:render_cursor()
      return
    end

    -- If we're waiting but options aren't visible yet, confirm advances pages
    if st == "waiting" and Input.pop(player_id, "confirm") then
      Displayer.Text.advance_text_box(player_id, self.box_id)

      -- Must release before next confirm can register (prevents hold-spam through pages)
      Input.consume(player_id)
      Input.require_release(player_id, { "confirm" })

      return
    end

    -- Cancel does nothing until options are visible (prevents queued cancel)
    Input.pop(player_id, "cancel")
    return
  end

  -- READY: left/right toggles selection
  -- If options are visible and we're ready, animate the selector cursor (push -> snap loop)
  if self.ready_for_input and options_visible_on_current_page(player_id, self.box_id) then
    dt = math.min(dt or 0, 1/30)

    -- Tune these two for feel:
    local speed  = 3.8
    local amp    = 2.0 * (self.ui.scale or 1.0)

    self.cursor_phase = (self.cursor_phase or 0) + (dt * speed)

    -- 0..1 repeating
    local t = self.cursor_phase % 1.0

    -- Ease-out ramp
    local eased = 1.0 - (1.0 - t) * (1.0 - t)
    local push = eased * amp

    if self.cursor_base_x and self.cursor_base_y then
      selector_draw(
        player_id,
        self.cursor_id,
        self.cursor_base_x + push,
        self.cursor_base_y,
        (self.ui.z or 100) + 2,
        self.ui.scale or 2.0
      )
    end
  end

  if Input.pop(player_id, "left") or Input.pop(player_id, "right") then
    self.selection = (self.selection == 1) and 2 or 1
    play_cursor_move_sfx(player_id)
    self:render_cursor()
    return
  end

  -- Confirm chooses
  if Input.pop(player_id, "confirm") then
    -- keep the textbox alive so Dialogue can reuse it
    Prompt.close(player_id, "confirm", { keep_textbox = true })
    if self.selection == 1 then self.on_yes() else self.on_no() end
    return
  end


  -- Cancel behavior (B)
  if Input.pop(player_id, "cancel") then
    local beh = self.cancel_behavior or "select_no"

    -- Legacy: B closes prompt immediately
    if beh == "close" then
      Prompt.close(player_id, "cancel")
      self.on_cancel()
      return
    end

    -- Optional: ignore B completely
    if beh == "ignore" then
      return
    end

    -- Default: "select_no"
    -- 1st B: move to No
    if self.selection ~= 2 then
      self.selection = 2
      play_cursor_move_sfx(player_id)
      self:render_cursor()
      return
    end

    -- 2nd B (already on No): confirm No
    Prompt.close(player_id, "cancel_no", { keep_textbox = true })
    self.on_no()
    return

  end

end


--========================
-- Public API
--========================
function Prompt.yesno(player_id, opts)
  ensure_listener()
  ensure_tick()

  if Prompt.instances[player_id] then
    Prompt.close(player_id, "replace")
  end

  set_input_locked(player_id, true)

  -- swallow interaction press
  Input.consume(player_id)

  local inst = PromptInstance:new(player_id, opts or {})
  Prompt.instances[player_id] = inst
  return inst.box_id
end

function Prompt.close(player_id, reason, opts)
  local inst = Prompt.instances[player_id]
  if not inst then return end

  opts = opts or {}
  local keep = (opts.keep_textbox == true)

  -- Always erase the selector cursor (prompt-owned)
  selector_erase(player_id, inst.cursor_id)

  if not keep then
    -- Normal behavior: close the textbox UI
    Displayer.Text.closeTextBox(player_id, inst.box_id)
  else
    -- Handoff behavior: keep the textbox UI alive, just swallow input so it doesn't
    -- instantly advance the next Dialogue that reuses this box.

    -- IMPORTANT:
    -- Prompt hides the textbox "next" indicator while options are visible.
    -- If we hand off and KEEP the textbox, the prompt stops updating, so the
    -- indicator can remain stuck OFF for the next dialogue.
    local bd = Displayer.Text.getTextBoxData(player_id, inst.box_id)
    if bd and bd.backdrop and bd.backdrop.indicator then
      bd.backdrop.indicator.enabled = true
    end

    Input.consume(player_id)

-- Clear any sticky "require_release" so the next dialogue doesn't need a dummy press
Input.clear_require_release(player_id, { "confirm", "cancel" })

    Input.swallow(player_id, 0.10)

  end

  set_input_locked(player_id, false)

  -- Clean exit
  if not keep then
    Input.consume(player_id)

    if Input.is_down(player_id, "confirm") or Input.is_down(player_id, "cancel") then
      Input.require_release(player_id, { "confirm", "cancel" })
    end
  end

  Prompt.instances[player_id] = nil
end


return Prompt
