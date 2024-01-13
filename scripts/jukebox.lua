-- finalized table
local Songs = {}

--Color for BBS
local color = 
  {
  r = 0,
  g = 0,
  b = 0
  }

function listFiles(directory)
  -- make a table to collect the file names
  local songTable = {}    
  -- handles running the cmd
  local cmd = 'ls "' .. directory .. '"'
  local handle = io.popen(cmd)

  if handle then
      for file in handle:lines() do
          table.insert(songTable, file)
      end
      handle:close()
      print(tostring(songTable))
  else
      print("Error listing files in directory.")
  end
  return songTable
end

-- grabbing initial song names from dir "server/assets/jukebox"
local songList = listFiles("./assets/jukebox")

function CreatePost(i, name, author) 
  return {
  id = i,
  title = string.gsub(name, "%.ogg$", ""),
  author = author or "",
  read = true,
  }
end

-- Creates posts with file name 
function CompilePosts(inputTable, author, finalizedTable)
for key, value in pairs(inputTable) do
  print(key, value)
  local postToAdd = CreatePost(key, value, author or "")
  table.insert(finalizedTable, postToAdd)
end
print(finalizedTable)
table.insert(finalizedTable, CreatePost(#finalizedTable+1, "Exit", ""))
print(tostring(finalizedTable))
end

-- run the function
CompilePosts(songList, "", Songs)

function handle_post_selection(player_id,post_id) 
  local numberfiedPostID = tonumber(post_id) 
  if numberfiedPostID == #Songs then
    Async.question_player(player_id,("Do you wish to close the Jukebox?"))
    .and_then(function(response)
    if response == 0 then
      print("they said no")
    end
    if (response == 1) then
      Net.close_bbs(player_id)  
    end
  end)
  elseif numberfiedPostID <= #Songs then
    Async.question_player(player_id,("Do you wish to change the song to "..Songs[tonumber(post_id)].title.."?"))
    .and_then(function(response)
    if response == 0 then
      print("they said no")
    end
    if (response == 1) then
        print("Attempting to set song")
        local area_id = Net.get_player_area(player_id)
        Net.set_song(area_id, "/server/assets/jukebox/"..Songs[tonumber(post_id)].title..".ogg")
        print("successfully set song")
        Net.close_bbs(player_id)
        print("Closed BBS with success")
        print(post_id)
      end
    end)
  end
end


     function handle_object_interaction(player_id, object_id, button)
      local area_id = Net.get_player_area(player_id)
      local object = Net.get_object_by_id(area_id, object_id)
      if object.custom_properties.Jukebox ~= nil then
      print("Checked Custom properties to make sure its Jukebox")
      if object.custom_properties.Color ~= nil then
        color.r = object.custom_properties.r
        color.g = object.custom_properties.g
        color.b = object.custom_properties.b
        Net.open_board(player_id, "Songs", color, Songs)
      end
      elseif object.custom_properties.Color == nil then
        Net.open_board(player_id, "Songs", color, Songs)
      end
    end