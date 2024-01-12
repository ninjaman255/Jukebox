-- Example use case
-- set a local variable for the directory youd like all the file names from
-- "/server/" does not work for this use case, you will need to use "." instead
-- to start from the server directory

-- local costumesDir = './assets/ezlibs-custom-assets/costumes/'

function listFiles(directory)
    -- make a table to collect the file names
    local songTable = {}    
    -- handles running the cmd
    local cmd = 'dir "' .. directory .. '" /b'
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

-- Run the function to grab all files from the costumesDir listed in the "Example use case" above
-- listFiles(costumesDir)