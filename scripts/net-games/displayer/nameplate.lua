-- scripts/net-games/displayer/nameplate.lua
-- BN-style nameplate that unfolds from the center and sizes to the text.
-- Draws as 3-slice: left + N*middle + right, using TINY_BLACK for the label.

local Nameplate = {}
Nameplate.__index = Nameplate

local function ceil_div(a, b)
  return math.floor((a + b - 1) / b)
end

-- =====================================================
-- DEBUG (mirrors text-display.lua flags)
-- Turn on with: _G.NG_TEXTBOX_DEBUG = true
-- Optional trace: _G.NG_TEXTBOX_DEBUG_TRACE = true
-- =====================================================
local function _ng_dbg_enabled()
  return _G and _G.NG_TEXTBOX_DEBUG == true
end

local function _ng_dbg_trace()
  return _G and _G.NG_TEXTBOX_DEBUG_TRACE == true
end

local function _ng_now()
  return os.clock()
end

local function _np_dbg(player_id, box_id, msg, extra)
  if not _ng_dbg_enabled() then return end
  local t = string.format("%.3f", _ng_now())
  local prefix = "[NPDBG t=" .. t .. " p=" .. tostring(player_id) .. " box=" .. tostring(box_id) .. "] "
  print(prefix .. tostring(msg))
  if extra then
    print(prefix .. tostring(extra))
  end
  if _ng_dbg_trace() then
    print(prefix .. debug.traceback("", 2))
  end
end

-- Compatibility stub: older code calls this name
local function _np_dbg_enabled()
  return _G and _G.NG_TEXTBOX_DEBUG == true
end



function Nameplate:new(font_system)
  local o = setmetatable({}, self)
  o.font_system = font_system

  -- textures (base)
  o.tex_left  = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left.png"
  o.tex_mid   = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle.png"
  o.tex_right = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right.png"

  -- textures (frame-gray overlay for dye)
  o.tex_left_frame  = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left_frame_gray.png"
  o.tex_mid_frame   = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle_frame_gray.png"
  o.tex_right_frame = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right_frame_gray.png"

  -- slice sizes (px at scale=1)
  o.w_left  = 5
  o.w_mid   = 3
  o.w_right = 5
  o.h_plate = 13

  -- allocated sprite ids (texture holders)
  -- IMPORTANT: use STRING ids to avoid collisions with other systems
  -- base
  o.SID_LEFT  = "np_base_left"
  o.SID_RIGHT = "np_base_right"
  o.SID_MID0  = "np_base_mid_"   -- suffix with i

  -- frame-gray overlay (tinted)
  o.SID_LEFT_F  = "np_frame_left"
  o.SID_RIGHT_F = "np_frame_right"
  o.SID_MID0_F  = "np_frame_mid_" -- suffix with i

  o.MAX_MIDS  = 60


  return o
end

function Nameplate:_alloc_once(player_id, player_data)
  player_data._nameplate_alloc = player_data._nameplate_alloc or false
  if player_data._nameplate_alloc then
    if _np_dbg_enabled() then
      _np_dbg(player_id, "?", "ALLOC_SKIP", "already allocated for this player")
    end
    return
  end
  player_data._nameplate_alloc = true

  if _np_dbg_enabled() then
    _np_dbg(player_id, "?", "ALLOC_DO", "allocating base + frame-gray overlay")
    _np_dbg(player_id, "?", "ALLOC_TEX",
      "L=" .. tostring(self.tex_left) ..
      " M=" .. tostring(self.tex_mid) ..
      " R=" .. tostring(self.tex_right) ..
      " | LF=" .. tostring(self.tex_left_frame) ..
      " MF=" .. tostring(self.tex_mid_frame) ..
      " RF=" .. tostring(self.tex_right_frame)
    )
  end

  -- base assets
  Net.provide_asset_for_player(player_id, self.tex_left)
  Net.provide_asset_for_player(player_id, self.tex_mid)
  Net.provide_asset_for_player(player_id, self.tex_right)

  -- overlay assets
  Net.provide_asset_for_player(player_id, self.tex_left_frame)
  Net.provide_asset_for_player(player_id, self.tex_mid_frame)
  Net.provide_asset_for_player(player_id, self.tex_right_frame)

  -- base sprites (texture holders)
  Net.player_alloc_sprite(player_id, self.SID_LEFT,  { texture_path = self.tex_left })
  Net.player_alloc_sprite(player_id, self.SID_RIGHT, { texture_path = self.tex_right })
  for i = 0, self.MAX_MIDS - 1 do
    Net.player_alloc_sprite(player_id, self.SID_MID0 .. i, { texture_path = self.tex_mid })
  end

  -- overlay sprites (frame-gray texture holders)
  Net.player_alloc_sprite(player_id, self.SID_LEFT_F,  { texture_path = self.tex_left_frame })
  Net.player_alloc_sprite(player_id, self.SID_RIGHT_F, { texture_path = self.tex_right_frame })
  for i = 0, self.MAX_MIDS - 1 do
    Net.player_alloc_sprite(player_id, self.SID_MID0_F .. i, { texture_path = self.tex_mid_frame })
  end

end


function Nameplate:erase(player_id, player_data, box_data)
  local np = box_data.nameplate
  if not np then return end

  -- erase base pieces by DRAW ids (NOT sprite ids)
  Net.player_erase_sprite(player_id, np.idp .. "_L")
  Net.player_erase_sprite(player_id, np.idp .. "_R")
  for i = 0, self.MAX_MIDS - 1 do
    Net.player_erase_sprite(player_id, np.idp .. "_M" .. i)
  end

  -- erase overlay (frame) pieces by DRAW ids
  Net.player_erase_sprite(player_id, np.idp .. "_FL")
  Net.player_erase_sprite(player_id, np.idp .. "_FR")
  for i = 0, self.MAX_MIDS - 1 do
    Net.player_erase_sprite(player_id, np.idp .. "_FM" .. i)
  end

  -- erase the name text
  if self.font_system and np.text_display_id then
    self.font_system:eraseTextDisplay(player_id, np.text_display_id)
  end

  box_data.nameplate = nil
end

function Nameplate:attach(player_id, player_data, box_id, box_data, cfg)
  if not cfg then return end

  -- cfg can be "NAME" or { text="NAME", ... }
  local text = cfg
  if type(cfg) == "table" then text = cfg.text end
  if type(text) ~= "string" or text == "" then return end

  self:_alloc_once(player_id, player_data)

  -- wipe any existing plate on this box before overwriting
  if box_data.nameplate then
    self:erase(player_id, player_data, box_data)
  end

  local scale = box_data.scale or 2.0
  local z     = (box_data.z_order or 100) + 3

  -- Anchor to the ACTUAL rendered textbox panel position (includes render offsets)
  local bx = box_data.x or 0
  local by = box_data.y or 0
  if box_data.backdrop then
    bx = bx + (tonumber(box_data.backdrop.render_offset_x) or 0)
    by = by + (tonumber(box_data.backdrop.render_offset_y) or 0)
  end

  -- Text metrics
  local font_name  = "TINY_BLACK"
  local text_scale = (type(cfg) == "table" and cfg.text_scale) or scale
  local pad_px     = (type(cfg) == "table" and cfg.pad_px) or (4 * scale)

  local text_w = self.font_system:getTextWidth(text, font_name, text_scale)
  local inner_needed = math.max(1, math.floor(text_w + pad_px * 2))

  local mid_w = self.w_mid * scale
  local mids_target = math.min(self.MAX_MIDS, math.max(1, ceil_div(inner_needed, mid_w)))

  local total_w = (self.w_left + self.w_right) * scale + (mids_target * mid_w)

  -- Placement
  local gap_x = (type(cfg) == "table" and cfg.gap_x) or (6 * scale)
  local gap_y = (type(cfg) == "table" and cfg.gap_y) or (4 * scale)

  local anchor = (type(cfg) == "table" and cfg.anchor) or "above_left"
  local align  = (type(cfg) == "table" and cfg.align)  or "left"

  local bw = box_data.width or 0

  local x, y
  if anchor == "above" then
    -- Above the textbox panel
    if align == "center" then
      x = bx + (bw - total_w) / 2
    elseif align == "right" then
      x = bx + bw - total_w - gap_x
    else
      -- left
      x = bx + gap_x
    end
    y = by - (self.h_plate * scale) - gap_y
  else
    -- legacy: above-left OUTSIDE the box
    x = bx - total_w - gap_x
    y = by - (self.h_plate * scale) - gap_y
  end

  -- Optional absolute override
  if type(cfg) == "table" then
    if cfg.x ~= nil then x = cfg.x end
    if cfg.y ~= nil then y = cfg.y end
  end

  local center_x = x + (total_w / 2)
  local idp = tostring(box_id) .. "_np"

  if type(cfg) == "table" and cfg.debug then
    _np_dbg(player_id, box_id, "ATTACH",
      "idp=" .. tostring(idp) ..
      " text=" .. tostring(text) ..
      " mids_target=" .. tostring(mids_target) ..
      " scale=" .. tostring(scale) ..
      " z=" .. tostring(z)
    )
  end


  -- Optional frame tint (overlay). Mirrors textbox dye behavior: gray overlay tinted on top.
  local frame_tint = nil
  if type(cfg) == "table" and type(cfg.frame) == "table" then
    local f = cfg.frame
    frame_tint = {
      r = tonumber(f.r) or 255,
      g = tonumber(f.g) or 255,
      b = tonumber(f.b) or 255,
      a = tonumber(f.a) or 255,
      color_mode = tonumber(f.color_mode) or 2,
    }
  end

  box_data.nameplate = {
    debug = (type(cfg) == "table" and cfg.debug) or false,
    idp = idp,

    text = text,
    font = font_name,
    text_scale = text_scale,
    pad_px = pad_px,

    x = x,
    y = y,
    base_y = y,
    z = z,

    -- overlay tint
    frame = frame_tint,

    -- bob animation
    bob_t = 0,
    bob_amp = (type(cfg) == "table" and cfg.bob_amp) or (3 * scale),
    bob_speed = (type(cfg) == "table" and cfg.bob_speed) or 1.0,

    mids_target = mids_target,
    mid_w = mid_w,
    total_w_full = total_w,
    center_x = center_x,

    -- animation
    t = 0,
    dur = (type(cfg) == "table" and cfg.dur) or 0.14,
    close_dur = (type(cfg) == "table" and cfg.close_dur) or nil,
    mids_drawn = 0,
    complete = false,

    text_display_id = "nameplate:" .. tostring(box_id),
  }
end


function Nameplate:begin_close(player_id, player_data, box_data, cfg)
  local np = box_data.nameplate
  if not np then return end
  if np.closing then return end

  np.closing = true
  np.close_t = 0

  -- allow per-box override, else per-nameplate config, else fall back
  local cd =
    (type(cfg) == "table" and cfg.close_dur)
    or np.close_dur
    or (type(cfg) == "table" and cfg.dur)
    or np.dur
    or 0.12

  np.close_dur = cd

  -- Hide text immediately so it doesn't ghost over transitions
  if self.font_system and np.text_display_id then
    self.font_system:eraseTextDisplay(player_id, np.text_display_id)
  end
end

function Nameplate:update(player_id, player_data, box_data, dt)
  local np = box_data.nameplate
  if not np then return end

  dt = math.min(dt or 0, 1/30)

  -- If closing: reverse-unfold then self-erase
  if np.closing then
    np.close_t = (np.close_t or 0) + dt
    local p = np.close_t / (np.close_dur or 0.12)
    if p >= 1 then
      self:erase(player_id, player_data, box_data)
      return
    end

    local remain = 1 - p
    local mids = math.max(0, math.floor(np.mids_target * remain + 0.0001))
    np.mids_drawn = mids
  else
    -- unfold
    if not np.complete then
      np.t = np.t + dt
      local p = np.t / np.dur
      if p >= 1 then p = 1; np.complete = true end
      local mids = math.max(1, math.floor(np.mids_target * p + 0.0001))
      np.mids_drawn = mids
    end
  end

  local scale = box_data.scale or 2.0
  local z = np.z

  local mids = np.mids_drawn
  local total_w = (self.w_left + self.w_right) * scale + (mids * np.mid_w)
 
  -- keep the middle piece centered while unfolding
  local left_x = math.floor((np.center_x - (total_w / 2)) + 0.5)

  -- subtle bob (PIXEL-SNAPPED so plate + frame + text never desync)
  np.bob_t = (np.bob_t or 0) + (dt or 0) * (np.bob_speed or 1.0)

  -- snap bob to whole pixels (no subpixel jitter)
  local bob = math.floor((math.sin(np.bob_t) * (np.bob_amp or 0)) + 0.5)

  -- snap final y too
  local y = math.floor(((np.base_y or np.y) + bob) + 0.5)

  -- DEBUG: detect anchor drift (this is the #1 cause of "moves while typing")
  if np.debug then
    np._last_ax = np._last_ax or left_x
    np._last_ay = np._last_ay or y

    local dx = left_x - np._last_ax
    local dy = y - np._last_ay

    if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then
      _np_dbg(player_id, box_data.id or "?", "ANCHOR_DRIFT",
        "dx=" .. string.format("%.3f", dx) ..
        " dy=" .. string.format("%.3f", dy) ..
        " left_x=" .. string.format("%.3f", left_x) ..
        " y=" .. string.format("%.3f", y)
      )
    end

    np._last_ax = left_x
    np._last_ay = y
  end

  -- =========================
  -- BASE + OVERLAY (INTERLEAVED)
  -- =========================

  local mx = left_x + (self.w_left * scale)

  -- overlay tint config (we'll draw it immediately after each base piece)
  local f = np.frame
  local draw_frame = (type(f) == "table") and ((tonumber(f.a) or 255) > 0)

  local fz, fr, fg, fb, fa, fmode
  if draw_frame then
    fz = z + 1
    fr = tonumber(f.r) or 255
    fg = tonumber(f.g) or 255
    fb = tonumber(f.b) or 255
    fa = tonumber(f.a) or 255
    fmode = tonumber(f.color_mode) or 2

    if np.debug then
      _np_dbg(player_id, box_data.id or "?", "FRAME_IDS",
        "idp=" .. tostring(np.idp) ..
        " LF=" .. tostring(np.idp .. "_FL") ..
        " MF0=" .. tostring(np.idp .. "_FM0") ..
        " RF=" .. tostring(np.idp .. "_FR")
      )
      _np_dbg(player_id, box_data.id or "?", "FRAME_TINT",
        "r=" .. tostring(fr) .. " g=" .. tostring(fg) .. " b=" .. tostring(fb) ..
        " a=" .. tostring(fa) .. " mode=" .. tostring(fmode)
      )
    end
  end

  -- LEFT (base, then frame)
  Net.player_draw_sprite(player_id, self.SID_LEFT, {
    id = np.idp .. "_L",
    x = left_x, y = y, z = z,
    sx = scale, sy = scale,
    r = 255, g = 255, b = 255, a = 255,
    color_mode = 0,
  })

  if draw_frame then
    Net.player_draw_sprite(player_id, self.SID_LEFT_F, {
      id = np.idp .. "_FL",
      x = left_x, y = y, z = fz,
      sx = scale, sy = scale,
      r = fr, g = fg, b = fb, a = fa,
      color_mode = fmode,
    })
  else
    Net.player_erase_sprite(player_id, np.idp .. "_FL")
  end

  -- MIDS (base+frame per-slice)
  for i = 0, mids - 1 do
    local px = mx + (i * np.mid_w)

    Net.player_draw_sprite(player_id, self.SID_MID0 .. i, {
      id = np.idp .. "_M" .. i,
      x = px, y = y, z = z,
      sx = scale, sy = scale,
      r = 255, g = 255, b = 255, a = 255,
      color_mode = 0,
    })

    if draw_frame then
      Net.player_draw_sprite(player_id, self.SID_MID0_F .. i, {
        id = np.idp .. "_FM" .. i,
        x = px, y = y, z = fz,
        sx = scale, sy = scale,
        r = fr, g = fg, b = fb, a = fa,
        color_mode = fmode,
      })
    else
      Net.player_erase_sprite(player_id, np.idp .. "_FM" .. i)
    end
  end

  -- erase unused mids (base + frame) together
  for i = mids, self.MAX_MIDS - 1 do
    Net.player_erase_sprite(player_id, np.idp .. "_M" .. i)
    Net.player_erase_sprite(player_id, np.idp .. "_FM" .. i)
  end

  -- RIGHT (base, then frame)
  local rx = mx + (mids * np.mid_w)

  Net.player_draw_sprite(player_id, self.SID_RIGHT, {
    id = np.idp .. "_R",
    x = rx, y = y, z = z,
    sx = scale, sy = scale,
    r = 255, g = 255, b = 255, a = 255,
    color_mode = 0,
  })

  if draw_frame then
    Net.player_draw_sprite(player_id, self.SID_RIGHT_F, {
      id = np.idp .. "_FR",
      x = rx, y = y, z = fz,
      sx = scale, sy = scale,
      r = fr, g = fg, b = fb, a = fa,
      color_mode = fmode,
    })
  else
    Net.player_erase_sprite(player_id, np.idp .. "_FR")
  end
 

  -- =========================
  -- TEXT
  -- =========================
  if np.complete and not np.closing then
    local text_x = math.floor((left_x + (self.w_left * scale) + np.pad_px) + 0.5)
    local text_y = math.floor((y + (3 * scale) + 2) + 0.5)

    self.font_system:drawTextWithId(
      player_id,
      np.text,
      text_x,
      text_y,
      np.font,
      np.text_scale,
      z + 2,
      np.text_display_id
    )
  end
end

return Nameplate

