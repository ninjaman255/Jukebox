-- lockable_table.lua
local LockableTable = {}

local function is_lockable(t)
    return type(t) == "table" and t._is_lockable == true
end

local function create_lockable_table(t)
    -- Internal data storage
    local data = t and {table.unpack(t)} or {}
    local locked_keys = {}
    local locked_values = {}
    local fully_locked = false
    
    -- Methods table (separate from data)
    local methods = {}
    
    -- Helper function to check if we can modify
    local function can_modify(key, new_value)
        if fully_locked then
            return false, "Cannot modify: Table is fully locked"
        end
        
        if locked_keys[key] then
            return false, "Cannot modify: Key '" .. tostring(key) .. "' is locked"
        end
        
        local current_value = data[key]
        if locked_values[current_value] then
            return false, "Cannot modify: Value at key '" .. tostring(key) .. "' is locked"
        end
        
        return true
    end
    
    -- Create the public table
    local public = {}
    
    -- Mark as lockable
    public._is_lockable = true
    
    -- Metatable for the public table
    local mt = {
        __index = function(tbl, key)
            -- First check if it's a method
            local method = methods[key]
            if method then
                return method
            end
            -- Then return data
            return data[key]
        end,
        
        __newindex = function(tbl, key, value)
            -- Check if trying to overwrite a method
            if methods[key] then
                error("Cannot overwrite method: " .. tostring(key))
            end
            
            local ok, err = can_modify(key, value)
            if not ok then
                error(err)
            end
            
            -- Handle nested lockable tables
            if is_lockable(value) then
                value._parent = public
            end
            
            data[key] = value
        end,
        
        __pairs = function()
            return function(tbl, k)
                return next(data, k)
            end, nil, nil
        end,
        
        __len = function()
            local count = 0
            for _ in pairs(data) do
                count = count + 1
            end
            return count
        end
    }
    
    setmetatable(public, mt)
    
    -- Define methods
    function methods:add(key, value, recursive)
        recursive = recursive or false
        local ok, err = can_modify(key, value)
        if not ok then
            return false, err
        end
        
        if is_lockable(value) then
            value._parent = public
            if recursive and fully_locked then
                value:lockAll(true)
            end
        end
        
        data[key] = value
        return true
    end
    
    function methods:remove(key, recursive)
        recursive = recursive or false
        local ok, err = can_modify(key)
        if not ok then
            return false, err
        end
        
        if recursive then
            local value = data[key]
            if is_lockable(value) then
                value:unlockAll(true)
                value._parent = nil
            end
        end
        
        data[key] = nil
        return true
    end
    
    function methods:addMany(pairs, recursive)
        recursive = recursive or false
        local results = {}
        for key, value in pairs(pairs) do
            local success, err = self:add(key, value, recursive)
            results[key] = {success = success, error = err}
        end
        return results
    end
    
    function methods:removeMany(keys, recursive)
        recursive = recursive or false
        local results = {}
        for _, key in ipairs(keys) do
            local success, err = self:remove(key, recursive)
            results[key] = {success = success, error = err}
        end
        return results
    end
    
    function methods:canAdd(key)
        return can_modify(key)
    end
    
    function methods:canRemove(key)
        return can_modify(key)
    end
    
    function methods:update(key, value, recursive)
        recursive = recursive or false
        if data[key] == nil then
            return false, "Key does not exist"
        end
        
        local success, err = self:add(key, value, recursive)
        if success then
            return true, "Updated successfully"
        else
            return false, err
        end
    end
    
    function methods:replace(new_data, recursive)
        recursive = recursive or false
        if fully_locked then
            return false, "Cannot replace: Table is fully locked"
        end
        
        -- First, remove all existing keys
        for key, _ in pairs(data) do
            if key ~= "_is_lockable" then
                local success, err = self:remove(key, recursive)
                if not success then
                    return false, "Failed to remove key '" .. tostring(key) .. "': " .. err
                end
            end
        end
        
        -- Then add all new data
        for key, value in pairs(new_data) do
            local success, err = self:add(key, value, recursive)
            if not success then
                return false, "Failed to add key '" .. tostring(key) .. "': " .. err
            end
        end
        
        return true
    end
    
    function methods:clear(recursive)
        recursive = recursive or false
        return self:replace({}, recursive)
    end
    
    function methods:getRaw(key)
        return data[key]
    end
    
    function methods:setRaw(key, value)
        data[key] = value
        return true
    end
    
    function methods:lockKey(key, recursive)
        recursive = recursive or false
        locked_keys[key] = true
        
        if recursive and is_lockable(data[key]) then
            data[key]:lockAll()
        end
    end
    
    function methods:unlockKey(key, recursive)
        recursive = recursive or false
        locked_keys[key] = nil
        
        if recursive and is_lockable(data[key]) then
            data[key]:unlockAll()
        end
    end
    
    function methods:lockValue(value, recursive)
        recursive = recursive or false
        if value == nil then return end
        
        locked_values[value] = true
        
        if recursive and is_lockable(value) then
            value:lockAll()
        end
    end
    
    function methods:unlockValue(value, recursive)
        recursive = recursive or false
        if value == nil then return end
        
        locked_values[value] = nil
        
        if recursive and is_lockable(value) then
            value:unlockAll()
        end
    end
    
    function methods:lockAll(recursive)
        recursive = recursive or false
        fully_locked = true
        
        if recursive then
            for _, v in pairs(data) do
                if is_lockable(v) then
                    v:lockAll(true)
                end
            end
        end
    end
    
    function methods:unlockAll(recursive)
        recursive = recursive or false
        fully_locked = false
        locked_keys = {}
        locked_values = {}
        
        if recursive then
            for _, v in pairs(data) do
                if is_lockable(v) then
                    v:unlockAll(true)
                end
            end
        end
    end
    
    function methods:isKeyLocked(key)
        return locked_keys[key] == true
    end
    
    function methods:isValueLocked(value)
        return locked_values[value] == true
    end
    
    function methods:isFullyLocked()
        return fully_locked
    end
    
    function methods:getLockedKeys()
        local keys = {}
        for key, _ in pairs(locked_keys) do
            table.insert(keys, key)
        end
        return keys
    end
    
    function methods:getLockedValues()
        local values = {}
        for value, _ in pairs(locked_values) do
            table.insert(values, value)
        end
        return values
    end
    
    function methods:size()
        local count = 0
        for _ in pairs(data) do
            count = count + 1
        end
        return count
    end
    
    function methods:keys()
        local keys = {}
        for key, _ in pairs(data) do
            table.insert(keys, key)
        end
        return keys
    end
    
    function methods:values()
        local values = {}
        for _, value in pairs(data) do
            table.insert(values, value)
        end
        return values
    end
    
    return public
end

-- Module function
function LockableTable.new(t)
    return create_lockable_table(t)
end

-- Check if a table is lockable
function LockableTable.isLockable(t)
    return is_lockable(t)
end

-- Make a regular table lockable (shallow)
function LockableTable.wrap(t)
    if is_lockable(t) then
        return t
    end
    return LockableTable.new(t)
end

return LockableTable