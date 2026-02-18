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
-- Returns a simple list of file/directory names (strings).
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

-- Lists contents of a directory with type information.
-- Returns a table where each entry is { name = string, is_dir = boolean }.
function utils.listFilesDetailed(directory)
    local os_type = utils.get_os()
    print("[jukebox] Getting detailed file listing from " .. os_type .. " system.")
    local entries = {}

    if os_type == "windows" then
        -- List directories
        local cmd_dir = 'dir "' .. directory .. '" /ad /b'
        local handle_dir = io.popen(cmd_dir)
        if handle_dir then
            for dir in handle_dir:lines() do
                table.insert(entries, { name = dir, is_dir = true })
            end
            handle_dir:close()
        else
            print("Error listing directories.")
        end

        -- List files
        local cmd_file = 'dir "' .. directory .. '" /a-d /b'
        local handle_file = io.popen(cmd_file)
        if handle_file then
            for file in handle_file:lines() do
                table.insert(entries, { name = file, is_dir = false })
            end
            handle_file:close()
        else
            print("Error listing files.")
        end
    else -- unix
        -- Use ls -F to append type indicators (/ for directories)
        local cmd = 'ls -F "' .. directory .. '"'
        local handle = io.popen(cmd)
        if handle then
            for line in handle:lines() do
                if line:sub(-1) == '/' then
                    -- Directory: remove trailing '/'
                    local name = line:sub(1, -2)
                    table.insert(entries, { name = name, is_dir = true })
                else
                    -- File (may have other indicators like *, @, |, but we ignore them)
                    table.insert(entries, { name = line, is_dir = false })
                end
            end
            handle:close()
        else
            print("Error listing files.")
        end
    end

    return entries
end

return utils
