--=====================================================
-- talk_presets.lua
-- Creator-facing presets for Dialogue NPCs (PROG-defaulted)
--=====================================================

local P = {}

-- ----------------------------
-- Nameplate presets
-- ----------------------------
P.nameplates = {
  prog = {
    -- text is filled in by talk.lua (BOT_NAME)
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

-- ----------------------------
-- Mugshot presets
-- ----------------------------
P.mugs = {
  prog = {
    enabled = true,
    texture_path = "/server/assets/ow/prog/prog_mug.png",
    anim_path = "/server/assets/ow/prog/prog_mug.animation",
    talk_anim_state = "TALK",
    idle_anim_state = "IDLE",
    reserve_w = 40,
    reserve_h = 40,
    offset_x = 6,
    offset_y = -46,
    gap_px = 6,
    sprite_id = 5300,
    z_bias = 50,
  },

    prog_red =       { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_red.png",       anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5301, z_bias=50 },
    prog_sapphire =      { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_sapphire.png",      anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5302, z_bias=50 },
    prog_emerald =     { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_emerald.png",     anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5303, z_bias=50 },
    prog_yellow =    { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_yellow.png",    anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5304, z_bias=50 },
    prog_orange =    { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_orange.png",    anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5305, z_bias=50 },
    prog_purple =    { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_purple.png",    anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5306, z_bias=50 },
    prog_pink =      { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_pink.png",      anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5307, z_bias=50 },
    prog_turquoise = { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_turquoise.png",      anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5308, z_bias=50 },
    prog_charcoal_grey =      { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_charcoal_grey.png",      anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5309, z_bias=50 },
    prog_lime =      { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_lime.png",      anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5310, z_bias=50 },
    prog_white =     { enabled=true, texture_path="/server/assets/ow/prog/prog_mug_white.png",     anim_path="/server/assets/ow/prog/prog_mug.animation", talk_anim_state="TALK", idle_anim_state="IDLE", reserve_w=40, reserve_h=40, offset_x=6, offset_y=-46, gap_px=6, sprite_id=5311, z_bias=50 },


}

-- ----------------------------
-- Textbox/backdrop presets
-- ----------------------------
P.boxes = {
  -- Canonical "PROG UI" defaults (matches prog_basic_nameplate + prog_prompt_dialogue)
  panel = {
    font = "THIN_BLACK",
    scale = 2.0,
    z = 100,

    -- YOU CONFIRMED THESE DEFAULTS
    typing_speed = 12,
    type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
    type_sfx_min_dt = 0.05,

    backdrop = {
      render_offset_x = 3,
      render_offset_y = 46,
      style = "textbox_panel",
      open_seconds = 0.20,
      close_seconds = 0.25, -- harmless default; can override per NPC if desired

      x = 1,
      y = 209,
      width = 478,
      height = 104,
      padding_x = 16,
      padding_y = 4,
      max_lines = 3,

      -- Leave enabled by default. Prompt.lua can toggle visibility when selector is on-screen.
      indicator = {
        enabled = true,
        width = 2,
        height = 2,
        offset_x = 24,
        offset_y = 26,
        indicator_timer = 0,
        indicator_base_x = nil,
        indicator_base_y = nil,
      },
    },
  },

  -- Legacy/simple black box (kept for convenience)
  black = {
    font = "THICK",
    scale = 2.0,
    z = 100,
    typing_speed = 30,
    type_sfx_path = "/server/assets/net-games/sfx/text.ogg",
    type_sfx_min_dt = 0.05,

    backdrop = {
      style = "black_box",
      x = 1,
      y = 209,
      width = 478,
      height = 104,
      padding_x = 16,
      padding_y = 16,
      max_lines = 3,

      indicator = {
        enabled = true,
        width = 2,
        height = 2,
        offset_x = 24,
        offset_y = 24,
        indicator_timer = 0,
        indicator_base_x = nil,
        indicator_base_y = nil,
      },
    },
  },
}

-- ----------------------------
-- Frame dye presets (only used with panel frame overlay style)
-- ----------------------------
P.frames = {
  lime          = { r = 80,  g = 255, b = 80,  a = 255, color_mode = 2 },
  red           = { r = 255, g = 80,  b = 80,  a = 255, color_mode = 2 },
  purple        = { r = 200, g = 80,  b = 255, a = 255, color_mode = 2 },

  turquoise     = { r = 80,  g = 230, b = 200, a = 255, color_mode = 2 },
  pink          = { r = 255, g = 120, b = 200, a = 255, color_mode = 2 },
  emerald       = { r = 60,  g = 200, b = 120, a = 255, color_mode = 2 },
  sapphire      = { r = 80,  g = 120, b = 255, a = 255, color_mode = 2 },
  yellow        = { r = 255, g = 220, b = 80,  a = 255, color_mode = 2 },
  orange        = { r = 255, g = 160, b = 80,  a = 255, color_mode = 2 },

  charcoal_grey = { r = 70,  g = 70,  b = 70,  a = 255, color_mode = 2 },
  white         = { r = 255, g = 255, b = 255, a = 255, color_mode = 2 },
}

-- ----------------------------
-- Vertical menu layout presets (PromptVertical)
-- ----------------------------
local function _shallow_copy(t)
  local o = {}
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end

P.vert_menus = {
  -- Matches ProgVertPromptPink build_layout_config()
  prog_prompt = {
    anchor = "textbox",
    offset_x = 1,
    offset_y = -199,

    width = 160,
    height = 64,

    visible_rows = 5,
    row_height = 14,
    padding_x = 48,
    padding_y = 4,

    -- menu text intro animation (Pink parity)
    text_intro_enabled = true,
    text_intro_frames = 18,
    text_intro_stagger_frames = 12,
    text_intro_slide_px = 6,

    scrollbar_x = 452,
    scrollbar_y = 12,
    scrollbar_h = 126,

    highlight_inset_x = 12,
    highlight_inset_y = 3,
    cursor_offset_x = 16,
    cursor_offset_y = 4,
  },
  -- Shop skin version: identical layout, plus MONIES label
  prog_prompt_shop = {
    anchor = "textbox",
    offset_x = 1,
    offset_y = -199,

    width = 160,
    height = 64,

    visible_rows = 5,
    row_height = 14,
    padding_x = 48,
    padding_y = 4,

    text_intro_enabled = true,
    text_intro_frames = 16,
    text_intro_stagger_frames = 8,
    text_intro_slide_px = 6,

    scrollbar_x = 452,
    scrollbar_y = 12,
    scrollbar_h = 126,

    highlight_inset_x = 12,
    highlight_inset_y = 3,
    cursor_offset_x = 16,
    cursor_offset_y = 4,

    -- NEW: Shop-only top-right label
    monies_label_enabled = true,
    monies_label_text = "MONIES",
    monies_label_font = "WIDE",
    monies_label_pad_x = 52,  -- px before scale
    monies_label_pad_y = 2,  -- px before scale
    monies_label_z_add = 4,

    -- NEW: Shop-only money amount (under MONIES)
    monies_amount_enabled  = true,
    monies_amount_text     = "0$",
    monies_amount_font     = "THIN",

    -- Positioned relative to the MONIES label (px before scale)
    monies_amount_offset_y = 5,
    monies_amount_offset_x = 32,

    -- NEW: Shop-only "Shop Item" image (top-left-ish)
    shop_item_enabled = true,
    shop_item_swap_exit = true,


    -- px before scale (same convention as monies pads)
    shop_item_pad_x = 164,
    shop_item_pad_y = 54,

    -- how far above the menu's base z to draw it
    shop_item_z_add = 4,

    shop_item_intro_enabled = true,
    shop_item_intro_frames = 8,

    -- IMPORTANT: set these to the real pixel size of the PNGs
    shop_item_w = 56,
    shop_item_h = 48,
    shop_exit_w = 56,
    shop_exit_h = 48,



  },
}

function P.get_vert_menu_layout(key)
  local base = P.vert_menus[key]
  if not base then return nil end
  return _shallow_copy(base)
end

-- ----------------------------
-- Vertical menu flow defaults (behavior, not content)
-- ----------------------------
P.vert_menu_flows = {
  prog_prompt = {
    keep_menu_open = true,
    lock_dim_alpha = 0.35,
    hide_cursor_when_locked = true,

    confirm = { enabled = true },
    post_select = { enabled = true },

    -- sfx is resolved via sfx_sets unless overridden per-call
    sfx = {},
  },
}

function P.get_vert_menu_flow(key)
  local base = P.vert_menu_flows[key]
  if not base then return nil end
  return _shallow_copy(base)
end


-- ----------------------------
-- SFX set presets (optional convenience)
-- ----------------------------
P.sfx_sets = {
  card_desc = {
    desc    = "/server/assets/net-games/sfx/card_desc.ogg",
    confirm = "/server/assets/net-games/sfx/card_confirm.ogg",
    close   = "/server/assets/net-games/sfx/card_desc_close.ogg",
  },
}

-- ----------------------------
-- High-level “preset packs” (what creators should pick)
-- ----------------------------
P.packs = {
  -- This is your “PROG baseline” for almost everything.
  prog = {
    box = "panel",
    mug = "prog",
    nameplate = "prog",

    -- Vertical menu defaults (non-content)
    vert_menu_layout = "prog_prompt",
    vert_menu_sfx_set = "card_desc",
    vert_menu_flow = "prog_prompt",

  },

  -- Same UI as prog (kept explicit so prompt can opt into it cleanly)
  prog_prompt = {
    box = "panel",
    mug = "prog",
    nameplate = "prog",
    -- Vertical menu defaults (non-content)
    vert_menu_layout = "prog_prompt",
    vert_menu_sfx_set = "card_desc",
    vert_menu_flow = "prog_prompt",

  },
}

return P
