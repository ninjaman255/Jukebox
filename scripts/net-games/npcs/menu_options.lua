-- scripts/net-games/npcs/menu_options.lua
-- Purpose: Build PromptVertical option tables without loops/math in each NPC file.

local M = {}

local function pad2(n)
  if n < 10 then return "0" .. tostring(n) end
  return tostring(n)
end

-- Build numbered options from a count.
-- Example:
--   MenuOptions.count(40, { prefix="Lime Option ", pad=2, start=1, exit_text="Exit" })
function M.count(count, cfg)
  cfg = cfg or {}
  local start = tonumber(cfg.start or 1) or 1
  local prefix = tostring(cfg.prefix or "Option ")
  local pad = tonumber(cfg.pad or 0) or 0

  local exit_text = tostring(cfg.exit_text or "Exit")
  local exit_id = cfg.exit_id or "exit"

  local t = {}
  for i = 0, (count - 1) do
    local n = start + i
    local label = tostring(n)
    if pad == 2 then label = pad2(n) end
    t[#t + 1] = { id = n, text = prefix .. label }
  end

  t[#t + 1] = { id = exit_id, text = exit_text }
  return t
end

-- Build from a list of strings. IDs become 1..N by default.
-- Example:
--   MenuOptions.list({ "Potion", "Antidote" }, { exit_text="Exit" })
function M.list(items, cfg)
  cfg = cfg or {}
  local exit_text = tostring(cfg.exit_text or "Exit")
  local exit_id = cfg.exit_id or "exit"

  local t = {}
  for i = 1, #items do
    t[#t + 1] = { id = i, text = tostring(items[i]) }
  end

  t[#t + 1] = { id = exit_id, text = exit_text }
  return t
end

return M
