local StaticUIData = {}

StaticUIData.UIIDNames = {
    "Share Screen",
    "Jukebox Backdrop",
    "Default Record",
    "Cursor Left",
    "Cursor Right"
}

StaticUIData.UIData = {
    ["Shade Screen"] = {
        texture_path = "/server/assets/jukebox/ui-sprites/shade-screen.png",
        anim_path = "",
        anim_state = "",
        x = 0,
        y = 0,
        z = 0,
        sx = 2.0,
        sy = 2.0,
    },
    ["Jukebox Backdrop"] = {
        texture_path = "/server/assets/jukebox/ui-sprites/jukebox-backdrop.png",
        anim_path = "",
        anim_state = "",
        x = 0,
        y = 1,
        z = 0,
        sx = 2.0,
        sy = 2.0
    },
    ["Default Record"] = {
        texture_path = "/server/assets/jukebox/records/MMBN7_OST-alouetteEXE/base.png",
        anim_path = "/server/assets/jukebox/ui-sprites/records/record.animation",
        anim_state = "DEFAULT",
        x = 120,
        y = 79,
        z = 2,
        sx = 2.0,
        sy = 2.0,
    },
    ["Cursor Left"] = {
        texture_path = "/server/assets/net-games/text_cursor.png",
        anim_path = "/server/assets/net-games/text_cursor.animation",
        anim_state = "CURSOR_LEFT",
        x = 63,
        y = 102,
        z = 4,
        sx = 2.0,
        sy = 2.0
    },
    ["Cursor Right"] = {
        texture_path = "/server/assets/net-games/text_cursor.png",
        anim_path = "/server/assets/net-games/text_cursor.animation",
        anim_state = "CURSOR_RIGHT",
        x = 186,
        y = 102,
        z = 4,
        sx = 2.0,
        sy = 2.0
    }
}

return StaticUIData
