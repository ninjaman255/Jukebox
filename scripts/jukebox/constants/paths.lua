local PathStrings = {}

PathStrings.RootPaths = {
    Records = "assets/jukebox/records/",
    Tracks = "assets/jukebox/tracks/",
    UISprites = "assets/jukebox/ui-sprites/"
}

PathStrings.UIAssetPaths = {
    backdrop = PathStrings.RootPaths.UISprites .. "jukebox-backdrop.png",
    frame = PathStrings.RootPaths.UISprites .. "jukebox-frame.png"
}

return PathStrings
