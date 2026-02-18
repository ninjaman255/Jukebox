-- scripts/net-games/npcs/npc_api.lua
-- Purpose: Remove NPC boilerplate (interaction wiring, busy guards, face-player, SFX helper).
-- This does NOT contain dialogue/menu content defaults.

local Direction = require("scripts/libs/direction")
require("scripts/net-games/dialogue/startup")

local Dialogue = require("scripts/net-games/dialogue/dialogue")
local TalkVertMenu = require("scripts/net-games/npcs/talk_vert_menu")

local M = {}

function M.play_sfx(player_id, path)
  if not path then return end
  Net.provide_asset_for_player(player_id, path)

  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, path) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(path) end)
  end
end

function M.face_player(bot_id, bot_pos, player_id)
  local player_pos = Net.get_player_position(player_id)
  Net.set_bot_direction(bot_id, Direction.from_points(bot_pos, player_pos))
end

-- Standard interaction wrapper:
-- - filters to this bot + confirm button
-- - prevents overlap via TalkVertMenu busy + Dialogue active
-- - optionally faces player
-- - calls your handler(player_id)
function M.bind_confirm_interaction(bot_id, bot_pos, handler, opts)
  opts = opts or {}
  local face = (opts.face ~= false)

  Net:on("actor_interaction", function(event)
    if event.actor_id ~= bot_id then return end
    if event.button ~= 0 then return end -- A/confirm only

    local player_id = event.player_id

    -- Global busy guard (prevents prompt/menu spam + close-window softlocks)
    if TalkVertMenu.is_busy(player_id) then return end
    if Dialogue.is_active(player_id) then return end

    if face then
      M.face_player(bot_id, bot_pos, player_id)
    end

    handler(player_id)
  end)
end

return M
