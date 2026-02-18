--=====================================================
-- scripts/net-games/helpers/net-helpers.lua
-- EZLIBS compatibility helpers for net-games
--
-- Adds:
--   Net:create_timer(seconds, callback) -> handle
--   handle:cancel()
--
-- Why:
--   EZLIBS ships timer helpers; base net-games typically doesn't.
--   We implement it in the net-games style: driven by Net:on("tick").
--=====================================================

local NetHelpers = {}
NetHelpers.__index = NetHelpers

local ATTACHED = false
local NEXT_ID = 1
local TIMERS = {} -- id -> { remaining, cb, cancelled }

local function attach_tick_listener()
  if ATTACHED then return end
  ATTACHED = true

  Net:on("tick", function(event)
    local dt = event and event.delta_time or 0
    if not dt or dt <= 0 then return end

    for id, t in pairs(TIMERS) do
      if t.cancelled then
        TIMERS[id] = nil
      else
        t.remaining = (t.remaining or 0) - dt
        if t.remaining <= 0 then
          -- remove BEFORE callback (so callback can safely create more timers)
          TIMERS[id] = nil

          local ok, err = pcall(t.cb)
          if not ok then
            print("[net-helpers] create_timer callback error: " .. tostring(err))
          end
        end
      end
    end
  end)
end

-- Public: Net:create_timer(seconds, callback)
function NetHelpers.create_timer(seconds, callback)
  attach_tick_listener()

  seconds = tonumber(seconds) or 0
  if type(callback) ~= "function" then
    error("[net-helpers] Net:create_timer(seconds, callback) requires a function callback")
  end

  local id = NEXT_ID
  NEXT_ID = NEXT_ID + 1

  TIMERS[id] = {
    remaining = math.max(0, seconds),
    cb = callback,
    cancelled = false,
  }

  -- Handle object (EZLIBS-ish ergonomics)
  local handle = {}
  function handle:cancel()
    if TIMERS[id] then
      TIMERS[id].cancelled = true
    end
  end

  return handle
end

--=====================================================
-- EZLIBS-ish safe_require: load a module without hard-crashing the whole server boot.
-- Returns: module_or_nil, err_or_nil
--=====================================================
function NetHelpers.safe_require(path)
  local ok, mod_or_err = pcall(require, path)
  if not ok then
    print("[net-helpers] safe_require failed: " .. tostring(path))
    print("[net-helpers]   " .. tostring(mod_or_err))
    return nil, mod_or_err
  end
  return mod_or_err, nil
end


-- Patch Net only if missing, so you don't stomp something else later.
function NetHelpers.patch_net()
  if not Net then
    print("[net-helpers] Net is nil; cannot patch")
    return false
  end

  if Net.create_timer == nil then
    Net.create_timer = NetHelpers.create_timer
  end

  return true
end

return NetHelpers
