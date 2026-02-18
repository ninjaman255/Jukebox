--[[
* ---------------------------------------------------------- *
                 Jukebox v2.1 by D3str0y3d
	 https://github.com/ninjaman255/Server_12_22_2021_Jukebox
* ---------------------------------------------------------- *
]]                                             --

local Utils = require("scripts/jukebox/utils") -- load the utility module
local Paths = require("scripts/jukebox/constants/paths")
local NetGames = require("scripts/net-games/framework")
local Emitter = require("scripts/tests/event-emitter")

local Jukebox = Emitter.new()
--Shorthand for async
function async(p)
  local co = coroutine.create(p)
  return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end

-- ===================================================================--
print("[Jukebox] Loading the groove!")
-- ===================================================================--
-- defaults
local Songs = {}

local SongRecordsDir
local SongList
local AllMapsWithTypedObjects
local JukeboxObjectCache

local BaseGatherPath = "./assets/jukebox/tracks/"
local UIAssetPaths = Paths.UIAssetPaths

local function gatherDirectoryContents(path)
  local dirContents = Utils.listFilesDetailed(path)
  -- print(dirContents)
  return dirContents
end

SongRecordsDir = gatherDirectoryContents(BaseGatherPath)

local function gatherAllMusic()
  local song_list = {}

  if SongRecordsDir == nil then
    SongRecordsDir = {}
  end
  for i = 1, #SongRecordsDir do
    local Dir = SongRecordsDir[i]
    local DirSongList = Utils.listFiles(BaseGatherPath .. Dir["name"] .. "/")
    song_list[Dir.name] = DirSongList
  end
  return song_list
end

SongList = gatherAllMusic()

local function gatherAllMapsAndObjects()
  local area_names = Net.list_areas()
  local maps_with_typed_objects = {}
  for i = 1, #area_names do
    local area_id = area_names[i]
    local objects = Net.list_objects(area_id)
    if maps_with_typed_objects[area_id] == nil then
      maps_with_typed_objects[area_id] = {}
    end
    for j = 1, #objects do
      local map = maps_with_typed_objects[area_id]
      local obj = Net.get_object_by_id(area_id, objects[j])
      local type = ""

      if obj.type ~= "" or obj.class ~= "" then
        if obj.type ~= "" then
          type = obj.type
        elseif obj.class ~= "" then
          type = obj.class
        end
      end

      if type ~= "" then
        if map[type] == nil then
          map[type] = {}
        end

        map[type][#map[type] + 1] = obj
      end
    end
  end
  -- print(maps_with_typed_objects)
  return maps_with_typed_objects
end

AllMapsWithTypedObjects = gatherAllMapsAndObjects()

local function gatherAllJukeboxes(maps)
  local cache = {}
  for name, value in pairs(maps) do
    if cache[name] == nil then
      cache[name] = {}
    end
    for type, objects in pairs(value) do
      for i = 1, #objects do
        if objects[i].type == "Jukebox" or objects[i].class == "Jukebox" then
          table.insert(cache[name], objects[i])
        end
      end
    end
  end
  print(cache)
  return cache
end

JukeboxObjectCache = gatherAllJukeboxes(AllMapsWithTypedObjects)

Net:on("player_join", function(event)
  local player_id = event.player_id
  print(SongList)
  for name, value in pairs(SongList) do
    print(name)
    print(value)
    for area_id, jukeboxes in pairs(JukeboxObjectCache) do
      print(area_id)
      print(jukeboxes)
      for i = 1, #value do
        Net.provide_asset(area_id, "/server/assets/jukebox/tracks/" .. name .. "/" .. value[i])
        print("provided asset for player for the area: " ..
          area_id .. ", the asset provided was found at: /server/assets/jukebox/tracks/" .. name .. "/" .. value[i])
      end
    end
  end
end)

-- grabbing initial song names from dir "server/assets/jukebox/tracks/"
local function compileTracks(SongList)
  local track_items = {}
  local index = 0
  for name, songs in pairs(SongList) do
    print(name)
    print(songs)
    for i = 1, #songs do
      print(songs[i])
      index = index + 1
      table.insert(track_items, { index = index, title = songs[i], record_label = name, author = name, duration = 0 })
    end
  end
  return track_items
end

local TrackItems = compileTracks(SongList)
print(TrackItems)


local function CreatePost(i, name, author)
  return {
    id = i,
    title = string.gsub(name, "%.ogg$", ""),
    author = author or "",
    read = true,
  }
end

-- Creates posts with file name
local function CompilePosts(inputTable, author, finalizedTable)
  for key, value in pairs(inputTable) do
    local postToAdd = CreatePost(key, value, author or "")
    table.insert(finalizedTable, postToAdd)
  end
  table.insert(finalizedTable, CreatePost(#finalizedTable + 1, "Close Jukebox", ""))
end

local function spawnJukeboxUI(player_id)
  NetGames.add_ui_element("Shade Screen", player_id, "/server/assets/jukebox/ui-sprites/shade-screen.png",
    "",
    "", 0,
    0,
    0, 2.0, 2.0, 240, 160)

  NetGames.add_ui_element("Jukebox Backdrop", player_id, "/server/assets/jukebox/ui-sprites/jukebox-backdrop.png",
    "",
    "", 0,
    1,
    0, 2.0, 2.0, 240, 160)

  NetGames.add_ui_element("Default Record", player_id,
    "/server/assets/jukebox/records/MMBN7_OST-alouetteEXE/base.png",
    "/server/assets/jukebox/ui-sprites/records/record.animation",
    "DEFAULT", 120,
    79,
    2, 2.0, 2.0, 240, 160)

  NetGames.rotate_ui_element("Default Record", player_id, 360, 0.5, "linear", function() end, true)

  NetGames.add_ui_element("Jukebox Frame", player_id, "/server/assets/jukebox/ui-sprites/jukebox-frame.png", "",
    "", 0,
    0,
    3, 2.0, 2.0, 240, 160)

  NetGames.add_ui_element("Cursor Left", player_id, "/server/assets/net-games/text_cursor.png",
    "/server/assets/net-games/text_cursor.animation", "CURSOR_LEFT", 63,
    102,
    4, 2.0, 2.0)

  -- NetGames.menu_cursor_ui_element("Cursor Left", player_id, 2, 1, 1, 0.5, "Left", "linear", "linear",
  --   function() end)

  NetGames.add_ui_element("Cursor Right", player_id, "/server/assets/net-games/text_cursor.png",
    "/server/assets/net-games/text_cursor.animation", "CURSOR_RIGHT", 186,
    102,
    4, 2.0, 2.0)

  -- NetGames.menu_cursor_ui_element("Cursor Right", player_id, 2, 1, 1, 1, "Right", "linear", "linear",
  --   function() end)
end

local function openJukeboxMenu(player_id, area_id, object_id)
  Jukebox:emit("Jukebox Open", { player_id = player_id, area_id = area_id, object_id = object_id })
end

local function removeJukeboxUI(player_id)
  print("TODO: IMPLEMENT")
end

local function requestJukeboxSong(player_id, index, should_close)
  print("TODO: IMPLEMENT")
end

Jukebox:on("Jukebox Open", function(event)
  Net.lock_player_input(event.player_id)
  Net.toggle_player_hud(event.player_id)
  spawnJukeboxUI(event.player_id)
end)

Jukebox:on("Jukebox Close", function(event)
  Net.unlock_player_input(event.player_id)
  Net.toggle_player_hud(event.player_id)
  removeJukeboxUI(event.player_id)
end)

Jukebox:on("Jukebox Request Song", function(event)
  print("TODO: IMPLEMENT")
  requestJukeboxSong(event.player_id, event.index, event.should_close)
end)


Net:on("object_interaction", function(event)
  local area_id = Net.get_player_area(event.player_id)
  local object = Net.get_object_by_id(area_id, event.object_id)

  --if we didn't interact with a jukebox then stop
  if object.class ~= "Jukebox" then
    return
  end

  if object.type ~= "Jukebox" then
    return
  end

  --if we didn't interact with A/Interact button then stop
  if event.button ~= 0 then
    return
  end

  openJukeboxMenu(event.player_id, area_id, event.object_id)
  -- if object.custom_properties.Color ~= nil then
  --   --print("[jukebox] Loaded custom color for jukebox")
  --   local color_parts = Utils.splitter(object.custom_properties.Color, ",")
  --   if color_parts[3] ~= nil then
  --     color.r = color_parts[1]
  --     color.g = color_parts[2]
  --     color.b = color_parts[3]
  --   else
  --     print("[jukebox] The color value of '" .. object.custom_properties.Color .. "' is malformed.")
  --   end
  -- end
  -- Net.open_board(event.player_id, "Songs", color, Songs)
end)
