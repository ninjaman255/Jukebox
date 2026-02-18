--=====================================================
-- prog_basic_freedraw.lua
-- Tiled-spawned NPC that draws ALL available fonts on screen
-- WITHOUT using Dialogue / textbox pipeline.
--=====================================================

local Direction  = require("scripts/libs/direction")
local NetHelpers = require("scripts/net-games/helpers/net-helpers")
NetHelpers.patch_net()

local games = require("scripts/net-games/framework")
assert(type(games) == "table", "[prog_basic_freedraw] framework failed to load (got " .. tostring(type(games)) .. ")")

local DEBUG = true
local function dbg(msg)
  if DEBUG then print("[prog_basic_freedraw] " .. msg) end
end

--=====================================================
-- Area / placement (must match your TMX object)
--=====================================================
local area_id  = "default"
local obj_name = "ProgBasicFreeDraw" -- Tiled object name

local bot_pos = Net.get_object_by_name(area_id, obj_name)
assert(bot_pos, "[prog_basic_freedraw] Missing Tiled object named '" .. obj_name .. "' in area: " .. tostring(area_id))

local bot_id = Net.create_bot({
  name = "FreeDraw Prog",
  area_id = area_id,
  texture_path = "/server/assets/ow/prog/prog_ow.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",
  x = bot_pos.x,
  y = bot_pos.y,
  z = bot_pos.z or 0,
  direction = Direction.Down,
  solid = true,
})

dbg("LOADED bot_id=" .. tostring(bot_id))

--=====================================================
-- Font list (add/remove here as your system grows)
--=====================================================
local FONT_TESTS = {
  { font = "THICK",       label = "THICK",       sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "THICK_BLACK", label = "THICK_BLACK", sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "BATTLE",      label = "BATTLE",      sample = "<PROG_EXE> ABC 0123 !?" },
  { font = "THIN",        label = "THIN",        sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "TINY",        label = "TINY",        sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "WIDE",        label = "WIDE",        sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "GRADIENT",    label = "GRADIENT",    sample = "ABC abc 0123 !?.,:;()[]+-*/" },
  { font = "COMPRESSED",  label = "COMPRESSED",  sample = "ABC abc 0123 !?.,:;()[]+-*/" },
}

--=====================================================
-- Per-player toggle
--=====================================================
local active = {}

local function display_id_for(font_name)
  return "freedraw_font_" .. tostring(font_name)
end

local function show(player_id)
  -- Safety: ensure THICK_BLACK texture is present (even if framework preload was missed)
  pcall(function()
    Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_dark_compressed.png")
  end)

  local x = 12
  local y = 10
  local z = 100
  local line_step = 16

  for i, t in ipairs(FONT_TESTS) do
    local text = string.format("%s: %s", t.label, t.sample)
    games.draw_text(display_id_for(t.font), player_id, text, x, y + ((i - 1) * line_step), z, t.font)
  end
end

local function hide(player_id)
  for _, t in ipairs(FONT_TESTS) do
    games.remove_text(display_id_for(t.font), player_id)
  end
end

--=====================================================
-- Interaction handler
--=====================================================
Net:on("actor_interaction", function(event)
  if event.actor_id ~= bot_id then return end
  if event.button ~= 0 then return end

  local player_id = event.player_id

  -- Face the player
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))

  if active[player_id] then
    active[player_id] = false
    hide(player_id)
    return
  end

  active[player_id] = true
  show(player_id)
end)

Net:on("player_disconnect", function(event)
  active[event.player_id] = nil
end)
