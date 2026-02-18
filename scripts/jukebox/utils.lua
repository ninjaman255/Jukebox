-- utils.lua
-- Helper functions for OS detection, file listing, and string splitting.

local utils = {}

-- Splits a string based on a delimiter.
function utils.splitter(inputstr, sep)
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

-- Detects the operating system (windows or unix).
function utils.get_os()
    if package.config:sub(1, 1) == "\\" then
        return "windows"
    else
        return "unix"
    end
end

-- Lists files in a directory using the appropriate system command.
function utils.listFiles(directory)
    local os_type = utils.get_os()
    print("[jukebox] Populating song list from " .. os_type .. " system.")
    local songTable = {}
    local cmd = ""

    if os_type == "windows" then
        cmd = 'dir "' .. directory .. '" /b'
    else
        cmd = 'ls "' .. directory .. '"'
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

return utils
