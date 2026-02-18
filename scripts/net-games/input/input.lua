-- scripts/net-games/input/input.lua
--
-- Net Games Input Helper (sticky-state)
-- - Listens to Net:on("virtual_input") once
-- - Tracks per-player edge presses (confirm/cancel/dpad)
-- - IMPORTANT: missing keys in event.events do NOT imply released
--
-- Input states (per docs):
--   0 = Pressed
--   1 = Held
--   2 = Released
-- Some forks also emit:
--   4 = Scroll (repeat pulse)
--
-- Supports BOTH event.events formats:
--   A) array: { {name="Confirm", state=0}, {name="UI Left", state=1} }
--   B) map:   { ["Confirm"]=0, ["UI Left"]=1 }
--
-- Key behavior:
-- - confirm/cancel: POP once per down. (Never repeat on hold. Scroll ignored.)
-- - directions: POP on down + repeat on Scroll pulses while held.
--
-- Also supports:
-- - swallow(player_id, seconds): ignore input briefly + clear edges
-- - require_release(player_id, {"confirm"}): ignore edges until a release is observed

local Input = {}

local LISTENER_ATTACHED = false
local st = {}

--=====================================================
-- Debug toggles
--=====================================================
Input.DEBUG = false                -- master debug
Input.DEBUG_THROTTLE = 0          -- seconds; 0 = no throttle
Input.DEBUG_CONFIRM_ONLY = false  -- if true, prints only when confirm group appears in packet
Input.DEBUG_DUMP_PACKET = false    -- if true, prints interpreted map each packet (noisy)

local function now() return os.clock() end

-- How long we wait without seeing confirm/cancel before treating it as "up".
-- Missing keys in event.events do NOT imply released.
local NON_DIR_UP_TIMEOUT = 0.06

local function refresh_non_dir_timeout(s)
  local t = now()

  -- Only for confirm/cancel (non-dir)
  for _, k in ipairs({ "confirm", "cancel" }) do
    if s.down[k] and t >= (s.non_dir_down_until[k] or 0) then
      s.down[k] = false
      s.non_dir_armed[k] = true
    end
  end
end


local function ensure(player_id)
  if not st[player_id] then
    st[player_id] = {
      edge = {}, -- buffered edges until consumed/popped
      swallow_until = 0,
      require_release = {},

      -- non-dir latch: we synthesize an "up" if we stop seeing the key for a bit
      non_dir_down_until = { confirm = 0, cancel = 0 },
      non_dir_armed      = { confirm = true, cancel = true },

      down = {
        confirm=false, cancel=false,
        left=false, right=false,
        up=false, down=false,
      },

      last_print = 0,
      seen_states = {},
      seen_names = {},

      last_shape = "(none)",
      last_map = {},
      last_raw_count = 0,
    }
  end
  return st[player_id]
end

local function state_word(s)
  if s == 1 then return "Pressed" end
  if s == 2 then return "Held" end
  if s == 3 then return "Released" end
  if s == 4 then return "Scroll" end
  return "INVALID"
end

local function normalize_state(s)
  if s == 1 or s == 2 or s == 3 or s == 4 then return s end
  if type(s) == "string" then
    local t = s:lower()
    if t == "pressed" then return 1 end
    if t == "held" then return 2 end
    if t == "released" then return 3 end
    if t == "scroll" then return 4 end
  end
  return nil
end

local function is_pressed(s)  return s == 0 end
local function is_held(s)     return s == 1 end
local function is_released(s) return s == 2 end
local function is_scroll(s)   return s == 4 end

local function is_dir_key(k)
  return k == "left" or k == "right" or k == "up" or k == "down"
end

-- Default bindings: keep confirm/cancel *pure* so Scroll-y gameplay actions
-- can't masquerade as UI confirm/cancel.
local DEFAULT_BINDINGS = {
  confirm = { "Confirm", "A", "OK", "Accept" },
  cancel  = { "Cancel", "Back", "B" },

  left    = { "UI Left", "Move Left", "Left" },
  right   = { "UI Right", "Move Right", "Right" },
  up      = { "UI Up", "Move Up", "Up" },
  down    = { "UI Down", "Move Down", "Down" },
}

-- Detect payload shape and build map of ONLY events present this packet (name -> normalized state)
local function build_event_map(events)
  local map = {}
  if events == nil then
    return map, "nil", 0
  end

  -- Shape A: array of objects
  if type(events) == "table" and type(events[1]) == "table" and events[1].name ~= nil then
    local count = 0
    for _, e in ipairs(events) do
      count = count + 1
      local ns = normalize_state(e.state)
      if e.name ~= nil and ns ~= nil then
        map[e.name] = ns
      end
    end
    return map, "array", count
  end

  -- Shape B: dictionary name->state
  if type(events) == "table" then
    local count = 0
    for name, state in pairs(events) do
      count = count + 1
      local ns = normalize_state(state)
      if name ~= nil and ns ~= nil then
        map[name] = ns
      end
    end
    return map, "map", count
  end

  return map, type(events), 0
end

-- For a binding group, compute:
--   down_change: true/false/nil (nil = no change this packet)
--   saw_pressed/saw_held/saw_scroll
-- promote_scroll_to_held: ONLY true for directional groups
local function resolve_group(map, names, promote_scroll_to_held)
  local saw_pressed  = false
  local saw_held     = false
  local saw_released = false
  local saw_scroll   = false

  for _, n in ipairs(names or {}) do
    local s = map[n]
    if s ~= nil then
      if is_pressed(s)  then saw_pressed  = true end
      if is_held(s)     then saw_held     = true end
      if is_released(s) then saw_released = true end
      if is_scroll(s) then
        saw_scroll = true
        if promote_scroll_to_held then
          saw_held = true
        end
      end
    end
  end

  if saw_pressed or saw_held then
    return true, saw_pressed, saw_held, saw_scroll
  end

  if saw_released then
    return false, false, false, saw_scroll
  end

  return nil, false, false, saw_scroll
end

local function dbg_ok_to_print(s)
  if not Input.DEBUG then return false end
  if not Input.DEBUG_THROTTLE or Input.DEBUG_THROTTLE <= 0 then return true end
  local t = now()
  if (t - (s.last_print or 0)) < Input.DEBUG_THROTTLE then
    return false
  end
  s.last_print = t
  return true
end

local function map_to_string(map)
  local parts = {}
  for name, stv in pairs(map or {}) do
    local w = state_word(stv)
    table.insert(parts, tostring(name) .. "=" .. w)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function any_binding_present(map, binding_list)
  for _, n in ipairs(binding_list or {}) do
    if map[n] ~= nil then return true end
  end
  return false
end

--=====================================================
-- Public API
--=====================================================

function Input.consume(player_id)
  local s = ensure(player_id)
  s.edge = {}
end

function Input.pop(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  if s.edge[key] then
    s.edge[key] = nil
    return true
  end
  return false
end


function Input.pressed(player_id, key)
  local s = ensure(player_id)
  return s.edge[key] == true
end

function Input.is_down(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  return s.down[key] == true
end


function Input.swallow(player_id, seconds)
  local s = ensure(player_id)
  s.swallow_until = math.max(s.swallow_until or 0, now() + (seconds or 0))
  s.edge = {}
end

function Input.require_release(player_id, keys)
  local s = ensure(player_id)
  for _, k in ipairs(keys or {}) do
    s.require_release[k] = true
  end
end

function Input.clear_require_release(player_id, keys)
  local s = ensure(player_id)
  for _, k in ipairs(keys or {}) do
    s.require_release[k] = nil
    s.non_dir_armed[k] = true
    if s.non_dir_down_until and s.non_dir_down_until[k] ~= nil then
      s.non_dir_down_until[k] = 0
    end
    if s.down and s.down[k] ~= nil then
      s.down[k] = false
    end
  end
end


function Input.debug_dump_last_packet(player_id)
  local s = ensure(player_id)
  print("[InputDBG] player=" .. tostring(player_id) ..
    " last_shape=" .. tostring(s.last_shape) ..
    " raw_count=" .. tostring(s.last_raw_count) ..
    " map=" .. map_to_string(s.last_map))
  local function b(x) return x and "true" or "false" end
  print("[InputDBG] down: confirm=" .. b(s.down.confirm) ..
    " cancel=" .. b(s.down.cancel) ..
    " left=" .. b(s.down.left) ..
    " right=" .. b(s.down.right) ..
    " up=" .. b(s.down.up) ..
    " down=" .. b(s.down.down))
  print("[InputDBG] edge: confirm=" .. b(s.edge.confirm) ..
    " cancel=" .. b(s.edge.cancel) ..
    " left=" .. b(s.edge.left) ..
    " right=" .. b(s.edge.right) ..
    " up=" .. b(s.edge.up) ..
    " down=" .. b(s.edge.down))
end

function Input.attach_virtual_input_listener(bindings)
  if LISTENER_ATTACHED then
    print("[Input] listener already attached")
    return
  end
  LISTENER_ATTACHED = true
  print("[Input] attaching Net:on('virtual_input') listener")

  bindings = bindings or DEFAULT_BINDINGS

  Net:on("virtual_input", function(event)
    local player_id = event.player_id
    local s = ensure(player_id)
    local t = now()

    -- swallow window: ignore packets completely
    if s.swallow_until and t < s.swallow_until then
      if Input.DEBUG and dbg_ok_to_print(s) then
        print("[InputDBG] SWALLOWED packet player=" .. tostring(player_id))
      end
      return
    end

    local map, shape, raw_count = build_event_map(event.events)
    s.last_shape = shape
    s.last_raw_count = raw_count
    s.last_map = map

    -- track seen states/names for discovery
    for name, stv in pairs(map) do
      s.seen_names[name] = true
      s.seen_states[stv] = true
    end

    -- Apply group logic
    local keys = { "confirm","cancel","left","right","up","down" }
    for _, k in ipairs(keys) do
      local down_change, saw_pressed, saw_held, saw_scroll =
        resolve_group(map, bindings[k], is_dir_key(k))

      --=====================================================
      -- NON-DIRECTION KEYS: POP once per down.
      -- IMPORTANT: IGNORE Scroll completely for confirm/cancel.
      -- Some clients never emit Pressed; they jump straight to Held.
      -- So: allow Held to create an edge ONLY if we were previously up.
      --=====================================================
      if not is_dir_key(k) then
        local saw_down_signal = saw_pressed or (saw_held and not s.down[k])

        if s.require_release[k] then
          if saw_down_signal then
            s.non_dir_down_until[k] = t + NON_DIR_UP_TIMEOUT
            s.down[k] = true
          elseif t >= (s.non_dir_down_until[k] or 0) then
            s.down[k] = false
            s.non_dir_armed[k] = true
            s.require_release[k] = nil
          end

        else
          if saw_down_signal then
            s.non_dir_down_until[k] = t + NON_DIR_UP_TIMEOUT

            if (not s.down[k]) and s.non_dir_armed[k] then
              s.edge[k] = true
              s.non_dir_armed[k] = false
            end

            s.down[k] = true

          elseif t >= (s.non_dir_down_until[k] or 0) then
            s.down[k] = false
            s.non_dir_armed[k] = true
          end
        end

      --=====================================================
      -- DIRECTIONS: sticky down state + repeat on Scroll pulses
      --=====================================================
      else
        if s.require_release[k] then
          if down_change == false then
            s.require_release[k] = nil
            s.down[k] = false
          else
            if down_change ~= nil then
              s.down[k] = down_change
            end
          end

        else
          if down_change ~= nil then
            local was = s.down[k]
            s.down[k] = down_change
            if down_change == true and not was then
              s.edge[k] = true
            end
          end

          -- repeat while held (Scroll pulses)
          if saw_scroll and s.down[k] then
            s.edge[k] = true
          end
        end
      end
    end

    if Input.DEBUG and dbg_ok_to_print(s) then
      local confirm_present = any_binding_present(map, bindings.confirm)
      if (not Input.DEBUG_CONFIRM_ONLY) or confirm_present then
        local function b(x) return x and "true" or "false" end
        print("[InputDBG] player=" .. tostring(player_id) ..
          " shape=" .. tostring(shape) ..
          " raw_count=" .. tostring(raw_count) ..
          " confirm_present=" .. tostring(confirm_present))

        print("[InputDBG] edges: confirm=" .. b(s.edge.confirm) ..
          " cancel=" .. b(s.edge.cancel) ..
          " left=" .. b(s.edge.left) ..
          " right=" .. b(s.edge.right) ..
          " up=" .. b(s.edge.up) ..
          " down=" .. b(s.edge.down))

        if Input.DEBUG_DUMP_PACKET then
          print("[InputDBG] packet_map=" .. map_to_string(map))
        end
      end
    end
  end)
end

return Input
