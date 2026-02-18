--[[
* ---------------------------------------------------------- *
                 Jukebox v2.1 by D3str0y3d
	 https://github.com/ninjaman255/Server_12_22_2021_Jukebox
* ---------------------------------------------------------- *
]]                                             --

local utils = require("scripts/jukebox/utils") -- load the utility module

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

local BaseRecordPath = "assets/jukebox/records/"
local BaseTracksPath = "assets/jukebox/tracks/"

local RecordLabels = {
  AlouetteEXE = {
    texture_path = BaseRecordPath .. "alouetteEXE-record.png"
  }
}

-- defaults
local Songs = {}

local color =
{
  r = 0,
  g = 0,
  b = 0
}

-- grabbing initial song names from dir "server/assets/jukebox/tracks/"
local songList = utils.listFiles("./assets/jukebox/tracks/alouetteEXE-record/")

local function createTrackRecord(index, title, record_label, author, duration)
  return {
    index = index,
    title = title,
    record_label = record_label,
    author = author,
    duration = duration
  }
end

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

-- run the function
CompilePosts(songList, "", Songs)

Net:on("post_selection", function(event)
  return async(function()
    local numberfiedPostID = tonumber(event.post_id)
    if numberfiedPostID == #Songs then
      Net.close_bbs(event.player_id)
    elseif numberfiedPostID <= #Songs then
      local response = await(Async.question_player(event.player_id,
        ("Do you wish to change the song to " .. Songs[tonumber(event.post_id)].title .. "?")))
      if (response == 1) then
        local area_id = Net.get_player_area(event.player_id)
        Net.set_song(area_id,
          "/server/assets/jukebox/tracks/alouetteEXE-record/" .. Songs[tonumber(event.post_id)].title .. ".ogg")
        Net.close_bbs(event.player_id)
      end
    end
  end)
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

  if object.custom_properties.Color ~= nil then
    --print("[jukebox] Loaded custom color for jukebox")
    local color_parts = utils.splitter(object.custom_properties.Color, ",")
    if color_parts[3] ~= nil then
      color.r = color_parts[1]
      color.g = color_parts[2]
      color.b = color_parts[3]
    else
      print("[jukebox] The color value of '" .. object.custom_properties.Color .. "' is malformed.")
    end
  end
  Net.open_board(event.player_id, "Songs", color, Songs)
end)
