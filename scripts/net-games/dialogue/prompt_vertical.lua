-- scripts/net-games/dialogue/prompt_vertical.lua
-- Vertical menu prompt helper for net-games Dialogue
-- - Keeps textbox open (optional handoff)
-- - Draws a separate menu window sprite + option text + cursor/highlight + scrollbar
-- - Supports N options with 3..5 (or any) visible rows via layout.visible_rows

local Displayer  = require("scripts/net-games/displayer/displayer")
local Input      = require("scripts/net-games/input/input")
local FontSystem = require("scripts/net-games/displayer/font-system")

local MENUDBG = true
local function mdbg(pid, msg)
  if not MENUDBG then return end
  print(string.format("[MENUDBG t=%.3f p=%s] %s", os.clock(), tostring(pid), tostring(msg)))
end


local PromptVertical = {}
PromptVertical.instances = {}
PromptVertical._tick_attached = false

--========================
-- Assets (you said these exist under /server/assets/net-games/ui/)
-- Adjust paths here if your filenames differ.
--========================
local DEFAULT_ASSET = {
  menu_bg       = "/server/assets/net-games/ui/prompt_vert_menu_an.png",
  menu_bg_anim  = "/server/assets/net-games/ui/prompt_vert_menu_an.animation",
  menu_bg_frame = "/server/assets/net-games/ui/prompt_vert_menu_an_frame.png",
  highlight     = "/server/assets/net-games/ui/highlight_default.png",
  cursor        = "/server/assets/net-games/ui/green_cursor.png",
  scrollbar     = "/server/assets/net-games/ui/scrollbar.png",

  shop_item     = "/server/assets/net-games/ui/card_shop_item.png",
  shop_exit = "/server/assets/net-games/ui/card_shop_exit.png",

}

local function merge_assets(overrides)
  if type(overrides) ~= "table" then
    return DEFAULT_ASSET
  end

  local out = {}
  for k, v in pairs(DEFAULT_ASSET) do out[k] = v end
  for k, v in pairs(overrides) do out[k] = v end
  return out
end



-- =====================================================
-- Prompt vertical menu final size (matches OPEN_IDLE)
-- =====================================================
local MENU_W = 238
local MENU_H = 95


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
  return "ng_prompt_menu_" .. tostring(player_id)
end

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function ensure_tick()
  if PromptVertical._tick_attached then return end
  PromptVertical._tick_attached = true

  Net:on("tick", function(event)
    for player_id, inst in pairs(PromptVertical.instances) do
      -- If textbox got removed externally, kill prompt safely
      local state = Displayer.Text.getTextBoxState(player_id, inst.box_id)
      if not state then
        PromptVertical.close(player_id, "textbox_missing")
      else
        inst:update(event.delta_time or 0)
      end
    end
  end)
end

local function provide_ui_assets(player_id, assets)
  Net.provide_asset_for_player(player_id, assets.menu_bg)
  Net.provide_asset_for_player(player_id, assets.menu_bg_frame)
  Net.provide_asset_for_player(player_id, assets.menu_bg_anim)
  Net.provide_asset_for_player(player_id, assets.highlight)
  Net.provide_asset_for_player(player_id, assets.cursor)
  Net.provide_asset_for_player(player_id, assets.scrollbar)
  Net.provide_asset_for_player(player_id, assets.shop_item)
  Net.provide_asset_for_player(player_id, assets.shop_exit)

end

local function alloc_ui_sprites(inst)
  if inst._sprites_allocated then return end
  inst._sprites_allocated = true

  local player_id = inst.player_id
  local A = inst.assets
  local S = inst.spr

  provide_ui_assets(player_id, A)

  -- MENU_BG is animated; start idle by default (we'll play OPEN once manually)
  Net.player_alloc_sprite(player_id, S.MENU_BG, {
    texture_path = A.menu_bg,
    anim_path    = A.menu_bg_anim,
    anim_state   = "OPEN_IDLE",
  })

  -- MENU_FRAME uses the SAME animation file; only swaps texture
  Net.player_alloc_sprite(player_id, S.MENU_FRAME, {
    texture_path = A.menu_bg_frame,
    anim_path    = A.menu_bg_anim,
    anim_state   = "OPEN_IDLE",
  })

  Net.player_alloc_sprite(player_id, S.HILITE, { texture_path = A.highlight })
  Net.player_alloc_sprite(player_id, S.CURSOR, { texture_path = A.cursor })
  Net.player_alloc_sprite(player_id, S.SCROLL, { texture_path = A.scrollbar })

  Net.player_alloc_sprite(player_id, S.SHOP_ITEM, { texture_path = A.shop_item })
  Net.player_alloc_sprite(player_id, S.SHOP_EXIT, { texture_path = A.shop_exit })

end


local function draw_sprite(inst, sprite_id, draw_id, x, y, z, s, anim_state)
  alloc_ui_sprites(inst)

  -- pixel-snap to avoid sub-pixel shimmer/jitter
  if x ~= nil then x = math.floor(x + 0.5) end
  if y ~= nil then y = math.floor(y + 0.5) end

  local opts = {
    id = draw_id,
    x = x, y = y, z = z,
    sx = s or 2.0,
    sy = s or 2.0,
  }

  if anim_state then
    opts.anim_state = anim_state
  end

  Net.player_draw_sprite(inst.player_id, sprite_id, opts)
end

local function draw_sprite_xy(inst, sprite_id, draw_id, x, y, z, sx, sy, anim_state)
  alloc_ui_sprites(inst)

  -- pixel-snap to avoid sub-pixel shimmer/jitter
  if x ~= nil then x = math.floor(x + 0.5) end
  if y ~= nil then y = math.floor(y + 0.5) end

  local opts = {
    id = draw_id,
    x = x, y = y, z = z,
    sx = sx or 2.0,
    sy = sy or 2.0,
  }

  if anim_state then
    opts.anim_state = anim_state
  end

  Net.player_draw_sprite(inst.player_id, sprite_id, opts)
end



local function draw_menu_frame_overlay(inst, draw_id, x, y, z, s, anim_state, frame_cfg)
  if type(frame_cfg) ~= "table" then
    -- ensure no stale overlay is left behind
    Net.player_erase_sprite(inst.player_id, draw_id)
    return
  end

  local a = tonumber(frame_cfg.a) or 255
  if a <= 0 then
    Net.player_erase_sprite(player_id, draw_id)
    return
  end

  local opts = {
    id = draw_id,
    x = x, y = y, z = z,
    sx = s or 2.0,
    sy = s or 2.0,
    r = tonumber(frame_cfg.r) or 255,
    g = tonumber(frame_cfg.g) or 255,
    b = tonumber(frame_cfg.b) or 255,
    a = a,
    color_mode = tonumber(frame_cfg.color_mode) or 2,
  }

  if anim_state then
    opts.anim_state = anim_state
  end

  Net.player_draw_sprite(inst.player_id, inst.spr.MENU_FRAME, opts)
end


local function erase_sprite(player_id, draw_id)
  Net.player_erase_sprite(player_id, draw_id)
end

--========================
-- Layout normalization
--========================
local function normalize_ui(ui)
  -- This is the textbox UI, same pattern as prompt.lua
  local o = {
    box_id = ui.box_id,
    font  = ui.font or "THIN_BLACK",
    scale = ui.scale or 2.0,
    z     = ui.z or 100,

    x = ui.x or 8,
    y = ui.y or 110,
    w = ui.w or 224,
    h = ui.h or 42,

    backdrop  = ui.backdrop or ui.backdrop_config or nil,
    mugshot   = ui.mugshot or nil,
    nameplate = ui.nameplate,

    typing_speed    = ui.typing_speed or 12,
    type_sfx_path   = ui.type_sfx_path,
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

local function normalize_layout(layout)
  layout = layout or {}

  -- Menu window geometry:
  -- You can anchor relative to textbox or use absolute screen coords.
  -- Default: anchor to textbox and sit above it.
  local o = {
    anchor = layout.anchor or "textbox", -- "textbox" or "absolute"

    -- For absolute anchor
    x = layout.x,
    y = layout.y,

    -- For textbox anchor
    offset_x = layout.offset_x or 0,
    offset_y = layout.offset_y or -200, -- above textbox by default
    gap      = layout.gap or 4,

    -- Size of menu window in pixels (these control sprite scaling)
    width  = layout.width  or 160,
    height = layout.height or 64,

    -- Text inside the menu
    font  = layout.font  or "THIN_BLACK",
    scale = layout.scale or 2.0,
    z     = layout.z or 130,
    -- Optional dyed overlay for the menu frame (same pattern as textbox/nameplate)
    -- If provided, we draw prompt_vert_menu_an_frame.png on top with r/g/b/a + color_mode.
    frame = layout.frame,


    padding_x   = layout.padding_x or 12,
    padding_y   = layout.padding_y or 10,
    row_height  = layout.row_height or 12, -- pixels BEFORE scale
    visible_rows = tonumber(layout.visible_rows or 5) or 5,

    -- Cursor/highlight positioning
    cursor_offset_x = layout.cursor_offset_x or 6,
    cursor_offset_y = layout.cursor_offset_y or 1,
    highlight_inset_x = layout.highlight_inset_x or 8,
    highlight_inset_y = layout.highlight_inset_y or 0,

    -- Scrollbar positioning (relative to menu top-left)
    scrollbar_x = layout.scrollbar_x or 148,
    scrollbar_y = layout.scrollbar_y or 12,
    scrollbar_h = layout.scrollbar_h or 40,
    thumb_min_h = layout.thumb_min_h or 6,
    thumb_w     = layout.thumb_w or 6, -- sprite scaled via sx
     -- Text intro animation (optional; off by default)
    text_intro_enabled        = (layout.text_intro_enabled == true),
    text_intro_frames         = tonumber(layout.text_intro_frames or 20) or 20,
    text_intro_stagger_frames = tonumber(layout.text_intro_stagger_frames or 3) or 3,
    text_intro_slide_px       = tonumber(layout.text_intro_slide_px or 10) or 10, 
  
    -- Shop-only top-right label (optional)
    monies_label_enabled = (layout.monies_label_enabled == true),
    monies_label_text    = layout.monies_label_text,
    monies_label_font    = layout.monies_label_font,
    monies_label_pad_x   = layout.monies_label_pad_x,
    monies_label_pad_y   = layout.monies_label_pad_y,
    monies_label_z_add   = layout.monies_label_z_add,
  
    -- Shop-only money amount (NEW)
    monies_amount_enabled  = (layout.monies_amount_enabled == true),
    monies_amount_text     = layout.monies_amount_text,
    monies_amount_font     = layout.monies_amount_font,
    monies_amount_offset_x = layout.monies_amount_offset_x,
    monies_amount_offset_y = layout.monies_amount_offset_y,

    -- Shop-only image label (NEW)
    shop_item_enabled = (layout.shop_item_enabled == true),
    shop_item_pad_x   = layout.shop_item_pad_x,
    shop_item_pad_y   = layout.shop_item_pad_y,
    shop_item_z_add   = layout.shop_item_z_add,

    shop_item_swap_exit = (layout.shop_item_swap_exit == true),

    -- Shop item intro "unfold" animation (NEW)
    shop_item_intro_enabled = (layout.shop_item_intro_enabled == true),
    shop_item_intro_frames  = tonumber(layout.shop_item_intro_frames or 10) or 10,

    -- Required for true center-scaling (set these in your preset!)
    shop_item_w = tonumber(layout.shop_item_w or 0) or 0,
    shop_item_h = tonumber(layout.shop_item_h or 0) or 0,
    shop_exit_w = tonumber(layout.shop_exit_w or 0) or 0,
    shop_exit_h = tonumber(layout.shop_exit_h or 0) or 0,


  }

  -- Safety: visible rows must be >= 1
  o.visible_rows = math.max(1, o.visible_rows)

  return o
end

--========================
-- Instance
--========================
local STATE = {
  TEXT      = "text",      -- textbox printing/paging; menu visible but locked
  MENU      = "menu",      -- menu input active
  SUBPROMPT = "subprompt", -- reserved for nested yes/no later
  CLOSING   = "closing",
}

local PromptMenuInstance = {}
PromptMenuInstance.__index = PromptMenuInstance

function PromptMenuInstance:new(player_id, opts)
  local o = setmetatable({}, self)

  opts = opts or {}
  o.player_id = player_id

  o.box_id = (opts.ui and opts.ui.box_id) or mk_id(player_id)
  o.ui = normalize_ui(opts.ui or {})
  o.layout = normalize_layout(opts.layout or {})

  -- Per-instance assets (prevents cross-NPC overwrites)
  o.assets = merge_assets(opts.assets)

  -- Per-instance sprite IDs (string IDs are safe; see font-system usage)
  local base = o.box_id
  o.spr = {
    MENU_BG    = "pv_" .. base .. "_spr_menu_bg",
    MENU_FRAME = "pv_" .. base .. "_spr_menu_frame",
    HILITE     = "pv_" .. base .. "_spr_hilite",
    CURSOR     = "pv_" .. base .. "_spr_cursor",
    SCROLL     = "pv_" .. base .. "_spr_scroll",
    SHOP_ITEM  = "pv_" .. base .. "_spr_shop_item",
    SHOP_EXIT  = "pv_" .. base .. "_spr_shop_exit",
  }

  o._sprites_allocated = false



  o.question = tostring(opts.question or "Choose:")
  o.options  = opts.options or { { text = "Exit" } }

  -- Cache for menu text redraw (prevents flicker)
  o._text_cache_top = nil
  o._text_cache_rows = nil
  o._text_cache_total = nil


  -- Normalize options to { text=..., id=..., value=... }
  for i = 1, #o.options do
    local v = o.options[i]
    if type(v) == "string" then
      o.options[i] = { text = v }
    else
      o.options[i].text = tostring(v.text or v[1] or ("Option " .. i))
    end
  end

  o.default_index = clamp(tonumber(opts.default_index or 1) or 1, 1, #o.options)
  o.selection_index = o.default_index
  o.scroll_top_index = 1

  -- Cancel behavior:
  --   "jump_to_exit" (default): B jumps to exit_index; second B selects it
  --   "close"                 : close immediately and call on_cancel
  --   "ignore"                : do nothing
  o.cancel_behavior = opts.cancel_behavior or "jump_to_exit"
  o.exit_index = clamp(tonumber(opts.exit_index or #o.options) or #o.options, 1, #o.options)

  o.keep_textbox = (opts.keep_textbox ~= false) -- default true for handoff/reuse
  
  -- If true, we will reuse an existing textbox UI and just replace its text
  -- (this avoids the createTextBox collision path and gives us "new dialogue" in same window)
  o.reuse_existing_box = (opts.reuse_existing_box == true)

    o.on_select = opts.on_select or function(_choice, _index) end
    o.on_cancel = opts.on_cancel or function() end

    -- Goal_1_5 additions:
    o.keep_menu_open = (opts.keep_menu_open == true)
    o.selection_behavior = tostring(opts.selection_behavior or "close_then_callback")
    o.on_choose = opts.on_choose -- optional: function(choice, index, menu)

    o.lock_dim_alpha = tonumber(opts.lock_dim_alpha or 0.35) or 0.35
    o.hide_cursor_when_locked = (opts.hide_cursor_when_locked ~= false)

    o.locked = false

  o.state = STATE.TEXT
  o.ready_for_input = false

  -- Draw IDs (unique per instance)
  local base = o.box_id
  o.draw = {
    menu_bg   = base .. "_menu_bg",
    menu_frame= base .. "_menu_frame",
    hilite    = base .. "_menu_hilite",
    cursor    = base .. "_menu_cursor",
    scroll    = base .. "_menu_scroll",
    monies    = base .. "_menu_monies",
    monies_amount = base .. "_menu_monies_amount",

    shop_item = base .. "_menu_shop_item",
    shop_exit = base .. "_menu_shop_exit",
  }

  -- Stable text display IDs (one per visible row) to prevent flicker.
  -- We reuse these IDs and redraw in-place instead of erasing/recreating every move.
  o.menu_text_ids = {}

  -- Cursor bob state (used only when menu input is active)
  o.cursor_phase  = 0
  o.cursor_base_x = nil
  o.cursor_base_y = nil
  -- Menu window animation control
  o.menu_bg_needs_open = true   -- first draw should play OPEN once
  o.menu_bg_set_idle_next = false
  -- Gate: don't animate menu until textbox finishes opening
  o.wait_textbox_open_idle = true

  o.menu_contents_pending = true
  -- Text intro animation state
  o._text_intro_active = false
  o._text_intro_t = 0
  -- Text intro speed boost (temporary, per intro run)
  o._text_intro_speed_mult = 1
  o._text_intro_boosted = false

  -- Shop item intro animation state (NEW)
  o._shop_item_intro_active = false
  o._shop_item_intro_t = 0



  -- OPEN anim timing (must outlive a single tick)
  o.menu_bg_open_t = 0
  o.menu_bg_open_total = 0.16 -- 0.04*5 + 0.20 (from your .animation)
  o.menu_bg_open_playing = false

  -- CLOSE anim timing (must outlive a single tick)
  o.menu_bg_close_t = 0
  o.menu_bg_close_total = 0.12 -- your CLOSE: 0.04*5 + 0.40 = 0.60
  o.menu_bg_close_playing = false

  -- Close pipeline
  o.pending_close = false
  o.pending_close_keep_textbox = false
  o.pending_close_reason = nil



    o:render_textbox()

    -- Don't draw contents yet. Let OPEN finish first.
    o.menu_contents_pending = true

    return o

    end

function PromptMenuInstance:render_textbox()
  local ui = self.ui
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

  -- IMPORTANT:
  -- When reusing an existing textbox, passing nameplate again re-attaches it,
  -- which erases + restarts the nameplate animation (looks like a reset).
  if self.reuse_existing_box then
    ops.nameplate = nil
  end


    -- If the textbox already exists (ex: coming from a YES/NO prompt),
    -- reset it so we get fresh text in the SAME box without closing/reopening UI.
    if self.reuse_existing_box then
      if Displayer.Text.reset_text_box then
        -- snake_case wrapper
        Displayer.Text.reset_text_box(
          self.player_id, self.box_id, self.question,
          ui.x, ui.y, ui.w, ui.h,
          ui.font, ui.scale, ui.z,
          ui.backdrop,
          ui.typing_speed,
          ops
        )
        return
      elseif Displayer.Text.resetTextBox then
        -- camelCase (method form)
        Displayer.Text:resetTextBox(
          self.player_id, self.box_id, self.question,
          ui.x, ui.y, ui.w, ui.h,
          ui.font, ui.scale, ui.z,
          ui.backdrop,
          ui.typing_speed,
          ops
        )
        return
      end
    end


  -- Fallback: create normally
  if Displayer.Text.create_text_box then
    Displayer.Text.create_text_box(
      self.player_id, self.box_id, self.question,
      ui.x, ui.y, ui.w, ui.h,
      ui.font, ui.scale, ui.z,
      ui.backdrop,
      ui.typing_speed,
      ops
    )
  else
    Displayer.Text.createTextBox(
      self.player_id, self.box_id, self.question,
      ui.x, ui.y, ui.w, ui.h,
      ui.font, ui.scale, ui.z,
      ui.backdrop,
      ui.typing_speed,
      ops
    )
  end
end


function PromptMenuInstance:menu_origin()
  local L = self.layout
  local bd = Displayer.Text.getTextBoxData(self.player_id, self.box_id)

  if L.anchor == "absolute" or not bd then
    return (L.x or 24), (L.y or 32)
  end

  -- Anchor to the visible panel if we have a backdrop; otherwise fall back to textbox data.
local tx = (self.ui.backdrop and self.ui.backdrop.x) or bd.x or self.ui.x or 0
local ty = (self.ui.backdrop and self.ui.backdrop.y) or bd.y or self.ui.y or 0



  local mx = tx + (L.offset_x or 0)
  local my = ty + (L.offset_y or 0) - (L.gap or 0)

  return mx, my
end

function PromptMenuInstance:start_close(reason, keep_textbox)
  if self.state == STATE.CLOSING or self.pending_close then
    return
  end

  self.pending_close = true
  self.pending_close_reason = reason
  self.pending_close_keep_textbox = (keep_textbox == true)

  -- Stop menu input immediately
  self.state = STATE.CLOSING
  self.ready_for_input = false

  -- Kill overlays + menu text right away (background stays to animate out)
  erase_sprite(self.player_id, self.draw.hilite)
  erase_sprite(self.player_id, self.draw.cursor)
  erase_sprite(self.player_id, self.draw.scroll)

  erase_sprite(self.player_id, self.draw.shop_item)
  erase_sprite(self.player_id, self.draw.shop_exit)



  FontSystem:eraseTextDisplay(self.player_id, self.draw.monies)
  FontSystem:eraseTextDisplay(self.player_id, self.draw.monies_amount)
  self:clear_menu_text()

  -- If OPEN is mid-play, stop it so it doesn't fight CLOSE
  self.menu_bg_open_playing = false

  -- Draw CLOSE state once and start timer
  local L = self.layout
  local x, y = self:menu_origin()
  x = x + (MENU_W * L.scale)
  y = y + (MENU_H * L.scale)

  mdbg(self.player_id, "MENU_BG anim_state => CLOSE")
    draw_sprite(
      self, self.spr.MENU_BG,
      self.draw.menu_bg,
      x, y,
      L.z,
      L.scale,
      "CLOSE"
    )


    -- frame overlay (dyed) closes in lockstep with the base
    draw_menu_frame_overlay(
      self,
      self.draw.menu_frame,
      x, y,
      L.z + 1,
      L.scale,
      "CLOSE",
      L.frame
    )



  self.menu_bg_close_t = 0
  self.menu_bg_close_playing = true
end


function PromptMenuInstance:render_menu_window()
  local L = self.layout
  local x, y = self:menu_origin()
  -- Shift draw position so bottom-right stays anchored
    x = x + (MENU_W * L.scale)
    y = y + (MENU_H * L.scale)


  -- First time: play OPEN once, then next update will force OPEN_IDLE
  local anim = nil
  if self.menu_bg_needs_open then
  mdbg(self.player_id, "MENU_BG anim_state => OPEN")

    anim = "OPEN"
    self.menu_bg_needs_open = false

    -- start OPEN timer; do NOT slam OPEN_IDLE next tick
    self.menu_bg_open_t = 0
    self.menu_bg_open_playing = true
  end


    draw_sprite(
      self, self.spr.MENU_BG,
      self.draw.menu_bg,
      x, y,
      L.z,
      L.scale,
      anim
    )


    -- dyed frame overlay (uses same animation file; only texture differs)
    draw_menu_frame_overlay(
      self,
      self.draw.menu_frame,
      x, y,
      L.z + 1,
      L.scale,
      anim,
      L.frame
    )

end

function PromptMenuInstance:clear_menu_text()
  if not self.menu_text_ids then
    self.menu_text_ids = {}
    return
  end

  for _, id in ipairs(self.menu_text_ids) do
    FontSystem:eraseTextDisplay(self.player_id, id)
  end

  self.menu_text_ids = {}
end


function PromptMenuInstance:update_scroll_for_selection(force)
  local L = self.layout
  local total = #self.options
  local rows = L.visible_rows

  local sel = self.selection_index
  local top = self.scroll_top_index

  -- Keep selection in view
  if sel < top then
    top = sel
  elseif sel > (top + rows - 1) then
    top = sel - (rows - 1)
  end

  local max_top = math.max(1, total - rows + 1)
  top = clamp(top, 1, max_top)

  local changed = (top ~= self.scroll_top_index)
  self.scroll_top_index = top

  return force or changed
end

local function set_textbox_indicator_enabled(player_id, box_id, enabled)
  local bd = Displayer.Text.getTextBoxData(player_id, box_id)
  if not bd or not bd.backdrop then return end
  bd.backdrop.indicator = bd.backdrop.indicator or {}
  bd.backdrop.indicator.enabled = enabled and true or false
end


function PromptMenuInstance:menu_overlays_visible()
  return (self.state == STATE.MENU)
     and (self.ready_for_input == true)
     and (self.locked ~= true)
end

function PromptMenuInstance:set_locked(locked)
  self.locked = (locked == true)

  if self.locked then
    self.ready_for_input = false

    -- IMPORTANT:
    -- Do NOT force-disable the textbox indicator here.
    -- When locked, other systems (Prompt.yesno / post-select text) may WANT the indicator.
    -- The caller can toggle it as needed.

    -- Cursor goes away when locked (Goal_1_5)
    if self.hide_cursor_when_locked then
      erase_sprite(self.player_id, self.draw.cursor)
      self.cursor_base_x = nil
      self.cursor_base_y = nil
    end
  else
    self.ready_for_input = true

    -- While the menu is interactable, the textbox indicator should stay off.
    set_textbox_indicator_enabled(self.player_id, self.box_id, false)
  end

  -- Force a redraw so dim/highlight updates immediately
  self:update_scroll_for_selection(true)
  self:render_menu_contents(true)
end



function PromptMenuInstance:update_cursor_bob(dt)
  if not self:menu_overlays_visible() then return end
  if not self.cursor_base_x or not self.cursor_base_y then return end

  dt = math.min(dt or 0, 1/30)

  -- "Prompt cursor" feel:
  -- snap left instantly, then push right smoothly, then snap left again.
  local cycle_sec = 0.36      -- total loop length
  local snap_left = 2.0       -- pixels left from base (before scale)
  local push_right = 3.0      -- pixels to push right from snapped position (before scale)
  local push_portion = 0.70   -- % of cycle used for the push (rest is hold)

  local scale = tonumber(self.layout.scale) or 2.0
  local snap_px = snap_left * scale
  local push_px = push_right * scale

  self.cursor_phase = (self.cursor_phase or 0) + dt

  -- normalize phase into [0, cycle_sec)
  if self.cursor_phase >= cycle_sec then
    self.cursor_phase = self.cursor_phase - cycle_sec
  end

  local t = self.cursor_phase / cycle_sec

  -- Ease-out curve for the push (fast at start, slows near end)
  local function ease_out_quad(x)
    return 1 - (1 - x) * (1 - x)
  end

  local x
  if t < push_portion then
    local p = ease_out_quad(t / push_portion)
    -- snap to (base - snap) then push right by push_px
    x = (self.cursor_base_x - snap_px) + (push_px * p)
  else
    -- hold at the pushed position until the next snap
    x = (self.cursor_base_x - snap_px) + push_px
  end

    draw_sprite(
      self, self.spr.CURSOR,
      self.draw.cursor,
      x,
      self.cursor_base_y,
      (self.layout.z + 3),
      self.layout.scale
    )

end



function PromptMenuInstance:render_menu_contents(force)
-- Hard gate: nothing should render until the menu bg finished OPEN -> OPEN_IDLE
if self.menu_bg_open_playing or self.menu_bg_needs_open then
  -- ensure nothing lingering
  if self.menu_text_ids and #self.menu_text_ids > 0 then
    self:clear_menu_text()
  end

  self._text_cache_top = nil
  self._text_cache_rows = nil
  self._text_cache_total = nil
  erase_sprite(self.player_id, self.draw.hilite)
  erase_sprite(self.player_id, self.draw.cursor)
  erase_sprite(self.player_id, self.draw.scroll)
  FontSystem:eraseTextDisplay(self.player_id, self.draw.monies)
  FontSystem:eraseTextDisplay(self.player_id, self.draw.monies_amount)
  return
end


  local L = self.layout
  local x0, y0 = self:menu_origin()

-- ========================
-- SHOP label: "MONIES" (WIDE font) - top-right of menu window
-- ========================
do
  if L.monies_label_enabled then
    local scale = tonumber(L.scale) or 2.0
    local text  = tostring(L.monies_label_text or "MONIES")
    local font  = tostring(L.monies_label_font or "WIDE_BLACK")

    local pad_x = (tonumber(L.monies_label_pad_x) or 6) * scale
    local pad_y = (tonumber(L.monies_label_pad_y) or 4) * scale
    local zadd  = tonumber(L.monies_label_z_add) or 4

    local tw = FontSystem:getTextWidth(text, font, scale)

    -- menu sprite is drawn anchored to bottom-right (x0,y0 is top-left),
    -- so MENU_W is the correct width reference here.
    local mx = x0 + (MENU_W * scale) - pad_x - tw
    local my = y0 + pad_y

    FontSystem:drawTextWithId(
      self.player_id,
      text,
      mx, my,
      font,
      scale,
      (L.z + zadd),
      self.draw.monies
    )
        -- Amount line under MONIES (THIN)
    if L.monies_amount_enabled then
      local atext = tostring(L.monies_amount_text or "0$")
      local afont = tostring(L.monies_amount_font or "THIN")

      local ax_off = (tonumber(L.monies_amount_offset_x) or 0) * scale
      local ay_off = (tonumber(L.monies_amount_offset_y) or 10) * scale

      local atw = FontSystem:getTextWidth(atext, afont, scale)

      -- Right-align to the same right edge as MONIES, then apply offsets
      local ax = (mx + tw) - atw + ax_off
      local ay = my + ay_off

      FontSystem:drawTextWithId(
        self.player_id,
        atext,
        ax, ay,
        afont,
        scale,
        (L.z + zadd),
        self.draw.monies_amount
      )
    else
      FontSystem:eraseTextDisplay(self.player_id, self.draw.monies_amount)
    end

        if L.shop_item_enabled then
          local scale = tonumber(L.scale) or 2.0
          local ix = x0 + (MENU_W * scale) - (tonumber(L.shop_item_pad_x) or 0)
          local iy = y0 + (tonumber(L.shop_item_pad_y) or 0)
          local zadd = tonumber(L.shop_item_z_add) or 3

          local cur = (self.options and self.selection_index) and self.options[self.selection_index] or nil
          local cur_id = cur and cur.id or nil
          local cur_text = cur and cur.text or nil

          local is_exit_hover =
            (self.selection_index == self.exit_index) or
            (cur_id ~= nil and tostring(cur_id) == "exit") or
            (cur_text ~= nil and string.lower(tostring(cur_text)) == "exit")

          if (L.shop_item_swap_exit == true) and is_exit_hover then
            -- show EXIT, hide ITEM
            erase_sprite(self.player_id, self.draw.shop_item)
            local w = tonumber(L.shop_exit_w) or 0
            local h = tonumber(L.shop_exit_h) or 0

            local sx = scale
            local sy = scale
            local dx = ix
            local dy = iy

            if self._shop_item_intro_active and w > 0 then
              local frames = tonumber(L.shop_item_intro_frames) or 10
              local dur = frames / 60
              local raw = math.min(1, (self._shop_item_intro_t or 0) / math.max(0.0001, dur))

              -- Ease-in that stays thin longer, then snaps open
              local t = raw * raw * raw

              -- start thinner than zero-width visually (BN-style snap)
              local min_p = 0.05   -- 5% width floor
              local p = math.max(min_p, t)

              sx = scale * p

              local cx = ix + (w * scale) / 2
              dx = cx - (w * sx) / 2
            end

            draw_sprite_xy(self, self.spr.SHOP_EXIT, self.draw.shop_exit, dx, dy, (L.z + zadd), sx, sy)

          else
            -- show ITEM, hide EXIT
            erase_sprite(self.player_id, self.draw.shop_exit)
            local w = tonumber(L.shop_item_w) or 0
            local h = tonumber(L.shop_item_h) or 0

            local sx = scale
            local sy = scale
            local dx = ix
            local dy = iy

            if self._shop_item_intro_active and w > 0 then
              local frames = tonumber(L.shop_item_intro_frames) or 10
              local dur = frames / 60
              local raw = math.min(1, (self._shop_item_intro_t or 0) / math.max(0.0001, dur))

              -- Ease-in that stays thin longer, then snaps open
              local t = raw * raw * raw

              -- start thinner than zero-width visually (BN-style snap)
              local min_p = 0.05   -- 5% width floor
              local p = math.max(min_p, t)

              sx = scale * p

              -- keep center fixed while sx changes
              local cx = ix + (w * scale) / 2
              dx = cx - (w * sx) / 2
            end

            draw_sprite_xy(self, self.spr.SHOP_ITEM, self.draw.shop_item, dx, dy, (L.z + zadd), sx, sy)

          end
        else
          erase_sprite(self.player_id, self.draw.shop_item)
          erase_sprite(self.player_id, self.draw.shop_exit)
        end




  else
    FontSystem:eraseTextDisplay(self.player_id, self.draw.monies)
    FontSystem:eraseTextDisplay(self.player_id, self.draw.monies_amount)
  end

end


  -- Only redraw the option TEXT when the visible window changes.
  -- Selection changes only move highlight/cursor, so keep text displays stable to prevent flicker.
  local rows  = L.visible_rows
  local total = #self.options
  local top   = self.scroll_top_index
  local sel   = self.selection_index

  local redraw_text =
    force
    or (self._text_cache_top ~= top)
    or (self._text_cache_rows ~= rows)
    or (self._text_cache_total ~= total)

  if redraw_text then
    -- Keep a stable list of display IDs (one per visible row).
    -- This prevents flicker caused by erase/recreate cycles.
    if not self.menu_text_ids or #self.menu_text_ids ~= rows then
      -- wipe any old row ids
      self:clear_menu_text()
      self.menu_text_ids = {}
      for i = 1, rows do
        self.menu_text_ids[i] = self.box_id .. "_menu_row_" .. tostring(i)
      end
    end

    self._text_cache_top = top
    self._text_cache_rows = rows
    self._text_cache_total = total
  end



  local rows = L.visible_rows
  local total = #self.options
  local top = self.scroll_top_index
  local sel = self.selection_index

  local scale = tonumber(L.scale) or 2.0
  local row_h = (tonumber(L.row_height) or 12) * scale

  -- Content top-left inside window
  local cx = x0 + (L.padding_x or 0)
  local cy = y0 + (L.padding_y or 0)

  if redraw_text then
    for i = 0, rows - 1 do
      local idx = top + i
      local tx = cx
      local ty = cy + (i * row_h)

      local display_id = self.menu_text_ids[i + 1]

      if idx <= total then
        local text = tostring(self.options[idx].text or "")

        -- Intro animation: per-row fade + slight slide from the right
        local opacity = 255
        local xoff = 0

        if self._text_intro_active and self.layout.text_intro_enabled then
          local dur = (tonumber(self.layout.text_intro_frames) or 20) / 60
          local stagger = (tonumber(self.layout.text_intro_stagger_frames) or 3) / 60

          local row_t = (self._text_intro_t or 0) - (i * stagger)
          local p = 0
          if row_t > 0 and dur > 0 then
            p = clamp(row_t / dur, 0, 1)
          end

          -- smoothstep easing (nice and cheap)
          local eased = p * p * (3 - 2 * p)

          opacity = math.floor(255 * eased)
          xoff = (tonumber(self.layout.text_intro_slide_px) or 10) * (1 - eased) * scale
        end

        -- Preserve your locked-dim behavior by multiplying opacity
        if self.locked and (idx ~= sel) then
          opacity = math.floor(opacity * (self.lock_dim_alpha or 0.35))
        end

        local tint = { opacity = opacity }

        FontSystem:drawTextWithId(
          self.player_id,
          text,
          tx + xoff,
          ty,
          L.font,
          scale,
          (L.z + 2),
          display_id,
          tint
        )


      else
        -- If fewer items than rows, erase the unused row display
        FontSystem:eraseTextDisplay(self.player_id, display_id)
        self.menu_row_last_len[i + 1] = 0
      end
    end
  end

  -- Highlight + cursor should only be visible once the menu is actually unlocked
  local sel_row = sel - top
  if sel_row >= 0 and sel_row < rows then
    if (self.state == STATE.MENU) then

      -- Highlight bar (behind selected row)
      local hx = x0 + (L.highlight_inset_x or 0)
      local hy = cy + (sel_row * row_h) + ((L.highlight_inset_y or 0) * scale)

        draw_sprite(
          self, self.spr.HILITE,
          self.draw.hilite,
          hx, hy,
          (L.z + 1),
          L.scale
        )


      -- Cursor base (bob anim uses this)
      local curx = x0 + (L.cursor_offset_x or 0)
      local cury = cy + (sel_row * row_h) + ((L.cursor_offset_y or 0) * scale)

      self.cursor_base_x = curx
      self.cursor_base_y = cury

        if not (self.locked and self.hide_cursor_when_locked) then
            draw_sprite(
              self, self.spr.CURSOR,
              self.draw.cursor,
              curx, cury,
              (L.z + 3),
              L.scale
            )

        else
          erase_sprite(self.player_id, self.draw.cursor)
        end


    else
      -- Menu text is allowed to show, but overlays must not
      self.cursor_base_x = nil
      self.cursor_base_y = nil
      erase_sprite(self.player_id, self.draw.hilite)
      erase_sprite(self.player_id, self.draw.cursor)
    end
  else
    self.cursor_base_x = nil
    self.cursor_base_y = nil
    erase_sprite(self.player_id, self.draw.hilite)
    erase_sprite(self.player_id, self.draw.cursor)
  end

  -- Scroll indicator (only if needed)
  if total > rows then
    local track_x = x0 + (L.scrollbar_x or 0)
    local track_y = y0 + (L.scrollbar_y or 0)

    -- IMPORTANT: scrollbar_h is already in screen pixels. Do NOT multiply by scale.
    local track_h = (L.scrollbar_h or 0)

    local scale = tonumber(L.scale) or 2.0

    -- Indicator height in sprite pixels (pre-scale). Set this to match your scrollbar indicator art.
    -- If your indicator sprite is 8px tall, use 8 (default below).
    local indicator_h = (tonumber(L.scroll_indicator_h) or 8) * scale

    -- Map scroll_top [1..max_top] into the *visible rail*
    local max_top = math.max(1, total - rows + 1)
    local t = 0
    if max_top > 1 then
      t = (top - 1) / (max_top - 1)
    end

    -- Travel space is rail minus indicator height so it never goes past the bottom.
    local travel = math.max(0, track_h - indicator_h)
    local thumb_y = track_y + (travel * t)

    -- Optional: snap to whole pixels to avoid jitter
    thumb_y = math.floor(thumb_y + 0.5)

        draw_sprite(
          self, self.spr.SCROLL,
          self.draw.scroll,
          track_x,
          thumb_y,
          (L.z + 3),
          L.scale
        )

  else
    erase_sprite(self.player_id, self.draw.scroll)
  end
end

function PromptMenuInstance:start_text_intro()
  if not (self.layout and self.layout.text_intro_enabled) then
    self._text_intro_active = false
    self._text_intro_t = 0
    self._text_intro_speed_mult = 1
    self._text_intro_boosted = false
    return
  end

  self._text_intro_active = true
  self._text_intro_t = 0
  self._text_intro_speed_mult = 1
  self._text_intro_boosted = false
end


function PromptMenuInstance:become_ready()
  self.state = STATE.MENU
  self.ready_for_input = true
  -- Menu is now driving progression; indicator should never show during menu lifetime
  set_textbox_indicator_enabled(self.player_id, self.box_id, false)


  -- Reset bob so it doesn't start mid-wave
  self.cursor_phase = 0

  -- Goal_1_5: only draw contents once the menu window is actually ready.
  -- If we render too early (menu_bg_needs_open still true), render_menu_contents()
  -- hard-gates and never sets cursor_base_x/y, so the cursor won't appear until you move.
  if self.menu_bg_open_playing or self.menu_bg_needs_open then
    self.menu_contents_pending = true
  else
    self.menu_contents_pending = false

    -- IMPORTANT:
    -- Do NOT restart the intro here.
    -- In your Pink flow, the menu opens while textbox types, so the intro already ran
    -- when OPEN finished. become_ready() is just “unlock control / show overlays”.
    self:update_scroll_for_selection(true)

    -- Only redraw overlays; avoid forcing a full text redraw
    self:render_menu_contents(false)
  end


  -- Avoid carry-press from dialogue confirm spamming into menu selection
  local held = {}
  if Input.is_down(self.player_id, "up")      then table.insert(held, "up") end
  if Input.is_down(self.player_id, "down")    then table.insert(held, "down") end
  if Input.is_down(self.player_id, "confirm") then table.insert(held, "confirm") end
  if Input.is_down(self.player_id, "cancel")  then table.insert(held, "cancel") end

  if #held > 0 then
    Input.consume(self.player_id)
    Input.require_release(self.player_id, held)
  end
end

function PromptMenuInstance:select_current()
  local idx = self.selection_index
  local choice = self.options[idx]

  -- Goal_1_5: keep menu open and route selection to callback only
  if self.selection_behavior == "callback_only" and type(self.on_choose) == "function" then
    pcall(function()
      self.on_choose(choice, idx, self)
    end)
    return
  end

  -- Default legacy behavior: animate close then callback
  self._post_close_cb = function()
    self.on_select(choice, idx)
  end
  self:start_close("select", self.keep_textbox)
end


function PromptMenuInstance:do_cancel()
  local beh = self.cancel_behavior or "jump_to_exit"

  if beh == "ignore" then
    return
  end

  if beh == "close" then
    self._post_close_cb = function()
      self.on_cancel()
    end
    self:start_close("cancel", self.keep_textbox)

    return
  end

  -- Default: jump_to_exit
  if self.selection_index ~= self.exit_index then
    self.selection_index = self.exit_index
    self:restart_shop_item_intro()
    local sc_changed = self:update_scroll_for_selection(false)
    play_cursor_move_sfx(self.player_id)
    self:render_menu_contents(true)
    return
  end


  -- Already on exit: treat cancel as select
  self:select_current()
end

function PromptMenuInstance:restart_shop_item_intro()
  if not (self.layout and self.layout.shop_item_intro_enabled) then return end
  self._shop_item_intro_active = true
  self._shop_item_intro_t = 0
end



function PromptMenuInstance:update(_dt)
  -- clamp dt to reduce visible stutter from occasional frame-time spikes
  local dt = math.min(_dt or 0, 1/30)

  local player_id = self.player_id
  local st = Displayer.Text.getTextBoxState(player_id, self.box_id)
  -- =====================================================
  -- Gate: do NOT draw/animate the menu until textbox is fully open
  -- =====================================================
  if self.wait_textbox_open_idle then
    -- Textbox is still playing its OPEN animation
    if st == "opening" then
      return
    end

    -- Textbox is now visually open (printing or waiting)
    self.wait_textbox_open_idle = false

    -- First time we ever draw the menu bg -> plays OPEN (via menu_bg_needs_open)
    self:render_menu_window()
  end



  -- =====================================================
  -- CLOSE animation timing (must run even after OPEN is done)
  -- =====================================================
  if self.menu_bg_close_playing then
    local dt = dt
    self.menu_bg_close_t = self.menu_bg_close_t + dt

    if self.menu_bg_close_t >= (self.menu_bg_close_total or 0.60) then
      self.menu_bg_close_playing = false

      -- Now actually close/cleanup
      PromptVertical._finalize_close(player_id, self.pending_close_reason, {
        keep_textbox = self.pending_close_keep_textbox
      })
      return
    end

    -- While closing, swallow inputs and do nothing else
    Input.consume(player_id)
    return
  end

  -- =====================================================
  -- OPEN animation timing
  -- =====================================================
  if self.menu_bg_open_playing then
    local dt = dt
    self.menu_bg_open_t = self.menu_bg_open_t + dt

    if self.menu_bg_open_t >= (self.menu_bg_open_total or 0.58) then
      self.menu_bg_open_playing = false

      local L = self.layout
      local x, y = self:menu_origin()
      x = x + (MENU_W * L.scale)
      y = y + (MENU_H * L.scale)

        draw_sprite(
          self, self.spr.MENU_BG,
          self.draw.menu_bg,
          x, y,
          L.z,
          L.scale,
          "OPEN_IDLE"
        )

        draw_menu_frame_overlay(
          self,
          self.draw.menu_frame,
          x, y,
          L.z + 1,
          L.scale,
          "OPEN_IDLE",
          L.frame
        )


      -- Now that the menu window is fully open, draw text + scrollbar/cursor once
      if self.menu_contents_pending then
        self.menu_contents_pending = false
        self:update_scroll_for_selection(true)
        self:start_text_intro()
        -- Start shop item "unfold" (NEW)
            if self.layout.shop_item_intro_enabled then
              self._shop_item_intro_active = true
              self._shop_item_intro_t = 0
            end
        self:render_menu_contents(true)
      end
    end
  end

  -- =====================================================
  -- Shop item intro "unfold" timing (NEW)
  -- =====================================================
    if self._shop_item_intro_active then
      local dt = dt
      self._shop_item_intro_t = (self._shop_item_intro_t or 0) + dt

      local frames = tonumber(self.layout.shop_item_intro_frames) or 10
      local dur = frames / 60  -- frames-at-60Hz ? seconds

      if self._shop_item_intro_t >= dur then
        self._shop_item_intro_active = false
        self._shop_item_intro_t = dur
      end

      -- redraw every tick while animating
      self:render_menu_contents(true)
    end





  -- =====================================================
  -- Text intro animation timing (fade/slide/cascade)
  -- =====================================================
  if self._text_intro_active then
    local dt = dt * (self._text_intro_speed_mult or 1)

    self._text_intro_t = (self._text_intro_t or 0) + dt

    local dur = (tonumber(self.layout.text_intro_frames) or 20) / 60
    local stagger = (tonumber(self.layout.text_intro_stagger_frames) or 3) / 60
    local rows = tonumber(self.layout.visible_rows) or 5

    local end_t = dur + math.max(0, (rows - 1) * stagger)
    if self._text_intro_t >= end_t then
      self._text_intro_active = false
      self._text_intro_speed_mult = 1
      self._text_intro_boosted = false
    end

    -- Force redraw while intro is running so x/opacity updates each tick
    self:render_menu_contents(true)
  end



  -- While printing: allow hold-confirm to fast-forward textbox; menu locked
    if st == "printing" then
      Input.pop(player_id, "up")
      Input.pop(player_id, "down")
      Input.pop(player_id, "cancel")

        -- PRE-DISABLE indicator when printing the FINAL page so it never "pops" on wait.
        -- IMPORTANT: only do this during the initial question text phase.
        if self.state == STATE.TEXT then
          local bd = Displayer.Text.getTextBoxData(player_id, self.box_id)
          local page_count = (bd and bd.pages) and #bd.pages or nil
          local cur_page = bd and bd.current_page or nil
          local is_last_page = (page_count and cur_page) and (cur_page >= page_count) or false
          if is_last_page then
            set_textbox_indicator_enabled(self.player_id, self.box_id, false)
          end
        end


      if Input.is_down(player_id, "confirm") then
        Input.pop(player_id, "confirm")

        -- If menu intro is still animating, speed it up for the remainder of this intro
        if self._text_intro_active and not self._text_intro_boosted then
          self._text_intro_boosted = true
          self._text_intro_speed_mult = 5
        end

        Displayer.Text.advance_text_box(player_id, self.box_id)
      end
      return
    end


    -- While waiting: advance pages.
    -- SPECIAL CASE: if we're on the final page, auto-advance once to clear the indicator,
    -- then unlock menu immediately (keeps textbox + anchor alive).
    if (st == "waiting") and (self.state == STATE.TEXT) then
      -- lock menu input while textbox is mid-script
      Input.pop(player_id, "up")
      Input.pop(player_id, "down")
      Input.pop(player_id, "cancel")

      local bd = Displayer.Text.getTextBoxData(player_id, self.box_id)
      local page_count = (bd and bd.pages) and #bd.pages or nil
      local cur_page = bd and bd.current_page or nil
      local is_last_page = (page_count and cur_page) and (cur_page >= page_count) or false

      if is_last_page then
        -- We are done printing the question. Keep the textbox OPEN,
        -- hide the indicator, and pass control to the menu.
        set_textbox_indicator_enabled(self.player_id, self.box_id, false)
        self:become_ready()
        return
      end

      -- not last page: confirm advances normally
      if Input.pop(player_id, "confirm") then
        Displayer.Text.advance_text_box(player_id, self.box_id)
        Input.consume(player_id)
        Input.require_release(player_id, { "confirm" })
        return
      end

      return
    end


  -- MENU INPUT
  if self.state ~= STATE.MENU then
    -- swallow anything if not in MENU
    Input.pop(player_id, "up")
    Input.pop(player_id, "down")
    Input.pop(player_id, "confirm")
    Input.pop(player_id, "cancel")
    return
  end

  -- Goal_1_5: when locked, the menu remains visible but MUST NOT accept MENU input.
    -- IMPORTANT: do NOT swallow confirm/cancel here, or sub-prompts / dialogue can never be confirmed.
    if self.locked then
      Input.pop(player_id, "up")
      Input.pop(player_id, "down")
      Input.pop(player_id, "left")
      Input.pop(player_id, "right")
      return
    end



  local total = #self.options
  self:update_cursor_bob(dt)

    if Input.pop(player_id, "up") then
      local prev = self.selection_index

      if self.selection_index <= 1 then
        self.selection_index = total
      else
        self.selection_index = self.selection_index - 1
      end
          if self.selection_index ~= prev then
            self:restart_shop_item_intro()
            local sc_changed = self:update_scroll_for_selection(false)
            play_cursor_move_sfx(player_id)
            -- Let the intro timer drive redraw; only force when scrolling window changed
            self:render_menu_contents(sc_changed)
          end
      return

    end

    if Input.pop(player_id, "down") then
      local prev = self.selection_index

      if self.selection_index >= total then
        self.selection_index = 1
      else
        self.selection_index = self.selection_index + 1
      end
        if self.selection_index ~= prev then
          self:restart_shop_item_intro()
          local sc_changed = self:update_scroll_for_selection(false)
          play_cursor_move_sfx(player_id)
          self:render_menu_contents(sc_changed)
        end
      return

    end


  if Input.pop(player_id, "confirm") then
    self:select_current()
    return
  end

  if Input.pop(player_id, "cancel") then
    self:do_cancel()
    return
  end
end

--========================
-- Public API
--========================
function PromptVertical.menu(player_id, opts)
  ensure_listener()
  ensure_tick()

  if PromptVertical.instances[player_id] then
    PromptVertical.close(player_id, "replace")
  end

  set_input_locked(player_id, true)

  -- swallow interaction press so we don’t insta-confirm/select
  Input.consume(player_id)

  local inst = PromptMenuInstance:new(player_id, opts or {})
  PromptVertical.instances[player_id] = inst
  return inst.box_id
end

function PromptVertical._finalize_close(player_id, _reason, opts)
  local inst = PromptVertical.instances[player_id]
  if not inst then return end

  opts = opts or {}
  local keep = (opts.keep_textbox == true)

  -- Erase remaining sprites (menu bg last)
  erase_sprite(player_id, inst.draw.menu_bg)
  erase_sprite(player_id, inst.draw.menu_frame)
  erase_sprite(player_id, inst.draw.hilite)
  erase_sprite(player_id, inst.draw.cursor)
  erase_sprite(player_id, inst.draw.scroll)
  erase_sprite(player_id, inst.draw.shop_item)

  -- Erase menu text
  inst:clear_menu_text()
  FontSystem:eraseTextDisplay(player_id, inst.draw.monies)
  FontSystem:eraseTextDisplay(player_id, inst.draw.monies_amount)


  if not keep then
    Displayer.Text.closeTextBox(player_id, inst.box_id)
  else
    -- Goal_1_5: indicator should NOT appear when the menu closes but textbox stays
    set_textbox_indicator_enabled(player_id, inst.box_id, false)
    Input.consume(player_id)
    Input.clear_require_release(player_id, { "confirm", "cancel" })
    Input.swallow(player_id, 0.10)
  end


  set_input_locked(player_id, false)

  if not keep then
    Input.consume(player_id)
    if Input.is_down(player_id, "confirm") or Input.is_down(player_id, "cancel") then
      Input.require_release(player_id, { "confirm", "cancel" })
    end
  end

  -- Run deferred callback (selection/cancel) after visuals are done
  if inst._post_close_cb then
    local cb = inst._post_close_cb
    inst._post_close_cb = nil
    pcall(cb)
  end

  PromptVertical.instances[player_id] = nil
end


function PromptVertical.close(player_id, _reason, opts)
  local inst = PromptVertical.instances[player_id]
  if not inst then return end

  opts = opts or {}
  local keep = (opts.keep_textbox == true)

  -- Start animated close instead of instant erase
  inst:start_close(_reason or "close", keep)
end


return PromptVertical
