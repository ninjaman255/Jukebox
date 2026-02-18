-- scripts/net-games/input/input.lua
--
-- Net Games Input Helper (sticky-state)
-- - Listens to Net:on("virtual_input") once
-- - Tracks per-player edge presses (confirm/cancel/dpad)
-- - IMPORTANT: missing keys in event.events do NOT imply released
-- - Input states (per docs):
--     0 = Pressed
--     1 = Held
--     2 = Released
--
-- Supports BOTH event.events formats:
--   A) array: { {name="Confirm", state=0}, {name="UI Left", state=1} }
--   B) map:   { ["Confirm"]=0, ["UI Left"]=1 }
--
-- Extra features:
-- - swallow(player_id, seconds): ignore input for a short window + clear edges
-- - require_release(player_id, {"confirm"}): ignore confirm edges until a release event arrives

local Input = {}

local LISTENER_ATTACHED = false
local st = {}

--=====================================================
-- Debug toggles
--=====================================================
Input.DEBUG = false                 -- master debug
Input.DEBUG_THROTTLE = 0         -- seconds; set to 0 for no throttle
Input.DEBUG_CONFIRM_ONLY = false    -- if true, prints only when confirm group appears in packet
Input.DEBUG_DUMP_PACKET = false    -- if true, prints interpreted map each packet (can be noisy)

local function now() return os.clock() end

local function ensure(player_id)
  if not st[player_id] then
    st[player_id] = {
      edge = {}, -- buffered edges until consumed/popped
      swallow_until = 0,
      require_release = {},

      down = {
        confirm=false, cancel=false,
        left=false, right=false,
        up=false, down=false
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
  if s == 0 then return "Pressed" end
  if s == 1 then return "Held" end
  if s == 2 then return "Released" end
  return "INVALID"
end

local function normalize_state(s)
  if s == 0 or s == 1 or s == 2 then return s end
  -- allow string states just in case (some forks do this)
  if type(s) == "string" then
    local t = s:lower()
    if t == "pressed" then return 0 end
    if t == "held" then return 1 end
    if t == "released" then return 2 end
  end
  return nil
end

local function is_pressed(s)  return s == 0 end
local function is_held(s)     return s == 1 end
local function is_released(s) return s == 2 end

-- Default bindings: adjust after you discover real names with debug_dump_seen_names()
local DEFAULT_BINDINGS = {
  confirm = { "Confirm", "Interact", "Use Card", "A", "OK", "Accept" },
  cancel  = { "Cancel", "Back", "Run", "Cust Menu", "B" },

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
--   saw_pressed: true if any binding emitted "Pressed" this packet
--   saw_held:    true if any binding emitted "Held" this packet
--   saw_scroll:  true if any binding emitted "Scroll" this packet
local function resolve_group(map, names)
  local saw_pressed = false
  local saw_held = false
  local saw_released = false
  local saw_scroll = false

  for _, n in ipairs(names or {}) do
    local s = map[n]
    if s ~= nil then
      if is_pressed(s) then saw_pressed = true end
      if is_held(s) then saw_held = true end
      if is_released(s) then saw_released = true end
      if is_scroll(s) then saw_scroll = true end
    end
  end

  -- Any down signal this packet means "down" (Pressed OR Held)
  if saw_pressed or saw_held then
    return true, saw_pressed, saw_held, saw_scroll
  end

  if saw_released then
    return false, false, false, saw_scroll
  end

  -- nil => no change (sticky)
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

-- Helpful: discover what names the client is actually sending
function Input.debug_dump_seen_names(player_id)
  local s = ensure(player_id)
  local names = {}
  for n, _ in pairs(s.seen_names) do table.insert(names, n) end
  table.sort(names)
  print("[InputDBG] player=" .. tostring(player_id) .. " seen_names(" .. tostring(#names) .. "): " .. table.concat(names, ", "))
end

function Input.debug_dump_seen_states(player_id)
  local s = ensure(player_id)
  local states = {}
  for stv, _ in pairs(s.seen_states) do table.insert(states, tostring(stv)) end
  table.sort(states)
  print("[InputDBG] player=" .. tostring(player_id) .. " seen_states: " .. table.concat(states, ", "))
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

    local events = event.events

    -- swallow window: ignore packets completely
    if s.swallow_until and t < s.swallow_until then
      if Input.DEBUG and dbg_ok_to_print(s) then
        print("[InputDBG] SWALLOWED packet player=" .. tostring(player_id))
      end
      return
    end

    local map, shape, raw_count = build_event_map(events)
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
      local down_change, saw_pressed = resolve_group(map, bindings[k])

      if s.require_release[k] then
        -- Clear lock only when we SEE a release for that group
        if down_change == false then
          s.require_release[k] = nil
          s.down[k] = false
        else
          -- track down state but never emit edges
          if down_change ~= nil then
            s.down[k] = down_change
          end
        end
      else
        if down_change ~= nil then
          local was = s.down[k]
          s.down[k] = down_change

            -- Edge on FIRST transition up->down (Pressed OR Held)
            -- This prevents softlocks when the first Pressed gets swallowed or never arrives.
            if down_change == true and not was then
              s.edge[k] = true
            end
        end
        -- nil => keep previous (sticky)
      end
    end

    -- Debug printing
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