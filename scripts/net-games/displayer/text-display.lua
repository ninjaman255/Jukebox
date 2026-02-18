--=====================================================
-- text-display.lua
-- Text Display System with Marquee and Optional Backdrop Support
--
-- IMPORTANT CHANGE:
--  - No more auto-alloc/provide of marquee-backdrop on player_join.
--  - Backdrops are LAZY: only allocated/provided when actually used.
--  - Default backdrop texture_path is nil (library should not assume assets exist).
--=====================================================
local TextDisplay = {}
TextDisplay.__index = TextDisplay

local Nameplate = require("scripts/net-games/displayer/nameplate")

-- ===== TextBox Debug =====
local TBDBG = true
local function tbdbg(box_data, player_id, box_id, msg)
  if not TBDBG then return end
  local t = os.clock()
  local tok = box_data and box_data._dbg_token or "no-token"
  print(string.format("[TBDBG t=%.3f p=%s box=%s tok=%s] %s",
    t, tostring(player_id), tostring(box_id), tostring(tok), tostring(msg)))
end

local function stacktag()
  -- cheap-ish: gives you a callsite without spamming a full traceback
  local info = debug.getinfo(3, "Sl")
  if not info then return "unknown" end
  return tostring(info.short_src) .. ":" .. tostring(info.currentline)
end



-- =====================================================
-- DEBUG: Textbox lifecycle instrumentation
-- =====================================================
local function _ng_dbg_enabled()
  return _G and _G.NG_TEXTBOX_DEBUG == true
end

local function _ng_dbg_trace()
  return _G and _G.NG_TEXTBOX_DEBUG_TRACE == true
end

local function _ng_now()
  -- os.clock() is monotonic-ish and good for sequencing
  return os.clock()
end

local function _ng_dbg(player_id, box_id, msg, extra)
  if not _ng_dbg_enabled() then return end
  local t = string.format("%.3f", _ng_now())
  local prefix = "[TBDBG t=" .. t .. " p=" .. tostring(player_id) .. " box=" .. tostring(box_id) .. "] "
  print(prefix .. tostring(msg))
  if extra then
    print(prefix .. tostring(extra))
  end
  if _ng_dbg_trace() then
    print(prefix .. debug.traceback("", 2))
  end
end


-- Normalize "loops" option:
-- nil/true  => infinite (default)
-- false/"once"/1 => once
-- number>=1 => that many passes
local function _normalize_loops(v)
    if v == nil or v == true then return nil end
    if v == false or v == "once" then return 1 end
    local n = tonumber(v)
    if n then
        n = math.floor(n)
        if n < 1 then return 1 end
        return n
    end
    return nil
end

--=====================================================
-- Markup parsing
-- Supports:
--   {p_1} or {p_0.25}  => pause seconds
--   {end_line}        => forced newline
--   {end_page}        => forced page break
-- Unknown tags are treated literally (so you can extend later).
--=====================================================

local function parse_markup_ops(text)
  local ops = {}
  text = tostring(text or "")

  local i = 1
  while i <= #text do
    local ch = text:sub(i, i)

    if ch == "{" then
      local close = text:find("}", i + 1, true)
      if close then
        local tag = text:sub(i + 1, close - 1) -- inside braces

        -- {p_0.2} pauses
        local p = tag:match("^p_(%d+%.?%d*)$")
        if p then
          table.insert(ops, { type = "pause", seconds = tonumber(p) or 0 })
          i = close + 1
        elseif tag == "end_line" then
          table.insert(ops, { type = "newline" })
          i = close + 1
        elseif tag == "end_page" then
          table.insert(ops, { type = "newpage" })
          i = close + 1
        else
          -- Unknown tag => treat literally "{...}"
          for j = i, close do
            table.insert(ops, { type = "char", ch = text:sub(j, j) })
          end
          i = close + 1
        end
      else
        -- No closing brace; treat as literal
        table.insert(ops, { type = "char", ch = ch })
        i = i + 1
      end
    else
      table.insert(ops, { type = "char", ch = ch })
      i = i + 1
    end
  end

  return ops
end

-- How many visible characters have been printed so far (global count across pages/lines)
local function get_printed_char_count(box_data)
  local count = 0

  -- completed pages
  for p = 1, (box_data.current_page - 1) do
    local page = box_data.pages[p]
    if page then
      for _, line in ipairs(page) do
        count = count + #line
      end
    end
  end

  -- completed lines in current page
  local page = box_data.pages[box_data.current_page]
  if page then
    for l = 1, (box_data.current_line - 1) do
      local line = page[l]
      if line then count = count + #line end
    end
  end

  -- printed chars in current line
  count = count + (box_data.current_char or 0)

  return count
end


--=====================================================
-- Glyph normalization + animation state mapping
--=====================================================

-- Converts smart punctuation into ASCII equivalents so your font anim states can match.
local function normalize_glyph(raw)
  if not raw or raw == "" then return nil end
  if raw == " " then return " " end

  -- smart punctuation -> ascii
  if raw == "’" then raw = "'" end
  if raw == "“" or raw == "”" then raw = '"' end
  if raw == "–" or raw == "—" then raw = "-" end

  return raw
end

local function normalize_text(text)
  if not text or text == "" then return text end

  -- =====================================================
  -- HARD SANITIZE: prevent "blank first letter" issues
  -- - strip Windows CR (CRLF -> LF leaves '\r' behind)
  -- - strip UTF-8 BOM if it ever sneaks in
  -- - convert NBSP to normal space
  -- =====================================================
  text = text:gsub("\r", "")
  text = text:gsub("\239\187\191", "") -- UTF-8 BOM
  text = text:gsub("\194\160", " ")    -- NBSP

  -- UTF-8 smart punctuation
  text = text:gsub("\x92", "'"):gsub("\x91", "'")
  text = text:gsub("\x93", '"'):gsub("\x94", '"')
  text = text:gsub("\x96", "-"):gsub("\x97", "-")
  text = text:gsub("\x85", "...")

  -- CP1252 bytes (common on Windows)
  local b = string.char
  text = text:gsub(b(0x91), "'"):gsub(b(0x92), "'")
  text = text:gsub(b(0x93), '"'):gsub(b(0x94), '"')
  text = text:gsub(b(0x96), "-"):gsub(b(0x97), "-")
  text = text:gsub(b(0x85), "...")

  return text
end



-- Match FontSystem's anim naming: strip trailing "_BLACK" for anim_state prefixes
local function anim_prefix_for_font(font_name)
  return (font_name and font_name:gsub("_BLACK$", "")) or font_name
end

-- Returns the font anim_state string for a character, or nil for spaces/unsupported.
local function anim_state_for_char(font_name, raw)
  local c = normalize_glyph(raw)
  if not c or c == " " then return nil end

  local prefix = anim_prefix_for_font(font_name)

  -- lowercase naming scheme (matches your font states)
  if c:match("%l") then
    return prefix .. "_LOWER_" .. c:upper()
  end

  -- double quote naming scheme
  if c == '"' then
    return prefix .. "_QUOTE"
  end

  return prefix .. "_" .. c
end

--=====================================================
-- Mugshot helpers
--=====================================================

local function _ceil_div(a, b)
  return math.floor((a + b - 1) / b)
end

-- Compute mugshot layout in PIXELS (after scale), and how many lines it occupies
local function compute_mug_layout(box_data)
  local mug = box_data.mugshot
  if not mug or not mug.enabled then return nil end

  local scale = mug.scale or box_data.scale or 2.0

  -- Reserve space (pixels). Prefer explicit reserve_w/h. Fallback to sprite_w/h if provided.
  local reserve_w = (mug.reserve_w or mug.sprite_w or 0) * scale
  local reserve_h = (mug.reserve_h or mug.sprite_h or 0) * scale

  -- Small gap between mug and text (pixels)
  local gap = (mug.gap_px ~= nil) and mug.gap_px or (3 * (box_data.scale or 2.0))

  local line_h = (box_data._line_height_px or (12 * (box_data.scale or 2.0)))
  local mug_lines = 0
  if reserve_h > 0 and line_h > 0 then
    mug_lines = _ceil_div(reserve_h, line_h)
  end

  return {
    scale = scale,
    reserve_w = reserve_w,
    reserve_h = reserve_h,
    gap = gap,
    lines = mug_lines
  }
end

local function line_height_px_for(font_name, scale, base_line_height)
  local lh = base_line_height or 12

  -- THIN needs extra breathing room
  if font_name == "THIN_BLACK" or font_name == "THIN" then
    lh = lh + 2 -- at scale 2 => +2px total
  end

  return lh * scale
end


function TextDisplay:init()
    self.player_texts = {}
    self.font_system = require("scripts/net-games/displayer/font-system")
    self.nameplate = Nameplate:new(self.font_system)

    -- Marquee speed definitions (pixels per second)
    self.marquee_speeds = {
        slow = 30,    -- 30 pixels per second
        medium = 60,  -- 60 pixels per second
        quick = 120   -- 120 pixels per second
    }

    -- Screen dimensions
    self.screen_width = 240
    self.screen_height = 160

    -- Backdrop sprite definition
    -- IMPORTANT: do not assume any default backdrop asset exists in the library.
    -- If a project wants one, set this.texture_path externally or in a fork.
    self.backdrop_sprite = {
        sprite_id = 5000,
        texture_path = nil, -- was: "/server/assets/net-games/displayer/marquee-backdrop.png"
        anim_path = nil
    }

    -- "Next" cursor sprite (BN-style confirm indicator)
    -- Put the asset here for now: /server/assets/net-games/textbox_next.png
    self.cursor_sprite = {
        sprite_id = 5100,
        texture_path = "/server/assets/net-games/textbox_next.png",
    }

    -- Text box settings
    self.text_box_settings = {
        default_speed = 30, -- Characters per second
        line_height = 12,   -- Increased from 10 to 12 for better spacing
        char_spacing = 1,   -- Consistent with font system
    }

    Net:on("player_join", function(event)
        self:setupPlayerTextDisplays(event.player_id)
    end)

    Net:on("player_disconnect", function(event)
        self:cleanupPlayerTextDisplays(event.player_id)
    end)

    -- Update marquees and text boxes every tick
    Net:on("tick", function(event)
        self:updateMarquees(event.delta_time)
        self:updateTextBoxes(event.delta_time)
    end)

    return self
end

--=====================================================
-- Player setup/cleanup
--=====================================================

function TextDisplay:setupPlayerTextDisplays(player_id)
    self.player_texts[player_id] = {
        active_texts = {},
        next_obj_id = 1,
        allocated_backdrop = false, -- kept for compatibility; no longer auto-alloc
        active_text_boxes = {},
        cursor_allocated = false,
        backdrop_allocated = {},
    }

    -- IMPORTANT:
    -- Do NOT auto-provide or allocate any backdrop here.
    -- Backdrops are now LAZY: only allocated when actually used.
end

function TextDisplay:cleanupPlayerTextDisplays(player_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        -- Remove all active texts
        for text_id, _ in pairs(player_data.active_texts) do
            self:removeText(player_id, text_id)
        end

        -- Remove all active text boxes
        for box_id, _ in pairs(player_data.active_text_boxes) do
            self:removeTextBox(player_id, box_id)
        end

        -- No global backdrop dealloc needed (lazy allocations are per text/box)
        self.player_texts[player_id] = nil
    end
end

--=====================================================
-- Remove text
--=====================================================

function TextDisplay:removeText(player_id, text_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if not text_data then return end

    -- Remove text display
    if text_data.type == "marquee" then
        -- Remove individual characters
        for _, char_data in ipairs(text_data.individual_chars or {}) do
            if char_data.obj_id then
                Net.player_erase_sprite(player_id, char_data.obj_id)
            end
        end
    else
        if text_data.display_id then
            self.font_system:eraseTextDisplay(player_id, text_data.display_id)
        end
    end

    -- Remove backdrop if it exists
    if text_data.backdrop_id then
        Net.player_erase_sprite(player_id, text_data.backdrop_id)
    end

    player_data.active_texts[text_id] = nil
end

--=====================================================
-- Text Box System
--=====================================================
function TextDisplay:createTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    z_order = z_order or 100
    speed = speed or self.text_box_settings.default_speed
    opts = opts or {}

    local type_sfx_path   = opts.type_sfx_path
    local type_sfx_min_dt = opts.type_sfx_min_dt

    if type_sfx_path then
      Net.provide_asset_for_player(player_id, type_sfx_path)
    end

    -- Behaviour options (additive / back-compat defaults)
    local page_advance = opts.page_advance or "auto_advance" -- "wait_for_confirm" | "auto_advance" | "auto_advance_or_confirm"
    local auto_advance_seconds = opts.auto_advance_seconds or 2.0
    local confirm_during_typing = (opts.confirm_during_typing ~= false)

        local player_data = self.player_texts[player_id]
    if not player_data then return nil end

    -- =====================================================
    -- SAFETY + DEBUG:
    -- If something calls createTextBox twice for the same box_id before the first one is removed,
    -- DO NOT hard-delete/recreate. That causes OPEN/CLOSE flicker once you add animations.
    -- Instead: ignore the duplicate create, and print a traceback so we can find the caller.
    -- =====================================================
local existing = player_data.active_text_boxes and player_data.active_text_boxes[box_id]
if existing and not existing.marked_for_removal then
  -- Only print once per living box to avoid log spam
  if not existing._dbg_reported_create_collision then
    existing._dbg_reported_create_collision = true

    local tb = "<debug.traceback unavailable>"
    if debug and type(debug.traceback) == "function" then
      tb = debug.traceback("", 2)
    end

    _ng_dbg(player_id, box_id,
      "CREATE COLLISION (ignored duplicate createTextBox)",
      "existing.state=" .. tostring(existing.state) ..
      " existing.token=" .. tostring(existing._dbg_token) ..
      " existing.created_at=" .. tostring(existing._dbg_created_at) ..
      " trace=" .. tostring(tb)
    )
  end

  return box_id
end


    -- Use backdrop config if provided, otherwise create default
    local actual_backdrop_config = backdrop_config or {
        x = x, y = y, width = width, height = height,
        padding_x = 0, padding_y = 0
    }

    -- Calculate text bounds within the box - ALWAYS use the backdrop config for positioning
    local padding_x = actual_backdrop_config.padding_x or 0
    local padding_y = actual_backdrop_config.padding_y or 0
    local inner_x = actual_backdrop_config.x + padding_x
    local inner_y = actual_backdrop_config.y + padding_y
    local inner_width = actual_backdrop_config.width - (padding_x * 2)
    local inner_height = actual_backdrop_config.height - (padding_y * 2)

    -- Mugshot support (wrap + per-line x offset)
    local mugshot = opts.mugshot or nil
    if mugshot and mugshot.enabled == nil and mugshot == true then
      mugshot = { enabled = true }
    end

    local wrap_opts = nil
    local mug_layout = nil

    if mugshot and mugshot.enabled then
      local tmp_box = {
        mugshot = mugshot,
        scale = scale,
        _line_height_px = line_height_px_for(font_name, scale, self.text_box_settings.line_height),
      }
      mug_layout = compute_mug_layout(tmp_box)

      if mug_layout and mug_layout.reserve_w > 0 and mug_layout.lines > 0 then
        local chars_per_pixel = ( ( ( (self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK)["A"] or 6) * scale ) + ((self.text_box_settings.char_spacing or 1) * scale) )
        local mug_chars = math.floor((mug_layout.reserve_w + mug_layout.gap) / chars_per_pixel)

        wrap_opts = {
          max_chars_for_line = function(line_idx_in_page, default_limit)
            if line_idx_in_page <= mug_layout.lines then
              return math.max(1, default_limit - mug_chars)
            end
            return default_limit
          end
        }
      end
    end

    -- Allow callers to override/extend wrapping behavior (ex: prompts)
    if opts and opts.wrap_opts then
      wrap_opts = wrap_opts or {}
      for k, v in pairs(opts.wrap_opts) do
        wrap_opts[k] = v
      end
    end

    text = normalize_text(text)


    -- Parse markup into ops
    local ops = parse_markup_ops(text)

    -- Build wrapped_text with pause sentinels (resolved AFTER wrapping)
    local pause_sentinels = {}  -- [sentinel_char] = seconds
    local pause_seq = 0
    local buf = {}

    for _, op in ipairs(ops) do
      if op.type == "char" then
        table.insert(buf, op.ch)
      elseif op.type == "newline" then
        table.insert(buf, "\n")
      elseif op.type == "newpage" then
        table.insert(buf, "\f")
      elseif op.type == "pause" then
        pause_seq = pause_seq + 1
        local prefix = "\127"              -- DEL
        local id = string.char(pause_seq)  -- 1..255
        table.insert(buf, prefix .. id)
        pause_sentinels[id] = (pause_sentinels[id] or 0) + (op.seconds or 0)
      end
    end

    local wrapped_text = table.concat(buf)

    -- Process text into pages with word wrapping (now respects \n and \f)
    local max_lines_override = actual_backdrop_config.max_lines
    local pages = self:wrapTextToPages(wrapped_text, font_name, scale, inner_width, inner_height, max_lines_override, wrap_opts)

    -- Resolve sentinels into pause_marks based on FINAL wrapped pages
    local pause_marks = {}
    local printed_count = 0

    for p = 1, #pages do
      for l = 1, #pages[p] do
        local line = pages[p][l]
        local out = {}

        local i = 1
        while i <= #line do
          local ch = line:sub(i, i)

          if ch == "\127" then
            local id = line:sub(i + 1, i + 1)
            local seconds = pause_sentinels[id]
            if seconds then
              pause_marks[printed_count] = (pause_marks[printed_count] or 0) + seconds
            end
            i = i + 2
          else
            table.insert(out, ch)
            printed_count = printed_count + 1
            i = i + 1
          end
        end

        pages[p][l] = table.concat(out)
      end
    end

    -- Calculate character delay based on speed (characters per second)
    local char_delay = 1.0 / speed

    -- OPEN animation control:
    local open_seconds =
      tonumber(opts.open_seconds) or
      tonumber(actual_backdrop_config.open_seconds) or
      0

    local initial_state = (open_seconds > 0) and "opening" or "printing"

    local text_box_data = {
        type = "text_box",
        box_id = box_id,
        x = actual_backdrop_config.x,
        y = actual_backdrop_config.y,
        width = actual_backdrop_config.width,
        height = actual_backdrop_config.height,
        inner_x = inner_x,
        inner_y = inner_y,
        inner_width = inner_width,
        inner_height = inner_height,
        font = font_name,
        scale = scale,
        z_order = z_order,
        speed = speed,
        char_delay = char_delay,
        pages = pages,
        current_page = 1,
        current_line = 1,
        current_char = 0,
        timer = 0,
        display_lines = {},
        pause_marks = pause_marks,
        pause_remaining = 0,
        ops = ops,
        mugshot = mugshot,
        mug_layout = mug_layout,
        line_x_offsets = {},
        _line_height_px = line_height_px_for(font_name, scale, self.text_box_settings.line_height),
        backdrop = actual_backdrop_config,
        backdrop_id = nil,
        _backdrop_allocated = false,
        type_sfx_path   = type_sfx_path,
        type_sfx_min_dt = type_sfx_min_dt,
        type_sfx_timer  = 0,
        type_sfx_count  = 0,
        page_advance = page_advance,
        auto_advance_seconds = auto_advance_seconds,
        confirm_during_typing = confirm_during_typing,

        -- OPEN animation bookkeeping
        open_seconds = open_seconds,
        open_timer = 0,
        _opening_started = false,

        state = initial_state,
        wait_timer = 0,
        padding_x = padding_x,
        padding_y = padding_y
    }

    -- Debug identity + lifetime (restores the “lived” usefulness)
    text_box_data._dbg_created_at = _ng_now()
    text_box_data._dbg_token = tostring(box_id) .. "#" .. tostring(math.floor(text_box_data._dbg_created_at * 1000))

    -- Build per-line X offsets so rendering matches reduced wrap width
    if mug_layout and mug_layout.reserve_w > 0 and mug_layout.lines > 0 then
      local offset_px = mug_layout.reserve_w + mug_layout.gap
      for i = 1, mug_layout.lines do
        text_box_data.line_x_offsets[i] = offset_px
      end
    end

    -- IMPORTANT:
    -- If we're opening, DO NOT draw panel here. Drawing here + drawing on opening-enter causes OPEN to be sent twice.
    if initial_state ~= "opening" then
      self:drawTextBoxBackdrop(player_id, box_id, text_box_data)
      self:drawTextBoxMugshot(player_id, box_id, text_box_data)
    end

    -- Optional BN nameplate
    if self.nameplate and opts and opts.nameplate then
      self.nameplate:attach(player_id, player_data, box_id, text_box_data, opts.nameplate)
    end

    player_data.active_text_boxes[box_id] = text_box_data

    if _ng_dbg_enabled() then
      _ng_dbg(player_id, box_id, "CREATE OK", "token=" .. tostring(text_box_data._dbg_token) .. " state=" .. tostring(text_box_data.state) .. " pages=" .. tostring(#pages))
    end

    return box_id
end

--=====================================================
-- Reset Text Box (REUSE existing UI)
-- Keeps the existing backdrop/nameplate/mugshot objects alive,
-- clears printed glyphs, rebuilds wrapped pages, and restarts printing.
--=====================================================
function TextDisplay:resetTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
  local player_data = self.player_texts[player_id]
  if not player_data then return nil end

  local box_data = player_data.active_text_boxes and player_data.active_text_boxes[box_id]

  -- If no existing box, fall back to create (so callers can safely "reset-or-create")
  if not box_data then
    return self:createTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
  end

  font_name = font_name or box_data.font or "THICK"
  scale     = scale     or box_data.scale or 2.0
  z_order   = z_order   or box_data.z_order or 100
  speed     = speed     or box_data.speed or self.text_box_settings.default_speed
  opts      = opts      or {}

  -- Ensure assets for typing sfx if changed
  local type_sfx_path   = opts.type_sfx_path or box_data.type_sfx_path
  local type_sfx_min_dt = opts.type_sfx_min_dt or box_data.type_sfx_min_dt
  if type_sfx_path then
    Net.provide_asset_for_player(player_id, type_sfx_path)
  end

  -- Behaviour options (keep current unless explicitly overridden)
  local page_advance =
    (opts.page_advance ~= nil and opts.page_advance)
    or box_data.page_advance
    or "auto_advance"

  local auto_advance_seconds =
    (opts.auto_advance_seconds ~= nil and opts.auto_advance_seconds)
    or box_data.auto_advance_seconds
    or 2.0

  local confirm_during_typing =
    (opts.confirm_during_typing ~= nil and opts.confirm_during_typing)
    or box_data.confirm_during_typing

  if confirm_during_typing == nil then confirm_during_typing = true end

  -- Keep old geometry unless caller overrides
  local bx = (x ~= nil and x) or box_data.x or 0
  local by = (y ~= nil and y) or box_data.y or 0
  local bw = (width  ~= nil and width)  or box_data.width  or 200
  local bh = (height ~= nil and height) or box_data.height or 100

  -- Backdrop config: keep the existing one unless caller supplies a new one
  local actual_backdrop_config = backdrop_config or box_data.backdrop or {
    x = bx, y = by, width = bw, height = bh,
    padding_x = 0, padding_y = 0
  }

  -- Calculate inner bounds (same logic as createTextBox)
  local padding_x = actual_backdrop_config.padding_x or 0
  local padding_y = actual_backdrop_config.padding_y or 0
  local inner_x = actual_backdrop_config.x + padding_x
  local inner_y = actual_backdrop_config.y + padding_y
  local inner_width = actual_backdrop_config.width - (padding_x * 2)
  local inner_height = actual_backdrop_config.height - (padding_y * 2)

  -- Mugshot support (wrap + per-line x offset)
  local mugshot = opts.mugshot
  if mugshot == nil then mugshot = box_data.mugshot end
  if mugshot and mugshot.enabled == nil and mugshot == true then
    mugshot = { enabled = true }
  end

  local wrap_opts = nil
  local mug_layout = nil

  if mugshot and mugshot.enabled then
    local tmp_box = {
      mugshot = mugshot,
      scale = scale,
      _line_height_px = line_height_px_for(font_name, scale, self.text_box_settings.line_height),
    }
    mug_layout = compute_mug_layout(tmp_box)

    if mug_layout and mug_layout.reserve_w > 0 and mug_layout.lines > 0 then
      local chars_per_pixel = ( ( ( (self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK)["A"] or 6) * scale ) + ((self.text_box_settings.char_spacing or 1) * scale) )
      local mug_chars = math.floor((mug_layout.reserve_w + mug_layout.gap) / chars_per_pixel)

      wrap_opts = {
        max_chars_for_line = function(line_idx_in_page, default_limit)
          if line_idx_in_page <= mug_layout.lines then
            return math.max(1, default_limit - mug_chars)
          end
          return default_limit
        end
      }
    end
  end

  -- Allow callers to override/extend wrapping behavior
  if opts and opts.wrap_opts then
    wrap_opts = wrap_opts or {}
    for k, v in pairs(opts.wrap_opts) do
      wrap_opts[k] = v
    end
  end

  -- Parse markup into ops (same logic as createTextBox)
  text = normalize_text(text)
  local ops = parse_markup_ops(text)

  -- Build wrapped_text with pause sentinels (resolved AFTER wrapping)
  local pause_sentinels = {}
  local pause_seq = 0
  local buf = {}

  for _, op in ipairs(ops) do
    if op.type == "char" then
      table.insert(buf, op.ch)
    elseif op.type == "newline" then
      table.insert(buf, "\n")
    elseif op.type == "newpage" then
      table.insert(buf, "\f")
    elseif op.type == "pause" then
      pause_seq = pause_seq + 1
      local prefix = "\127"
      local id = string.char(pause_seq)
      table.insert(buf, prefix .. id)
      pause_sentinels[id] = (pause_sentinels[id] or 0) + (op.seconds or 0)
    end
  end

  local wrapped_text = table.concat(buf)

  local max_lines_override = actual_backdrop_config.max_lines
  local pages = self:wrapTextToPages(wrapped_text, font_name, scale, inner_width, inner_height, max_lines_override, wrap_opts)

  -- Resolve sentinels into pause_marks based on FINAL wrapped pages
  local pause_marks = {}
  local printed_count = 0

  for p = 1, #pages do
    for l = 1, #pages[p] do
      local line = pages[p][l]
      local out = {}

      local i = 1
      while i <= #line do
        local ch = line:sub(i, i)

        if ch == "\127" then
          local id = line:sub(i + 1, i + 1)
          local seconds = pause_sentinels[id]
          if seconds then
            pause_marks[printed_count] = (pause_marks[printed_count] or 0) + seconds
          end
          i = i + 2
        else
          table.insert(out, ch)
          printed_count = printed_count + 1
          i = i + 1
        end
      end

      pages[p][l] = table.concat(out)
    end
  end

  -- Reset printed glyphs (text only). Do NOT erase backdrop or nameplate.
  self:clearTextBoxDisplay(player_id, box_id, box_data)

  -- If mugshot was removed, erase existing mug sprite
  if box_data.mug_id and (not mugshot or not mugshot.enabled) then
    Net.player_erase_sprite(player_id, box_data.mug_id)
    box_data.mug_id = nil
  end

  -- Update core data (preserving living sprite ids/backdrop_id)
  box_data.x = actual_backdrop_config.x
  box_data.y = actual_backdrop_config.y
  box_data.width  = actual_backdrop_config.width
  box_data.height = actual_backdrop_config.height

  box_data.inner_x = inner_x
  box_data.inner_y = inner_y
  box_data.inner_width  = inner_width
  box_data.inner_height = inner_height

  box_data.font  = font_name
  box_data.scale = scale
  box_data.z_order = z_order
  box_data.speed = speed
  box_data.char_delay = 1.0 / (speed or 30)

  box_data.pages = pages
  box_data.ops = ops

  box_data.current_page = 1
  box_data.current_line = 1
  box_data.current_char = 0

  box_data.timer = 0
  box_data.wait_timer = 0

  box_data.pause_marks = pause_marks
  box_data.pause_remaining = 0

  box_data.type_sfx_path   = type_sfx_path
  box_data.type_sfx_min_dt = type_sfx_min_dt
  box_data.type_sfx_timer  = 0
  box_data.type_sfx_count  = 0

  box_data.page_advance = page_advance
  box_data.auto_advance_seconds = auto_advance_seconds
  box_data.confirm_during_typing = confirm_during_typing

  box_data.mugshot = mugshot
  box_data.mug_layout = mug_layout
  box_data.line_x_offsets = {}
  box_data._line_height_px = line_height_px_for(font_name, scale, self.text_box_settings.line_height)

  box_data.backdrop = actual_backdrop_config
  box_data.padding_x = padding_x
  box_data.padding_y = padding_y

  -- IMPORTANT: reset should NOT re-open animation by default (prevents panel flicker)
  box_data.open_seconds = 0
  box_data.open_timer = 0
  box_data._opening_started = false

  -- Cancel a closing state if we were mid-close
  box_data.close_timer = 0
  box_data.state = "printing"

  -- Per-line X offsets for mugshot wrap
  if mug_layout and mug_layout.reserve_w > 0 and mug_layout.lines > 0 then
    local offset_px = mug_layout.reserve_w + mug_layout.gap
    for i = 1, mug_layout.lines do
      box_data.line_x_offsets[i] = offset_px
    end
  end

  -- Nameplate handling:
  -- - if opts.nameplate == false => remove
  -- - if opts.nameplate provided => (re)attach
  if self.nameplate then
    if opts.nameplate == false then
      self.nameplate:erase(player_id, player_data, box_data)
    elseif opts.nameplate ~= nil then
      self.nameplate:attach(player_id, player_data, box_id, box_data, opts.nameplate)
    end
  end

  -- Ensure panel/mug are visible + in correct anim state
  self:drawTextBoxBackdrop(player_id, box_id, box_data)
  self:drawTextBoxMugshot(player_id, box_id, box_data)

  if _ng_dbg_enabled() then
    _ng_dbg(player_id, box_id, "RESET OK",
      "token=" .. tostring(box_data._dbg_token) ..
      " state=" .. tostring(box_data.state) ..
      " pages=" .. tostring(#pages)
    )
  end

  return box_id
end


-- Separate backdrop drawing function for text boxes (lazy)
function TextDisplay:drawTextBoxBackdrop(player_id, box_id, box_data)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local style = (box_data.backdrop and box_data.backdrop.style) or "black_box"

    -- =====================================================
    -- Style: textbox_panel (regular BN textbox asset)
    -- IMPORTANT: must run BEFORE the early-return that checks self.backdrop_sprite
    -- =====================================================
    if style == "textbox_panel" then
        local sprite_id = 5201
        local tex  = "/server/assets/net-games/displayer/textbox.png"
        local anim = "/server/assets/net-games/displayer/textbox.animation"

        -- allocate once per player
        player_data.backdrop_allocated = player_data.backdrop_allocated or {}
        if not player_data.backdrop_allocated.textbox_panel then
            Net.provide_asset_for_player(player_id, tex)
            Net.provide_asset_for_player(player_id, anim)
            Net.player_alloc_sprite(player_id, sprite_id, {
                texture_path = tex,
                anim_path = anim,
                anim_state = "OPEN_IDLE",
            })
            player_data.backdrop_allocated.textbox_panel = true
        end

        local backdrop_id = box_id .. "_backdrop"
        local s = box_data.scale or 2.0
        local z = (box_data.z_order or 100) - 1

        -- Optional per-backdrop render offsets (moves ONLY the panel sprite, not the text)
        local ox = 0
        local oy = 0
        if box_data.backdrop then
          ox = tonumber(box_data.backdrop.render_offset_x) or 0
          oy = tonumber(box_data.backdrop.render_offset_y) or 0
        end

        -- NEW: support OPEN state (one-shot via edge trigger)
        local desired
        if box_data.state == "closing" then
          desired = "CLOSE"
        elseif box_data.state == "opening" then
          desired = "OPEN"
        else
          desired = "OPEN_IDLE"
        end

        -- Only send anim_state when it CHANGES (prevents restart/stuck)
        local anim_to_send = nil

        if box_data._panel_last_anim_state ~= desired then
          anim_to_send = desired
          box_data._panel_last_anim_state = desired

          if _ng_dbg_enabled() then
            _ng_dbg(player_id, box_id, "PANEL anim_state SENT => " .. tostring(desired),
              "tb_state=" .. tostring(box_data.state) ..
              " open_timer=" .. tostring(box_data.open_timer) ..
              " close_timer=" .. tostring(box_data.close_timer)
            )
          end
        end


        local draw = {
          id = backdrop_id,
          x  = box_data.x + ox,
          y  = box_data.y + oy,
          z  = z,
          sx = s,
          sy = s,
        }
        if anim_to_send then
          draw.anim_state = anim_to_send
        end

        -- APPLY OPTIONAL TINT (this is the "tint hook")
        local tint = box_data.backdrop
        if tint then
          draw.r = tint.r or 255
          draw.g = tint.g or 255
          draw.b = tint.b or 255
          draw.a = tint.a or tint.opacity or 255
          draw.color_mode = tint.color_mode or tint.mode
        end

        Net.player_draw_sprite(player_id, sprite_id, draw)
        box_data.backdrop_id = backdrop_id
        return
    end

    if style == "textbox_panel_frame_tint" then
      -- 1) draw normal textbox panel first (UNCHANGED UI)
      local base_sprite_id = 5201
      local base_tex  = "/server/assets/net-games/displayer/textbox.png"
      local base_anim = "/server/assets/net-games/displayer/textbox.animation"

      player_data.backdrop_allocated = player_data.backdrop_allocated or {}

      if not player_data.backdrop_allocated.textbox_panel then
        Net.provide_asset_for_player(player_id, base_tex)
        Net.provide_asset_for_player(player_id, base_anim)
        Net.player_alloc_sprite(player_id, base_sprite_id, {
          texture_path = base_tex,
          anim_path = base_anim,
          anim_state = "OPEN_IDLE",
        })
        player_data.backdrop_allocated.textbox_panel = true
      end

      local s = box_data.scale or 2.0
      local z = (box_data.z_order or 100) - 1

      local ox, oy = 0, 0
      if box_data.backdrop then
        ox = tonumber(box_data.backdrop.render_offset_x) or 0
        oy = tonumber(box_data.backdrop.render_offset_y) or 0
      end

      local x = box_data.x + ox
      local y = box_data.y + oy

      -- NEW: support OPEN state (one-shot via edge trigger)
      local desired
      if box_data.state == "closing" then
        desired = "CLOSE"
      elseif box_data.state == "opening" then
        desired = "OPEN"
      else
        desired = "OPEN_IDLE"
      end

      local anim_to_send = nil
      if box_data._panel_last_anim_state ~= desired then
        anim_to_send = desired
        box_data._panel_last_anim_state = desired
      end

      local base_id = box_id .. "_backdrop"
      local base_draw = {
        id = base_id,
        x = x, y = y,
        z = z,
        sx = s, sy = s,
      }
      if anim_to_send then
        base_draw.anim_state = anim_to_send
      end
      Net.player_draw_sprite(player_id, base_sprite_id, base_draw)
      box_data.backdrop_id = base_id

      -- 2) draw tinted frame overlay on top
      local frame_sprite_id = 5202
      local frame_tex = "/server/assets/net-games/displayer/textbox_frame_gray.png"

      if not player_data.backdrop_allocated.textbox_frame_gray then
        Net.provide_asset_for_player(player_id, frame_tex)
        -- reuse same anim file so frames match perfectly
        Net.provide_asset_for_player(player_id, base_anim)
        Net.player_alloc_sprite(player_id, frame_sprite_id, {
          texture_path = frame_tex,
          anim_path = base_anim,
          anim_state = "OPEN_IDLE",
        })
        player_data.backdrop_allocated.textbox_frame_gray = true
      end

      local tint = box_data.backdrop or {}
      local frame_id = box_id .. "_frame"

      local frame_draw = {
        id = frame_id,
        x = x, y = y,
        z = z + 0.01,
        sx = s, sy = s,

        r = tint.r or 80,
        g = tint.g or 255,
        b = tint.b or 80,
        a = tint.a or 255,
        color_mode = tint.color_mode or 2,
      }
      if anim_to_send then
        frame_draw.anim_state = anim_to_send
      end
      Net.player_draw_sprite(player_id, frame_sprite_id, frame_draw)
      box_data.frame_id = frame_id
      return
    end

    -- If no configured backdrop texture, do nothing.
    if not self.backdrop_sprite or not self.backdrop_sprite.texture_path then
        return
    end

    -- Remove old backdrop if it exists
    if box_data.backdrop_id then
        Net.player_erase_sprite(player_id, box_data.backdrop_id)
    end

    -- Lazy provide + alloc (ONLY when used)
    if not box_data._backdrop_allocated then
        Net.provide_asset_for_player(player_id, self.backdrop_sprite.texture_path)
        Net.player_alloc_sprite(player_id, self.backdrop_sprite.sprite_id, {
            texture_path = self.backdrop_sprite.texture_path
        })
        box_data._backdrop_allocated = true
    end

    local backdrop_id = box_id .. "_backdrop"

    Net.player_draw_sprite(
        player_id,
        self.backdrop_sprite.sprite_id,
        {
            id = backdrop_id,
            x = box_data.x,
            y = box_data.y,
            z = (box_data.z_order or 100) - 1, -- Behind the text
            sx = box_data.width,
            sy = box_data.height
        }
    )

    box_data.backdrop_id = backdrop_id
    box_data.backdrop_width = box_data.width
    box_data.backdrop_height = box_data.height
end


function TextDisplay:drawTextBoxMugshot(player_id, box_id, box_data)
  local mug = box_data.mugshot
  if not mug or not mug.enabled then return end
  if not mug.texture_path then return end

  local mug_id   = box_id .. "_mug"
  local sprite_id = mug.sprite_id or 5300

  local player_data = self.player_texts[player_id]
  if not player_data then return end
  player_data.mugshot_allocated = player_data.mugshot_allocated or {}

  -- allocation key: sprite_id + texture + anim
  local key = tostring(sprite_id) .. "|" .. tostring(mug.texture_path) .. "|" .. tostring(mug.anim_path or "")

  if not player_data.mugshot_allocated[key] then
    Net.provide_asset_for_player(player_id, mug.texture_path)
    if mug.anim_path then
      Net.provide_asset_for_player(player_id, mug.anim_path)
    end

    Net.player_alloc_sprite(player_id, sprite_id, {
      texture_path = mug.texture_path,
      anim_path    = mug.anim_path,
      anim_state   = mug.idle_anim_state or mug.anim_state or "IDLE",
    })

    player_data.mugshot_allocated[key] = true
  end

  -- scale
  local s = mug.scale or box_data.scale or 2.0

  -- match panel offsets
  local rx, ry = 0, 0
  if box_data.backdrop then
    rx = tonumber(box_data.backdrop.render_offset_x) or 0
    ry = tonumber(box_data.backdrop.render_offset_y) or 0
  end

  -- mug local offsets
  local ox = mug.offset_x or (2 * s)
  local oy = mug.offset_y or (2 * s)

-- TALK while characters are printing; IDLE otherwise
local desired_state = mug.idle_anim_state or mug.anim_state or "IDLE"

if box_data.state == "printing" then
  desired_state = mug.talk_anim_state or desired_state
end


-- Only push anim_state when it CHANGES, otherwise we restart the animation every draw.
box_data._mug_last_state = box_data._mug_last_state or nil

local draw_opts = {
  id = mug_id,
  x  = box_data.x + rx + ox,
  y  = box_data.y + ry + oy,
  z  = (box_data.z_order or 100) + (mug.z_bias or 0),
  sx = s,
  sy = s,
  opacity = box_data._mug_opacity or 255,

}

if box_data._mug_last_state ~= desired_state then
  draw_opts.anim_state = desired_state
  box_data._mug_last_state = desired_state
end

Net.player_draw_sprite(player_id, sprite_id, draw_opts)


  box_data.mug_id = mug_id
end




function TextDisplay:_ensureCursorAllocated(player_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return end
    if player_data.cursor_allocated then return end
    if not self.cursor_sprite or not self.cursor_sprite.texture_path then return end

    Net.provide_asset_for_player(player_id, self.cursor_sprite.texture_path)
    Net.player_alloc_sprite(player_id, self.cursor_sprite.sprite_id, {
        texture_path = self.cursor_sprite.texture_path
    })

    player_data.cursor_allocated = true
end

-- Wrap text into pages with word wrapping
function TextDisplay:wrapTextToPages(text, font_name, scale, max_width, max_height, max_lines_override, wrap_opts)
  local char_widths = self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK
  local default_char_width = char_widths["A"] or char_widths["0"] or 6
  local char_width = default_char_width * scale

  local base_spacing = self.text_box_settings.char_spacing or 1
  local scaled_spacing = base_spacing * scale

local base_lh = self.text_box_settings.line_height
if font_name == "THIN_BLACK" or font_name == "THIN" then
  base_lh = base_lh + 2  -- +1 at scale 2 => +2px
end
local line_height = base_lh * scale

  local chars_per_pixel = (char_width + scaled_spacing)
  local max_chars_per_line = math.floor(max_width / chars_per_pixel)

  wrap_opts = wrap_opts or {}
  local function line_limit(line_index_in_page)
    if type(wrap_opts.max_chars_for_line) == "function" then
      local v = wrap_opts.max_chars_for_line(line_index_in_page, max_chars_per_line)
      if type(v) == "number" then
        v = math.floor(v)
        if v >= 1 then return v end
      end
    end
    return max_chars_per_line
  end

  local max_lines_per_page = math.floor(max_height / line_height)
    if max_lines_override then
      max_lines_per_page = math.max(1, math.min(max_lines_per_page, tonumber(max_lines_override) or max_lines_per_page))
    end

  local pages = {}
  local current_page = {}
  local current_line = ""
  local current_line_chars = 0

  local function push_line(force_even_if_empty)
    if current_line_chars > 0 or force_even_if_empty then
      table.insert(current_page, current_line)
      if #current_page >= max_lines_per_page then
        table.insert(pages, current_page)
        current_page = {}
      end
    end
    current_line = ""
    current_line_chars = 0
  end

  local function push_page()
    -- flush any current line (if it has content)
    if current_line_chars > 0 then
      table.insert(current_page, current_line)
      current_line = ""
      current_line_chars = 0
    end
    if #current_page > 0 then
      table.insert(pages, current_page)
    else
      -- If user forced a page break on an empty page, preserve it as an empty page
      table.insert(pages, {})
    end
    current_page = {}
  end

  -- Tokenize: words + spaces + hard breaks (\n = newline, \f = pagebreak)
  local s = tostring(text or ""):gsub("\r\n", "\n")
  local tokens = {}
  local i = 1

  while i <= #s do
    local c = s:sub(i, i)

    if c == "\f" then
      table.insert(tokens, { t = "newpage" })
      i = i + 1

    elseif c == "\n" then
      table.insert(tokens, { t = "newline" })
      i = i + 1

    elseif c == " " then
      -- preserve exact run-length of spaces
      local j = i
      while j <= #s and s:sub(j, j) == " " do
        j = j + 1
      end
      table.insert(tokens, { t = "spaces", n = (j - i) })
      i = j

    elseif c:match("%s") then
      -- tabs etc => treat as one space
      table.insert(tokens, { t = "spaces", n = 1 })
      i = i + 1

    else
      local j = i
      while j <= #s do
        local cj = s:sub(j, j)
        if cj == "\n" or cj == "\f" or cj:match("%s") then break end
        j = j + 1
      end
      table.insert(tokens, { t = "word", v = s:sub(i, j - 1) })
      i = j
    end
  end


  local idx = 1
  while idx <= #tokens do
    local tok = tokens[idx]

    if tok.t == "newline" then
      -- hard line break (even if empty line)
      push_line(true)
      idx = idx + 1

    elseif tok.t == "newpage" then
      -- hard page break
      push_page()
      idx = idx + 1

    else
if tok.t == "spaces" then
  local allow_leading_spaces = wrap_opts and wrap_opts.allow_leading_spaces

  local n = tok.n or 1
  local limit = line_limit(#current_page + 1)

  if current_line_chars == 0 and not allow_leading_spaces then
    -- default behavior: drop leading spaces
    idx = idx + 1
  else
    -- keep spaces (including leading) if they fit
    if current_line_chars + n <= limit then
      current_line = current_line .. string.rep(" ", n)
      current_line_chars = current_line_chars + n
      idx = idx + 1
    else
      -- wrap; if we wrap, we drop spaces at the start of the new line
      push_line(false)
      idx = idx + 1
    end
  end


      else
        -- tok.t == "word"
        local word = tok.v
        local word_length = #word
        local total_chars = current_line_chars + word_length

        local limit = line_limit(#current_page + 1)
        if total_chars <= limit then
          current_line = current_line .. word
          current_line_chars = current_line_chars + word_length
          idx = idx + 1
        else
          if current_line_chars > 0 then
            push_line(false)
          else
            -- word is longer than line: split it
            local take = line_limit(#current_page + 1)
            local part = word:sub(1, take)
            current_line = part
            current_line_chars = #part
            push_line(false)

            local rest = word:sub(take + 1)
            if #rest > 0 then
              tokens[idx].v = rest
            else
              idx = idx + 1
            end
          end
        end
      end
    end
  end

  -- flush final line/page
  if current_line_chars > 0 then
    table.insert(current_page, current_line)
  end
  if #current_page > 0 then
    table.insert(pages, current_page)
  end

  return pages
end


--=====================================================
-- Text box ticking
--=====================================================
function TextDisplay:updateTextBoxCursor(player_id, box_id, box_data, delta)
    
local indicator_enabled = true
if box_data.backdrop and box_data.backdrop.indicator then
  indicator_enabled = (box_data.backdrop.indicator.enabled ~= false)
end


-- Show cursor only when the box is waiting AND confirm is meaningful
    local mode = box_data.page_advance or "auto_advance"
local should_show =
    indicator_enabled and
    (box_data.state == "waiting") and
    (mode == "wait_for_confirm" or mode == "auto_advance_or_confirm")

    local cursor_id = box_id .. "_cursor"

    if not should_show then
        if box_data.cursor_visible then
            Net.player_erase_sprite(player_id, cursor_id)
            box_data.cursor_visible = false
        end
        return
    end

    -- lazy allocate sprite
    self:_ensureCursorAllocated(player_id)

    -- bobbing
    delta = math.min(delta, 1/30)
    box_data.cursor_phase = (box_data.cursor_phase or 0) + (delta * 8.0) -- speed
    local amp = 1.2 * (box_data.scale or 1.0)                              -- amplitude
    local bob = math.sin(box_data.cursor_phase) * amp

    -- Position near bottom-right INSIDE the box
    -- Cursor texture is 11x11; scaled by box_data.scale
    local s = (box_data.scale or 1.0)
    local cursor_w = 11 * s
    local cursor_h = 11 * s
    local margin = 3 * s

    local x = (box_data.x + box_data.width) - cursor_w - margin
    local y_offset = 2 * s   -- try 2*s, 3*s, 4*s
    local y = (box_data.y + box_data.height) - cursor_h - margin + y_offset + bob


    Net.player_draw_sprite(player_id, self.cursor_sprite.sprite_id, {
        id = cursor_id,
        x = x,
        y = y,
        z = (box_data.z_order or 100) + 1,
        sx = s,
        sy = s
    })

    box_data.cursor_visible = true
end

function TextDisplay:updateTextBoxes(delta)
  for player_id, player_data in pairs(self.player_texts) do
    local to_remove = nil

    for box_id, box_data in pairs(player_data.active_text_boxes) do
      -- DEBUG: log state transitions (this is the “truth meter”)
      if _ng_dbg_enabled() then
        box_data._dbg_last_state = box_data._dbg_last_state or box_data.state
        if box_data.state ~= box_data._dbg_last_state then
          _ng_dbg(player_id, box_id,
            "STATE " .. tostring(box_data._dbg_last_state) .. " -> " .. tostring(box_data.state),
            "token=" .. tostring(box_data._dbg_token) ..
            " page=" .. tostring(box_data.current_page) ..
            " line=" .. tostring(box_data.current_line) ..
            " char=" .. tostring(box_data.current_char)
          )
          box_data._dbg_last_state = box_data.state
        end
      end

      if box_data.state == "opening" then
        local done = self:updateTextBoxOpening(player_id, box_id, box_data, delta, player_data)
        if done then
          box_data.state = "printing"
        end

      elseif box_data.state == "printing" then
        self:updateTextBoxPrinting(player_id, box_id, box_data, delta)

      elseif box_data.state == "waiting" then
        self:updateTextBoxWaiting(player_id, box_id, box_data, delta)

      elseif box_data.state == "closing" then
        local done = self:updateTextBoxClosing(player_id, box_id, box_data, delta, player_data)
        if done then
          to_remove = to_remove or {}
          table.insert(to_remove, box_id)
        end

      elseif box_data.state == "completed" then
        self:closeTextBox(player_id, box_id)
      end

      -- Cursor + nameplate can update every tick safely
      self:updateTextBoxCursor(player_id, box_id, box_data, delta)

      if self.nameplate then
        self.nameplate:update(player_id, player_data, box_data, delta)
      end
    end

    if to_remove then
      for _, box_id in ipairs(to_remove) do
        self:removeTextBox(player_id, box_id)
      end
    end
  end
end


function TextDisplay:updateTextBoxPrinting(player_id, box_id, box_data, delta)
  -- If currently pausing, count down and stop.
  box_data._last_delta = delta

  if box_data.pause_remaining and box_data.pause_remaining > 0 then
    -- enter pause: force mug to idle once
    if not box_data._in_pause then
      box_data._in_pause = true
      if box_data.mugshot and box_data.mugshot.enabled then
        -- temporarily treat as "not printing speech"
        local prev = box_data.state
        box_data.state = "waiting"
        self:drawTextBoxMugshot(player_id, box_id, box_data)
        box_data.state = prev
      end
    end

    box_data.pause_remaining = box_data.pause_remaining - delta
    if box_data.pause_remaining > 0 then
      return
    end

    -- pause ended
    box_data.pause_remaining = 0
    box_data._in_pause = false

    -- resume: restore talk pose once (if we’re still in printing)
    if box_data.mugshot and box_data.mugshot.enabled then
      self:drawTextBoxMugshot(player_id, box_id, box_data)
    end
  end

  -- Before printing the next character, see if a pause should trigger
  local printed = get_printed_char_count(box_data)
  if box_data.pause_marks and box_data.pause_marks[printed] and box_data.pause_marks[printed] > 0 then
    box_data.pause_remaining = box_data.pause_marks[printed]
    box_data.pause_marks[printed] = nil -- one-shot
    return
  end

  box_data.timer = box_data.timer + delta

  local current_page = box_data.pages[box_data.current_page]
  if not current_page then
    box_data.state = "completed"
    return
  end

  -- Print as many characters as our timer allows, but stop on pauses / page ends
  while box_data.timer >= box_data.char_delay do
    -- pause check again each char (so you can stack pauses tightly)
    printed = get_printed_char_count(box_data)
    if box_data.pause_marks and box_data.pause_marks[printed] and box_data.pause_marks[printed] > 0 then
      box_data.pause_remaining = box_data.pause_marks[printed]
      box_data.pause_marks[printed] = nil
      return
    end

    box_data.timer = box_data.timer - box_data.char_delay

    current_page = box_data.pages[box_data.current_page]
    if not current_page then
      box_data.state = "completed"
      return
    end

    local current_line_text = current_page[box_data.current_line]
    if not current_line_text then
      -- advance to next page
      box_data.current_page = box_data.current_page + 1
      if box_data.current_page > #box_data.pages then
        box_data.state = "completed"
      else
        box_data.current_line = 1
        box_data.current_char = 0
        self:clearTextBoxDisplay(player_id, box_id, box_data)
      end
      return
    end

    -- ============================================================
    -- SPACE-RUN FAST PRINT
    -- If the next character is a space, and there are 2+ spaces in a row,
    -- print the whole run immediately (using only ONE char_delay).
    -- Single spaces still print normally (keeps sentence pacing).
    -- ============================================================

    local next_pos = (box_data.current_char or 0) + 1

    -- If next_pos is past the end of the line, go to next line/page as usual
    if next_pos > #current_line_text then
      box_data.current_line = box_data.current_line + 1
      box_data.current_char = 0

      if box_data.current_line > #current_page then
        -- end of page => wait (confirm/auto logic lives in updateTextBoxWaiting)
        box_data.state = "waiting"
        box_data.wait_timer = 0

        -- IMPORTANT: mugshot must be redrawn here, otherwise it stays in last anim_state
        if box_data.mugshot and box_data.mugshot.enabled then
          self:drawTextBoxMugshot(player_id, box_id, box_data)
        end

        return
      end

    else
      local next_ch = current_line_text:sub(next_pos, next_pos)

      if next_ch == " " then
        -- count how many consecutive spaces from next_pos forward (same line only)
        local run_end = next_pos
        while run_end <= #current_line_text and current_line_text:sub(run_end, run_end) == " " do
          run_end = run_end + 1
        end
        local run_len = run_end - next_pos

        if run_len >= 2 then
          -- Print the whole run of spaces immediately.
          -- (We still respect pauses if a pause mark happens to land mid-run.)
          for j = next_pos, (next_pos + run_len - 1) do
            printed = get_printed_char_count(box_data)
            if box_data.pause_marks and box_data.pause_marks[printed] and box_data.pause_marks[printed] > 0 then
              box_data.pause_remaining = box_data.pause_marks[printed]
              box_data.pause_marks[printed] = nil
              return
            end

            box_data.current_char = j
            self:drawTextBoxCharacter(player_id, box_id, box_data, true)
          end

          -- Done: we consumed ONE char_delay total for multiple spaces.
          -- Next loop iteration prints the next non-space (if timer allows).
        else
          -- Single space: behave like normal typing cadence
          box_data.current_char = next_pos
          self:drawTextBoxCharacter(player_id, box_id, box_data, true)
        end
      else
        -- Normal character: print one
        box_data.current_char = next_pos
        self:drawTextBoxCharacter(player_id, box_id, box_data, true)
      end
    end
  end
end



function TextDisplay:updateTextBoxWaiting(player_id, box_id, box_data, delta)
  box_data.wait_timer = box_data.wait_timer + delta

  local mode = box_data.page_advance or "auto_advance"

  -- 1) wait_for_confirm: never auto-advance
  if mode == "wait_for_confirm" then
    return
  end

  -- 2) auto_advance or auto_advance_or_confirm:
  --    both auto-advance after N seconds.
  local seconds = box_data.auto_advance_seconds or 2.0
  if box_data.wait_timer >= seconds then
    box_data.current_page = box_data.current_page + 1
    if box_data.current_page > #box_data.pages then
      box_data.state = "completed"
    else
      box_data.current_line = 1
      box_data.current_char = 0
      box_data.state = "printing"
      box_data.wait_timer = 0

      if box_data.mugshot and box_data.mugshot.enabled then
        self:drawTextBoxMugshot(player_id, box_id, box_data)
      end

      self:clearTextBoxDisplay(player_id, box_id, box_data)
    end
  end
end

function TextDisplay:updateTextBoxOpening(player_id, box_id, box_data, delta, player_data)
  -- One-time "enter opening"
  if not box_data._opening_started then
    box_data._opening_started = true

    -- Only force an OPEN send if we *haven't already sent OPEN*.
    -- (Example: setTextBoxPosition may have drawn once right after create.)
    if box_data._panel_last_anim_state ~= "OPEN" then
      box_data._panel_last_anim_state = nil
    end

    -- Hide cursor immediately
    local cursor_id = box_id .. "_cursor"
    Net.player_erase_sprite(player_id, cursor_id)
    box_data.cursor_visible = false

    if _ng_dbg_enabled() then
      _ng_dbg(player_id, box_id, "OPEN enter",
        "open_seconds=" .. tostring(box_data.open_seconds) .. " token=" .. tostring(box_data._dbg_token))
    end

    -- Draw ONCE: this should be the ONLY place OPEN gets sent (unless it was already sent earlier)
    self:drawTextBoxBackdrop(player_id, box_id, box_data)
    self:drawTextBoxMugshot(player_id, box_id, box_data)
  end

  -- Clamp delta so hitches don't instantly finish open
  local dt = math.min(delta or 0, 1/30)

  box_data.open_timer = (box_data.open_timer or 0) + dt
  local secs = box_data.open_seconds or 0.20

    -- Fade mugshot in during OPEN
    if box_data.mugshot and box_data.mugshot.enabled then
      local p = math.min(1, (box_data.open_timer or 0) / secs)
      box_data._mug_opacity = math.floor(255 * p + 0.5)
      self:drawTextBoxMugshot(player_id, box_id, box_data)
    end


  if box_data.open_timer >= secs then
    if _ng_dbg_enabled() then
      _ng_dbg(player_id, box_id, "OPEN done", "open_timer=" .. string.format("%.3f", box_data.open_timer))
      box_data._mug_opacity = 255

    end

    -- Force OPEN_IDLE once right as opening ends (otherwise you can get stuck on OPEN's last frame)
    box_data._panel_last_anim_state = nil
    local prev = box_data.state
    box_data.state = "printing"
    self:drawTextBoxBackdrop(player_id, box_id, box_data) -- sends OPEN_IDLE once
    self:drawTextBoxMugshot(player_id, box_id, box_data)
    box_data.state = prev

    return true
  end

  return false
end

function TextDisplay:updateTextBoxClosing(player_id, box_id, box_data, delta, player_data)
  -- If someone closes during opening, stop opening bookkeeping
  box_data._opening_started = nil
  box_data.open_timer = nil

  -- One-time "enter closing"
  if not box_data._closing_started then
    box_data._closing_started = true
    box_data._mug_opacity = box_data._mug_opacity or 255

    -- Only force a CLOSE send if we *haven't already sent CLOSE*.
    if box_data._panel_last_anim_state ~= "CLOSE" then
      box_data._panel_last_anim_state = nil
    end

    -- Hide cursor
    local cursor_id = box_id .. "_cursor"
    Net.player_erase_sprite(player_id, cursor_id)
    box_data.cursor_visible = false

    if _ng_dbg_enabled() then
      _ng_dbg(player_id, box_id, "CLOSE enter",
        "close_seconds=" .. tostring(box_data.close_seconds) .. " token=" .. tostring(box_data._dbg_token))
    end

    -- Draw ONCE: apply CLOSE anim_state
self:drawTextBoxBackdrop(player_id, box_id, box_data)
self:drawTextBoxMugshot(player_id, box_id, box_data)




  end

  -- Clamp delta so hitches don't instantly finish close
  local dt = math.min(delta or 0, 1/30)

  box_data.close_timer = (box_data.close_timer or 0) + dt
  local secs = box_data.close_seconds or 0.25
  -- Fade mugshot out during CLOSE
if box_data.mugshot and box_data.mugshot.enabled and box_data.mug_id then
  local p = math.min(1, (box_data.close_timer or 0) / secs)
  box_data._mug_opacity = math.floor(255 * (1 - p) + 0.5)
  self:drawTextBoxMugshot(player_id, box_id, box_data)
end



  if box_data.close_timer >= secs then
    if _ng_dbg_enabled() then
      _ng_dbg(player_id, box_id, "CLOSE done", "close_timer=" .. string.format("%.3f", box_data.close_timer))
      -- Ensure mugshot is gone at end of close
if box_data.mug_id then
  Net.player_erase_sprite(player_id, box_data.mug_id)
  box_data.mug_id = nil
end
box_data._mug_opacity = nil

    end
    return true
  end

  return false
end



local function glyph_exists(font_system, font_name, glyph)
local base = (font_name and font_name:gsub("_BLACK$", "")) or font_name
local widths = font_system.char_widths[font_name] or font_system.char_widths[base] or font_system.char_widths.THICK
print("[glyph_exists] font="..tostring(font_name).." widths_from="..tostring((font_system.char_widths[font_name] and font_name) or (font_system.char_widths[font_name:gsub('_BLACK$','')] and font_name:gsub('_BLACK$','')) or 'THICK')) 
return widths and widths[glyph] ~= nil
end

local function choose_glyph(font_system, font_name, glyph)
  -- 1) exact match (this is what enables true lowercase)
  if glyph_exists(font_system, font_name, glyph) then
    return glyph
  end

  -- 2) fallback: try uppercase if lowercase isn't present
  if glyph:match("%a") then
    local up = glyph:upper()
    if glyph_exists(font_system, font_name, up) then
      return up
    end
  end

  -- 3) last resort: '?'
  if glyph_exists(font_system, font_name, "?") then
    return "?"
  end

  return nil
end

function TextDisplay:_playTypeSfx(player_id, box_data)
  local path = box_data.type_sfx_path or "/server/assets/net-games/sfx/text.ogg"

  local cps = 1 / math.max(box_data.char_delay or (1/30), 0.001)

  box_data.type_sfx_count = (box_data.type_sfx_count or 0) + 1

  local step = 1
  if cps >= 60 then step = 3
  elseif cps >= 40 then step = 2 end

  if (box_data.type_sfx_count % step) ~= 0 then return end

  local min_dt = (box_data.type_sfx_min_dt or 0.16)
  local now = os.clock()
  box_data._last_sfx_at = box_data._last_sfx_at or 0

  if (now - box_data._last_sfx_at) < min_dt then return end
  box_data._last_sfx_at = now

  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, path) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(player_id, path) end)
  elseif Net.play_audio then
    pcall(function() Net.play_audio(player_id, path) end)
  end
end


function TextDisplay:drawTextBoxCharacter(player_id, box_id, box_data, play_sfx)
  if play_sfx == nil then play_sfx = true end

  local current_page = box_data.pages[box_data.current_page]
  local current_line_text = current_page[box_data.current_line]
  local raw = current_line_text:sub(box_data.current_char, box_data.current_char)

  -- This returns nil for spaces or unsupported chars
  local state = anim_state_for_char(box_data.font, raw)
  if not state then return end

  -- Type blip SFX for visible glyphs (not spaces)
  if play_sfx then
    self:_playTypeSfx(player_id, box_data)
  end

local lh = box_data._line_height_px or (self.text_box_settings.line_height * box_data.scale)
local line_y = box_data.inner_y + ((box_data.current_line - 1) * lh)

  local char_widths = self.font_system.char_widths[box_data.font] or self.font_system.char_widths.THICK
  local default_char_width = char_widths["A"] or char_widths["0"] or 6
  local char_width = default_char_width * box_data.scale

  local base_spacing = self.text_box_settings.char_spacing or 1
  local scaled_spacing = base_spacing * box_data.scale
  local line_offset = 0
  if box_data.line_x_offsets then
    line_offset = box_data.line_x_offsets[box_data.current_line] or 0
  end

  local current_x = (box_data.inner_x + line_offset) + (box_data.current_char - 1) * (char_width + scaled_spacing)

  local char_obj_id = box_id .. "_line_" .. box_data.current_line .. "_char_" .. box_data.current_char

  Net.player_draw_sprite(player_id, box_data.font, {
    id = char_obj_id,
    x = current_x,
    y = line_y,
    z = box_data.z_order,
    sx = box_data.scale,
    sy = box_data.scale,
    anim_state = state
  })

  box_data.display_lines[box_data.current_line] = box_data.display_lines[box_data.current_line] or {}
  box_data.display_lines[box_data.current_line][box_data.current_char] = char_obj_id
  

end




function TextDisplay:clearTextBoxDisplay(player_id, box_id, box_data)
    for _, line_chars in pairs(box_data.display_lines) do
        for _, obj_id in pairs(line_chars) do
            Net.player_erase_sprite(player_id, obj_id)
        end
    end
    box_data.display_lines = {}
end

function TextDisplay:removeTextBox(player_id, box_id)
  local player_data = self.player_texts[player_id]
  if not player_data then return end

  local box_data = player_data.active_text_boxes[box_id]
  if not box_data then return end

  -- SAFE debug lib (may be stripped / nil in this runtime)
  local dbg = _G.debug

  -- WHO is deleting it? (guarded)
  local caller = "unknown"
  if dbg and dbg.getinfo then
    local ok, info = pcall(dbg.getinfo, 2, "Sl")
    if ok and info then
      caller = tostring(info.short_src) .. ":" .. tostring(info.currentline)
    end
  end

  _ng_dbg(player_id, box_id, "REMOVE (hard delete)",
    "caller=" .. tostring(caller) ..
    " token=" .. tostring(box_data._dbg_token) ..
    " state=" .. tostring(box_data.state) ..
    " lived=" .. string.format("%.3f", (_ng_now() - (box_data._dbg_created_at or _ng_now())))
  )

  if _ng_dbg_trace() and dbg and dbg.traceback then
    local ok, tb = pcall(dbg.traceback, "", 2)
    if ok and tb then
      print(tb)
    end
  end

  -- Remove nameplate (if any)
  if self.nameplate then
    self.nameplate:erase(player_id, player_data, box_data)
  end

  local cursor_id = box_id .. "_cursor"
  Net.player_erase_sprite(player_id, cursor_id)

  if box_data.backdrop_id then
    Net.player_erase_sprite(player_id, box_data.backdrop_id)
  end

  if box_data.mug_id then
    Net.player_erase_sprite(player_id, box_data.mug_id)
    box_data.mug_id = nil
  end

  if box_data.frame_id then
    Net.player_erase_sprite(player_id, box_data.frame_id)
    box_data.frame_id = nil
  end

  self:clearTextBoxDisplay(player_id, box_id, box_data)
  player_data.active_text_boxes[box_id] = nil
end



-- Soft-close: transitions the box into a "closing" lifecycle state.
-- The actual sprite erasing should happen later (after the close animation finishes).

function TextDisplay:closeTextBox(player_id, box_id, opts)
  local player_data = self.player_texts[player_id]
  if not player_data then return end

  local box_data = player_data.active_text_boxes[box_id]
  if not box_data then return end

  opts = opts or {}

  if box_data.state == "closing" then
    _ng_dbg(player_id, box_id, "CLOSE ignored (already closing)",
      "caller=" .. tostring(opts.caller) .. " reason=" .. tostring(opts.reason)
    )
    return
  end

  -- Enter closing state
  box_data.state = "closing"
  box_data.close_timer = 0

  box_data.close_seconds =
      opts.close_seconds
      or box_data.close_seconds
      or (box_data.backdrop and box_data.backdrop.close_seconds)
      or 0.25

  -- Hide cursor immediately
  local cursor_id = box_id .. "_cursor"
  Net.player_erase_sprite(player_id, cursor_id)
  box_data.cursor_visible = false

    -- Start nameplate close animation (reverse-unfold)
  if self.nameplate then
    self.nameplate:begin_close(player_id, player_data, box_data)
  end

  if opts.clear_text ~= false then
    self:clearTextBoxDisplay(player_id, box_id, box_data)
  end

  box_data.timer = 0
end



function TextDisplay:advanceTextBox(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local box_data = player_data.active_text_boxes[box_id]
    if not box_data then return end

    -- If confirm is disabled during typing, ignore confirm while printing
    if box_data.state == "printing" and box_data.confirm_during_typing == false then
      return
    end

    if box_data.state == "waiting" then
        box_data.current_page = box_data.current_page + 1
        if box_data.current_page > #box_data.pages then
            box_data.state = "completed"
        else
            box_data.current_line = 1
            box_data.current_char = 0
            box_data.state = "printing"

            if box_data.mugshot and box_data.mugshot.enabled then
              self:drawTextBoxMugshot(player_id, box_id, box_data)
            end

            self:clearTextBoxDisplay(player_id, box_id, box_data)
        end

    elseif box_data.state == "printing" then
        local current_page = box_data.pages[box_data.current_page]
        if not current_page then return end

        -- If pauses exist, fast-forward ONLY up to the NEXT pause mark (do not bypass it).
        local printed = get_printed_char_count(box_data)
        local next_pause = nil

        if box_data.pause_marks then
          for k, _ in pairs(box_data.pause_marks) do
            if k >= printed and (next_pause == nil or k < next_pause) then
              next_pause = k
            end
          end

          -- If we're already exactly at a pause boundary, don't move.
          -- The pause will trigger naturally in updateTextBoxPrinting.
          if next_pause ~= nil and next_pause <= printed then
            return
          end
        end

        -- Helper: print characters forward, stopping at `stop_at_printed` if provided.
        local function print_forward_until(stop_at_printed)
          for line = box_data.current_line, #current_page do
            local line_text = current_page[line]
            local start_char = (line == box_data.current_line) and (box_data.current_char + 1) or 1

            for char_pos = start_char, #line_text do
              box_data.current_line = line
              box_data.current_char = char_pos
              self:drawTextBoxCharacter(player_id, box_id, box_data, false)

              if stop_at_printed ~= nil then
                local now_printed = get_printed_char_count(box_data)
                if now_printed >= stop_at_printed then
                  return false -- stopped early (e.g., at a pause boundary)
                end
              end
            end
          end

          return true -- reached end of page
        end

        -- If there's a pause ahead: stop right at that boundary (stay in "printing").
        if next_pause ~= nil then
          local finished_page = print_forward_until(next_pause)
          -- If we somehow finished the page (pause was beyond it), fall through to waiting.
          if not finished_page then
            return
          end
        else
          -- No pause ahead: original behavior = finish the whole page instantly.
          print_forward_until(nil)
        end

        -- If we reached here, we're at the end of the page => waiting for confirm to advance.
        box_data.state = "waiting"
        box_data.wait_timer = 0

        -- Redraw mugshot once to switch from TALK -> IDLE (prevents sticking)
        if box_data.mugshot and box_data.mugshot.enabled then
          self:drawTextBoxMugshot(player_id, box_id, box_data)
        end
    end
end


function TextDisplay:setTextBoxPosition(player_id, box_id, x, y)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local box_data = player_data.active_text_boxes[box_id]
    if not box_data then return end

    box_data.x = x
    box_data.y = y

    if box_data.backdrop then
        box_data.backdrop.x = x
        box_data.backdrop.y = y
    end

    box_data.inner_x = x + box_data.padding_x
    box_data.inner_y = y + box_data.padding_y

    -- CRITICAL:
    -- setTextBoxPosition is often called immediately after createTextBox.
    -- If we redraw the panel while we're still "opening" (before OPEN enter),
    -- we can send OPEN twice (or restart the anim), which looks like flicker/double-open.
    if box_data.state == "opening" and not box_data._opening_started then
        if _ng_dbg_enabled() then
            _ng_dbg(player_id, box_id, "setTextBoxPosition (skip draw; pre-open)",
              "state=opening opening_started=false x=" .. tostring(x) .. " y=" .. tostring(y))
        end
        return
    end

    -- Same idea for closing: don't force a redraw before CLOSE enter handles it.
    if box_data.state == "closing" and not box_data._closing_started then
        if _ng_dbg_enabled() then
            _ng_dbg(player_id, box_id, "setTextBoxPosition (skip draw; pre-close)",
              "state=closing closing_started=false x=" .. tostring(x) .. " y=" .. tostring(y))
        end
        return
    end

    self:drawTextBoxBackdrop(player_id, box_id, box_data)
    self:clearTextBoxDisplay(player_id, box_id, box_data)

    if box_data.state == "printing" or box_data.state == "waiting" then
        local current_page = box_data.pages[box_data.current_page]
        if current_page then
            for line = 1, box_data.current_line do
                local line_text = current_page[line]
                if line_text then
                    local last_char = (line == box_data.current_line) and box_data.current_char or #line_text
                    for char_pos = 1, last_char do
                        box_data.current_line = line
                        box_data.current_char = char_pos
                        self:drawTextBoxCharacter(player_id, box_id, box_data, false)
                    end
                end
            end
        end

        -- restore cursor location after redraw
        self:updateTextBoxCursor(player_id, box_id, box_data, 0)
    end
end


function TextDisplay:isTextBoxCompleted(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local box_data = player_data.active_text_boxes[box_id]
        return box_data and box_data.state == "completed"
    end
    return true
end

function TextDisplay:getTextBoxData(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return nil end

    local box_data = player_data.active_text_boxes[box_id]
    return box_data
end


function TextDisplay:getTextBoxState(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return "completed" end

    local box_data = player_data.active_text_boxes[box_id]
    if not box_data then return "completed" end

    return box_data.state
end

--=====================================================
-- Static text
--=====================================================

function TextDisplay:drawText(player_id, text_id, text, x, y, z_order, font_name, scale)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    z_order = z_order or 100

    local player_data = self.player_texts[player_id]
    if not player_data then return nil end

    local actual_id = text_id or ("text_" .. player_data.next_obj_id)
    player_data.next_obj_id = player_data.next_obj_id + 1

    local text_data = {
        type = "static",
        text = text,
        x = x,
        y = y,
        font = font_name,
        scale = scale,
        z_order = z_order,
        display_id = nil,
        character_objects = {}
    }

    text_data.display_id = self.font_system:drawText(player_id, actual_id, text, x, y, z_order, font_name, scale)
    player_data.active_texts[actual_id] = text_data
    return actual_id
end

--=====================================================
-- Marquee
--=====================================================

function TextDisplay:drawMarqueeText(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    z_order = z_order or 100
    speed = speed or "medium"

    local player_data = self.player_texts[player_id]
    if not player_data then return nil end

    local text_width = self.font_system:getTextWidth(text, font_name, scale)
    local speed_value = self.marquee_speeds[speed] or self.marquee_speeds.medium

    local bounds_left, bounds_right, bounds_width
    local start_x
    local actual_y = y

    if backdrop then
        local padding_x = backdrop.padding_x or 0
        local padding_y = backdrop.padding_y or 0

        local backdrop_scale = backdrop.scale or 2.0

        local scaled_backdrop_x = backdrop.x * backdrop_scale
        local scaled_backdrop_y = backdrop.y * backdrop_scale
        local scaled_backdrop_width = backdrop.width * backdrop_scale
        local scaled_backdrop_height = backdrop.height * backdrop_scale
        local scaled_padding_x = padding_x * backdrop_scale
        local scaled_padding_y = padding_y * backdrop_scale

        bounds_left = scaled_backdrop_x + scaled_padding_x
        bounds_right = scaled_backdrop_x + scaled_backdrop_width - scaled_padding_x
        bounds_width = bounds_right - bounds_left

        start_x = bounds_right

        local text_height = 8 * scale
        local centered_y = scaled_backdrop_y + ((scaled_backdrop_height - text_height) / 2)
        actual_y = centered_y
    else
        bounds_left = 0
        bounds_right = self.screen_width
        bounds_width = self.screen_width
        start_x = self.screen_width
        actual_y = y
    end

    local marquee_data = {
        type = "marquee",
        text = text,
        y = actual_y,
        font = font_name,
        scale = scale,
        z_order = z_order,
        speed = speed_value,
        current_x = start_x,
        text_width = text_width,
        backdrop = backdrop or nil,
        bounds_left = bounds_left,
        bounds_right = bounds_right,
        bounds_width = bounds_width,
        character_objects = {},
        individual_chars = {},
        original_y = y,
        backdrop_y = backdrop and (backdrop.y * (backdrop.scale or 2.0)) or nil,

        -- finite/infinite loop controls
        loops_remaining = _normalize_loops(backdrop and backdrop.loops),
        on_finish       = backdrop and backdrop.on_finish,
        keep_backdrop   = backdrop and backdrop.keep_backdrop or false,

        _backdrop_allocated = false,
        backdrop_id = nil
    }

    self:setupMarqueeCharacters(marquee_data)

    if backdrop then
        self:drawBackdrop(player_id, marquee_id, marquee_data, backdrop)
    end

    self:drawMarqueeCharacters(player_id, marquee_id, marquee_data)

    player_data.active_texts[marquee_id] = marquee_data
    return marquee_id
end

function TextDisplay:setMarqueePosition(player_id, marquee_id, x, y)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local marquee_data = player_data.active_texts[marquee_id]
    if not marquee_data or marquee_data.type ~= "marquee" then return end

    marquee_data.original_y = y

    if marquee_data.backdrop then
        marquee_data.backdrop.x = x
        marquee_data.backdrop.y = y

        local text_height = 8 * marquee_data.scale
        local centered_y = y + ((marquee_data.backdrop.height - text_height) / 2)
        marquee_data.y = centered_y

        local padding_x = marquee_data.backdrop.padding_x or 4
        marquee_data.bounds_left = x + padding_x
        marquee_data.bounds_right = x + marquee_data.backdrop.width - padding_x
        marquee_data.bounds_width = marquee_data.bounds_right - marquee_data.bounds_left

        if marquee_data.backdrop_id then
            Net.player_erase_sprite(player_id, marquee_data.backdrop_id)
            marquee_data.backdrop_id = nil
        end
        self:drawBackdrop(player_id, marquee_id, marquee_data, marquee_data.backdrop)
    else
        marquee_data.y = y
        marquee_data.bounds_left = 0
        marquee_data.bounds_right = self.screen_width
        marquee_data.bounds_width = self.screen_width
    end

    marquee_data.current_x = marquee_data.bounds_right
    self:drawMarqueeCharacters(player_id, marquee_id, marquee_data)
end

function TextDisplay:setupMarqueeCharacters(marquee_data)
  local font_name = marquee_data.font
  local char_widths = self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK
  local scale = marquee_data.scale

  local base_spacing = 1
  local scaled_spacing = base_spacing * scale

  marquee_data.individual_chars = {}

  local total_text_width = 0
  local n = #marquee_data.text

  for i = 1, n do
    local raw = marquee_data.text:sub(i, i)

    -- returns nil for spaces (and anything you decide to skip)
    local state = anim_state_for_char(font_name, raw)
    local is_space = (state == nil)

    -- monotype width: use uppercase width for letters, else raw, else 'A'
    local width_key = raw
    if width_key and width_key:match("%a") then
      width_key = width_key:upper()
    end
    local char_width = (char_widths[width_key] or char_widths["A"] or 6) * scale

    table.insert(marquee_data.individual_chars, {
      raw = raw,
      width = char_width,
      relative_x = total_text_width,
      obj_id = nil,
      anim_state = state,   -- <- key change
      is_space = is_space   -- <- key change
    })

    total_text_width = total_text_width + char_width
    if i < n then
      total_text_width = total_text_width + scaled_spacing
    end
  end

  marquee_data.total_text_width = total_text_width
end


function TextDisplay:drawMarqueeCharacters(player_id, marquee_id, marquee_data)
    for i, char_data in ipairs(marquee_data.individual_chars) do
        local char_x = marquee_data.current_x + char_data.relative_x

        local is_visible = (char_x + char_data.width >= marquee_data.bounds_left and char_x <= marquee_data.bounds_right)

        if is_visible and char_data.anim_state then
            if char_data.obj_id then
                Net.player_draw_sprite(
                    player_id,
                    marquee_data.font,
                    {
                        id = char_data.obj_id,
                        x = char_x,
                        y = marquee_data.y,
                        z = marquee_data.z_order,
                        sx = marquee_data.scale,
                        sy = marquee_data.scale,
                        anim_state = char_data.anim_state
                    }
                )
            else
                local char_obj_id = marquee_id .. "_char_" .. i
                Net.player_draw_sprite(
                    player_id,
                    marquee_data.font,
                    {
                        id = char_obj_id,
                        x = char_x,
                        y = marquee_data.y,
                        z = marquee_data.z_order,
                        sx = marquee_data.scale,
                        sy = marquee_data.scale,
                        anim_state = char_data.anim_state
                    }
                )
                char_data.obj_id = char_obj_id
            end
        else
            if char_data.obj_id then
                Net.player_erase_sprite(player_id, char_data.obj_id)
                char_data.obj_id = nil
            end
        end
    end
end

-- Draw backdrop (lazy + safe no-op)
function TextDisplay:drawBackdrop(player_id, text_id, text_data, backdrop)
    if not self.backdrop_sprite or not self.backdrop_sprite.texture_path then
        return
    end

    local padding_x = backdrop.padding_x or 0
    local padding_y = backdrop.padding_y or 0

    local backdrop_scale = backdrop.scale or 2.0
    local backdrop_width = backdrop.width * backdrop_scale
    local backdrop_height = backdrop.height * backdrop_scale
    local backdrop_x = backdrop.x * backdrop_scale
    local backdrop_y = backdrop.y * backdrop_scale

    if not text_data._backdrop_allocated then
        Net.provide_asset_for_player(player_id, self.backdrop_sprite.texture_path)
        Net.player_alloc_sprite(player_id, self.backdrop_sprite.sprite_id, {
            texture_path = self.backdrop_sprite.texture_path
        })
        text_data._backdrop_allocated = true
    end

    local backdrop_id = text_id .. "_backdrop"

    Net.player_draw_sprite(
        player_id,
        self.backdrop_sprite.sprite_id,
        {
            id = backdrop_id,
            x = backdrop_x,
            y = backdrop_y,
            z = text_data.z_order - 1,
            sx = backdrop_width,
            sy = backdrop_height
        }
    )

    text_data.backdrop_id = backdrop_id
    text_data.backdrop_width = backdrop_width
    text_data.backdrop_height = backdrop_height
    text_data.backdrop_padding_x = padding_x * backdrop_scale
    text_data.backdrop_padding_y = padding_y * backdrop_scale
end

function TextDisplay:updateMarquees(delta)
    for player_id, player_data in pairs(self.player_texts) do
        for text_id, text_data in pairs(player_data.active_texts) do
            if text_data.type == "marquee" then
                self:updateMarquee(player_id, text_id, text_data, delta)
            end
        end
    end
end

function TextDisplay:updateMarquee(player_id, text_id, text_data, delta)
    local movement = text_data.speed * delta
    text_data.current_x = text_data.current_x - movement

    if text_data.current_x + text_data.total_text_width < text_data.bounds_left then
        text_data.current_x = text_data.bounds_right

        if text_data.loops_remaining == nil then
            text_data.current_x = text_data.bounds_right
        else
            if text_data.loops_remaining <= 1 then
                for _, c in ipairs(text_data.individual_chars or {}) do
                    if c.obj_id then
                        Net.player_erase_sprite(player_id, c.obj_id)
                    end
                end

                if not text_data.keep_backdrop and text_data.backdrop_id then
                    Net.player_erase_sprite(player_id, text_data.backdrop_id)
                end

                local pd = self.player_texts[player_id]
                if pd then pd.active_texts[text_id] = nil end

                if type(text_data.on_finish) == "function" then
                    pcall(text_data.on_finish, player_id, text_id)
                end
                return
            else
                text_data.loops_remaining = text_data.loops_remaining - 1
                text_data.current_x = text_data.bounds_right
            end
        end
    end

    self:drawMarqueeCharacters(player_id, text_id, text_data)
end

function TextDisplay:updateText(player_id, text_id, new_text)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if not text_data then return end

    if text_data.type == "marquee" then
        for _, char_data in ipairs(text_data.individual_chars or {}) do
            if char_data.obj_id then
                Net.player_erase_sprite(player_id, char_data.obj_id)
            end
        end
    else
        if text_data.display_id then
            self.font_system:eraseTextDisplay(player_id, text_data.display_id)
        end
    end

    if text_data.backdrop_id then
        Net.player_erase_sprite(player_id, text_data.backdrop_id)
        text_data.backdrop_id = nil
    end

    text_data.text = new_text

    if text_data.type == "marquee" then
        text_data.text_width = self.font_system:getTextWidth(new_text, text_data.font, text_data.scale)

        if text_data.backdrop then
            local padding_x = text_data.backdrop.padding_x or 0
            text_data.bounds_left = text_data.backdrop.x + padding_x
            text_data.bounds_right = text_data.backdrop.x + text_data.backdrop.width - padding_x
            text_data.bounds_width = text_data.bounds_right - text_data.bounds_left
        end

        self:setupMarqueeCharacters(text_data)
    end

    if text_data.backdrop then
        self:drawBackdrop(player_id, text_id, text_data, text_data.backdrop)
    end

    if text_data.type == "marquee" then
        self:drawMarqueeCharacters(player_id, text_id, text_data)
    else
        text_data.display_id = self.font_system:drawText(
            player_id,
            text_id,
            new_text,
            text_data.x,
            text_data.y,
            text_data.z_order,
            text_data.font,
            text_data.scale
        )
    end
end

function TextDisplay:setMarqueeSpeed(player_id, text_id, speed)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if text_data and text_data.type == "marquee" then
        text_data.speed = self.marquee_speeds[speed] or self.marquee_speeds.medium
    end
end

function TextDisplay:setTextPosition(player_id, text_id, x, y)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if text_data and text_data.type == "static" then
        if text_data.display_id then
            self.font_system:eraseTextDisplay(player_id, text_data.display_id)
        end

        if text_data.backdrop_id then
            Net.player_erase_sprite(player_id, text_data.backdrop_id)
            text_data.backdrop_id = nil
        end

        text_data.x = x
        text_data.y = y

        if text_data.backdrop then
            self:drawBackdrop(player_id, text_id, text_data, text_data.backdrop)
        end

        text_data.display_id = self.font_system:drawText(
            player_id,
            nil,
            text_data.text,
            x,
            y,
            text_data.z_order,
            text_data.font,
            text_data.scale
        )
    end
end

function TextDisplay:addBackdrop(player_id, text_id, backdrop_config)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if not text_data then return end

    text_data.backdrop = backdrop_config

    if text_data.backdrop_id then
        Net.player_erase_sprite(player_id, text_data.backdrop_id)
        text_data.backdrop_id = nil
    end

    self:drawBackdrop(player_id, text_id, text_data, backdrop_config)

    if text_data.type == "marquee" then
        local padding_x = backdrop_config.padding_x or 0
        text_data.bounds_left = backdrop_config.x + padding_x
        text_data.bounds_right = backdrop_config.x + backdrop_config.width - padding_x
        text_data.bounds_width = text_data.bounds_right - text_data.bounds_left
        self:setupMarqueeCharacters(text_data)
    end
end

function TextDisplay:removeBackdrop(player_id, text_id)
    local player_data = self.player_texts[player_id]
    if not player_data then return end

    local text_data = player_data.active_texts[text_id]
    if text_data and text_data.backdrop_id then
        Net.player_erase_sprite(player_id, text_data.backdrop_id)
        text_data.backdrop = nil
        text_data.backdrop_id = nil

        if text_data.type == "marquee" then
            text_data.bounds_left = 0
            text_data.bounds_right = self.screen_width
            text_data.bounds_width = self.screen_width
            self:setupMarqueeCharacters(text_data)
        end
    end
end

-- Utility functions
function TextDisplay:getTextWidth(text, font_name, scale)
    return self.font_system:getTextWidth(text, font_name, scale)
end

function TextDisplay:getScreenDimensions()
    return self.screen_width, self.screen_height
end

-- Initialize the text display system
local textDisplaySystem = setmetatable({}, TextDisplay)
textDisplaySystem:init()

return textDisplaySystem
