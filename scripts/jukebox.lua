local SongPath = "/server/assets/jukebox/"

--Must be named exactly as listed in quotes below next to the title: key
    local color = {
      r = 0,
      g = 0,
      b = 0
    }
  
    local Songs = {
      { id = "1",title = "Track 1", author = "", read = true, SongNumber = 0 },
      { id = "2",title = "Track 2", author = "", read = true,SongNumber = 1 },
      { id = "3",title = "Track 3", author = "",   read = true,SongNumber = 2 },
      { id = "4",title = "Track 4", author = "",  read = true,SongNumber = 3},
      { id = "5",title = "Track 5", author = "", read = true,SongNumber = 4 },
      { id = "6",title = "Track 6", author = "", read = true,SongNumber = 5 },
      { id = "7",title = "Track 7", author = "",read = true, SongNumber = 6 },
      { id = "8",title = "Track 8", author = "",  read = true,SongNumber = 7},
      { id = "9",title = "Track 9", author = "", read = true,SongNumber = 8 },
      { id = "10",title = "Track 10", author = "", read = true,SongNumber = 9 },
      { id = "11",title = "Track 11", author = "",   read = true,SongNumber = 10 },
      { id = "12",title = "Track 12", author = "",  read = true,SongNumber = 11},
      { id = "13",title = "Track 13", author = "", read = true,SongNumber = 12 },
      { id = "14",title = "Track 14", author = "", read = true,SongNumber = 13 },
      { id = "15",title = "Track 15", author = "",   read = true,SongNumber = 14 },
      { id = "16",title = "Track 16", author = "",  read = true,SongNumber = 15},
      { id = "17",title = "Track 17", author = "",  read = true,SongNumber = 16},
      { id = "18",title = "Track 18", author = "",  read = true,SongNumber = 17},
      { id = "19",title = "Track 19", author = "",  read = true,SongNumber = 18},
      { id = "20",title = "Track 20", author = "",  read = true,SongNumber = 19},
    }
    print("made it to step 1")


      function handle_post_selection(player_id,post_id)
        
      Async.question_player(player_id,("Do you wish to change the song to".." "..Songs[tonumber(post_id)].title.."?"))
  .and_then(function(response)
    if response == 0 then
      print("they said no")
      Net.close_bbs(player_id)
      print("closed BBS with a cancel")

    elseif response == 1 then
      print("Attempting to set song")
      local area_id = Net.get_player_area(player_id)
      Net.set_song(area_id, (SongPath..Songs[tonumber(post_id)].title..".ogg"))
      print("successfully set song")
      Net.close_bbs(player_id)
      print("Closed BBS with success")
      print(post_id)
    end
  end)
end
    
  
    for i, s in ipairs(Songs) do
      if s.title == post_id then
        Songs = s
        break
      end
    end
    
     function handle_object_interaction(player_id, object_id, button)
      local area_id = Net.get_player_area(player_id)
      local object = Net.get_object_by_id(area_id, object_id)
      if object.custom_properties.Jukebox ~= nil then
      print("Checked Custom properties to make sure its Jukebox")
      Net.open_board(player_id, "Songs", color, Songs)
      end
    end