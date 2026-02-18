LockableTable Module Documentation
Overview
LockableTable is a Lua module that provides tables with locking capabilities to prevent unauthorized modifications. It supports recursive locking/unlocking and can manage nested lockable tables.

Installation
lua
local LockableTable = require("lockable-table")
Creating Lockable Tables
LockableTable.new([initial_data])
Creates a new lockable table with optional initial data.

lua
-- Empty lockable table
local table1 = LockableTable.new()

-- With initial data
local table2 = LockableTable.new({
    name = "John",
    age = 30,
    scores = {95, 88, 92}
})

-- Using as a regular table
local data = LockableTable.new()
data.name = "Alice"           -- Direct assignment works
data:add("age", 25)          -- Safe method also works
LockableTable.wrap(table)
Converts a regular table to a lockable table (shallow conversion).

lua
local regular = {x = 10, y = 20}
local lockable = LockableTable.wrap(regular)
LockableTable.isLockable(table)
Checks if a table is a lockable table.

lua
local t = LockableTable.new()
print(LockableTable.isLockable(t))  -- true
print(LockableTable.isLockable({})) -- false
Core Methods
Data Manipulation Methods
:add(key, value[, recursive])
Safely adds a key-value pair to the table.

lua
local data = LockableTable.new()
local success, error = data:add("name", "Alice")
-- success = true, error = nil

data:lockKey("name")
local success, error = data:add("name", "Bob")
-- success = false, error = "Cannot modify: Key 'name' is locked"
:remove(key[, recursive])
Safely removes a key from the table.

lua
data:add("temp", "value")
local success, error = data:remove("temp")
-- Removes the key "temp"

data:lockKey("important")
local success, error = data:remove("important")
-- Fails because key is locked
:update(key, value[, recursive])
Updates an existing key (only works if key already exists).

lua
data:add("counter", 1)
local success, error = data:update("counter", 2)
-- Updates counter to 2

local success, error = data:update("nonexistent", 10)
-- Fails with "Key does not exist"
:addMany(pairs[, recursive])
Adds multiple key-value pairs at once.

lua
local results = data:addMany({
    a = 1,
    b = 2,
    c = 3
})
-- results = {a = {success = true}, b = {success = true}, c = {success = true}}
:removeMany(keys[, recursive])
Removes multiple keys at once.

lua
local results = data:removeMany({"a", "b", "c"})
:replace(new_data[, recursive])
Replaces all data in the table.

lua
data:replace({
    x = 100,
    y = 200,
    z = 300
})
:clear([recursive])
Clears all data from the table.

lua
data:clear()
Locking Methods
:lockKey(key[, recursive])
Locks a specific key to prevent modification.

lua
data:add("apiKey", "secret123")
data:lockKey("apiKey")
data.apiKey = "changed"  -- Error: key is locked
:unlockKey(key[, recursive])
Unlocks a previously locked key.

lua
data:unlockKey("apiKey")
data.apiKey = "changed"  -- Now works
:lockValue(value[, recursive])
Locks a specific value (prevents modification anywhere in the table).

lua
local config = {settings = "important"}
data:add("config1", config)
data:add("config2", config)

data:lockValue(config)
data.config1 = "new"  -- Error: value is locked
data.config2 = "new"  -- Error: value is locked
:unlockValue(value[, recursive])
Unlocks a previously locked value.

:lockAll([recursive])
Locks the entire table.

lua
data:lockAll()
data.newKey = "value"    -- Error: table is fully locked
data:add("test", 123)    -- Error: table is fully locked
:unlockAll([recursive])
Unlocks the entire table.

lua
data:unlockAll()
-- Now modifications are allowed
Checking Methods
:canAdd(key)
Checks if a key can be added.

lua
if data:canAdd("newKey") then
    data:add("newKey", "value")
else
    print("Cannot add key")
end
:canRemove(key)
Checks if a key can be removed.

:isKeyLocked(key)
Returns true if the key is locked.

:isValueLocked(value)
Returns true if the value is locked.

:isFullyLocked()
Returns true if the table is fully locked.

:getLockedKeys()
Returns a list of all locked keys.

lua
local lockedKeys = data:getLockedKeys()
-- Returns: {"apiKey", "password", ...}
:getLockedValues()
Returns a list of all locked values.

Utility Methods
:size()
Returns the number of key-value pairs in the table.

lua
print(data:size())  -- Number of items
:keys()
Returns a list of all keys.

lua
local allKeys = data:keys()
:values()
Returns a list of all values.

:getRaw(key)
Gets a value directly, bypassing any metatable checks.

:setRaw(key, value)
Sets a value directly, bypassing all locks (use with caution!).

Nested Lockable Tables
Creating Nested Structures
You can nest lockable tables inside other lockable tables for hierarchical data structures.

lua
-- Create parent and child tables
local parent = LockableTable.new({
    name = "Parent Table"
})

local child = LockableTable.new({
    name = "Child Table",
    data = {1, 2, 3}
})

-- Add child to parent
parent:add("child", child, true)  -- true enables recursive management

-- Add grandchild
local grandchild = LockableTable.new({value = "Nested"})
child:add("grandchild", grandchild, true)
Recursive Locking Management
When you use the recursive parameter (set to true), operations will affect nested tables.

lua
-- Lock parent and all children recursively
parent:lockAll(true)

-- Now all levels are locked
parent.name = "changed"              -- Error: locked
parent.child.name = "changed"        -- Error: locked
parent.child.grandchild.value = "new" -- Error: locked

-- Unlock everything recursively
parent:unlockAll(true)

-- Now modifications are allowed at all levels
Parent-Child Relationship
When you add a lockable table to another lockable table, a parent relationship is established:

lua
local parent = LockableTable.new()
local child = LockableTable.new()

parent:add("child", child)
print(child._parent == parent)  -- true
Example: Configuration System
lua
-- Create a hierarchical configuration system
local config = LockableTable.new({
    app = LockableTable.new({
        name = "MyApp",
        version = "1.0"
    }),
    database = LockableTable.new({
        host = "localhost",
        port = 3306,
        credentials = LockableTable.new({
            username = "admin",
            password = "secret"
        })
    })
})

-- Lock sensitive data at different levels
config.database.credentials:lockKey("password")
config.database.credentials:lockAll()  -- Lock all database credentials

-- Lock entire configuration when deploying
config:lockAll(true)  -- Locks everything including nested tables

-- Temporarily unlock for maintenance
config:unlockAll(true)
config.database:update("port", 5432)
config:lockAll(true)
Example: Game State Management
lua
local gameState = LockableTable.new({
    players = LockableTable.new(),
    world = LockableTable.new({
        objects = LockableTable.new(),
        terrain = LockableTable.new()
    }),
    settings = LockableTable.new({
        difficulty = "normal",
        graphics = "high"
    })
})

-- Add players
gameState.players:add("player1", {
    health = 100,
    position = {x=0, y=0, z=0}
})

-- Lock critical game state during save
gameState:lockAll(true)

-- Save game (no modifications during save)
-- saveGame(gameState)

-- Unlock after save
gameState:unlockAll(true)

-- Lock individual player data
gameState.players:lockKey("player1")

-- But allow world modifications
gameState.world.objects:add("npc1", {type = "villager"})
Best Practices
Use safe methods: Prefer :add(), :remove(), :update() over direct assignment for better error handling.

Always check returns: Most methods return (success, error_message).

Use recursive locking carefully: Only use recursive = true when you want to affect nested tables.

Clean up references: When removing nested lockable tables, use recursive = true to properly clear parent references.

Document locking strategy: Make it clear which parts of your data structure should be locked at different times.

Error Handling
lua
local data = LockableTable.new()

-- Method 1: Check return values
local success, err = data:add("key", "value")
if not success then
    print("Error:", err)
end

-- Method 2: Use canAdd/canRemove
if data:canAdd("key") then
    data:add("key", "value")
end

-- Method 3: Try/catch for direct assignment
local ok, result = pcall(function()
    data.lockedKey = "value"  -- Might throw error
end)
if not ok then
    print("Error:", result)
end
Performance Considerations
Lock checking adds overhead to table operations

Nested locking adds recursive overhead

Use raw methods (getRaw/setRaw) for performance-critical code that doesn't need locking

Consider locking at the highest level possible rather than locking individual keys

This module provides robust data protection while maintaining flexibility for various use cases.