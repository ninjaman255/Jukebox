--[[
* ---------------------------------------------------------- *
                 Jukebox v2.1 by D3str0y3d
	 https://github.com/ninjaman255/Server_12_22_2021_Jukebox
* ---------------------------------------------------------- *
]] --

print("[jukebox] Loading the groove!")

-- defaults
local Songs = {}
local color =
{
  r = 0,
  g = 0,
  b = 0
}

--Shorthand for async
function async(p)
  local co = coroutine.create(p)
  return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end

--purpose: splits a string based on a delimiter
local function splitter(inputstr, sep)
  if sep == nil then
    sep = '%s'
  else
    sep = sep:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
  end

  local t = {}
  for str in (inputstr .. sep):gmatch("(.-)" .. sep) do
    table.insert(t, str)
  end
  return t
end

--purpose: checks if server is running on windows or unix and adjusts populating the song list accordingly
local function get_os()
  if package.config:sub(1, 1) == "\\" then
    return "windows"
  else
    return "unix"
  end
end

local function listFiles(directory)
  local os_type = get_os()
  print("[jukebox] Populating song list from " .. os_type .. " system.")
  -- make a table to collect the file names
  local songTable = {}
  -- handles running the cmd
  local cmd = 'ls "' .. directory .. '"'
  if os_type == "windows" then
    local cmd = 'dir "' .. directory .. '" /b'
  end

  local handle = io.popen(cmd)

  if handle then
    for file in handle:lines() do
      table.insert(songTable, file)
    end
    handle:close()
  else
    print("Error listing files in directory.")
  end
  return songTable
end

-- grabbing initial song names from dir "server/assets/jukebox"
local songList = listFiles("./assets/jukebox")

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
      response = await(Async.question_player(event.player_id,
        ("Do you wish to change the song to " .. Songs[tonumber(event.post_id)].title .. "?")))
      if (response == 1) then
        local area_id = Net.get_player_area(event.player_id)
        Net.set_song(area_id, "/server/assets/jukebox/" .. Songs[tonumber(event.post_id)].title .. ".ogg")
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
    color_parts = splitter(object.custom_properties.Color, ",")
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
