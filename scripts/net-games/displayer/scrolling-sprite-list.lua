-- Scrolling Sprite List System - DEBUG VERSION
ScrollingSpriteList = {}
ScrollingSpriteList.__index = ScrollingSpriteList

function ScrollingSpriteList:init()
    self.player_lists = {}
    
    -- Default configurations
    self.default_config = {
        z_order = 100,
        scroll_speed = 30,
        entry_spacing = 10,
        entry_delay = 1.0,
        loop = false,
        destroy_when_finished = true,
        destroy_delay = 1.0,
        max_columns = 1,
        column_spacing = 5,
        row_spacing = 5,
        align = "left"
    }
    
    -- Animation states
    self.states = {
        waiting = "waiting",
        scrolling = "scrolling",
        finished = "finished"
    }
    
    Net:on("player_join", function(event)
        self:setupPlayerLists(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerLists(event.player_id)
    end)
    
    Net:on("tick", function(event)
        self:updateScrollingLists(event.delta_time)
    end)
    
    --print("DEBUG: ScrollingSpriteList initialized")
    return self
end

function ScrollingSpriteList:setupPlayerLists(player_id)
    self.player_lists[player_id] = {
        active_lists = {},
        next_list_id = 1,
        allocated_sprites = {} -- Track allocated sprites
    }
    
    print("DEBUG: Player lists setup for " .. player_id)
end

function ScrollingSpriteList:cleanupPlayerLists(player_id)
    local player_data = self.player_lists[player_id]
    if player_data then
        for list_id, list_data in pairs(player_data.active_lists) do
            self:removeScrollingList(player_id, list_id)
        end
        self.player_lists[player_id] = nil
    end
    print("DEBUG: Cleaned up player lists for " .. player_id)
end

function ScrollingSpriteList:createScrollingList(player_id, list_id, x, y, width, height, config)
    print("DEBUG: Creating scrolling list " .. list_id .. " for player " .. player_id)
    
    config = config or {}
    
    local player_data = self.player_lists[player_id]
    if not player_data then 
        print("DEBUG: No player data for " .. player_id)
        return nil 
    end
    
    -- Merge with default configuration
    local list_config = {}
    for k, v in pairs(self.default_config) do
        list_config[k] = config[k] or v
    end
    
    list_config.x = x or 0
    list_config.y = y or 0
    list_config.width = width or 200
    list_config.height = height or 100
    list_config.backdrop = config.backdrop
    list_config.sprites = config.sprites or {}
    list_config.entry_states = {}
    list_config.current_state = self.states.waiting
    
    -- Calculate text bounds if backdrop is provided
    if list_config.backdrop then
        local padding_x = list_config.backdrop.padding_x or 8
        local padding_y = list_config.backdrop.padding_y or 6
        list_config.bounds_left = list_config.backdrop.x + padding_x
        list_config.bounds_right = list_config.backdrop.x + list_config.backdrop.width - padding_x
        list_config.bounds_top = list_config.backdrop.y + padding_y
        list_config.bounds_bottom = list_config.backdrop.y + list_config.backdrop.height - padding_y
        list_config.bounds_width = list_config.bounds_right - list_config.bounds_left
        list_config.bounds_height = list_config.bounds_bottom - list_config.bounds_top
    else
        list_config.bounds_left = list_config.x
        list_config.bounds_right = list_config.x + list_config.width
        list_config.bounds_top = list_config.y
        list_config.bounds_bottom = list_config.y + list_config.height
        list_config.bounds_width = list_config.width
        list_config.bounds_height = list_config.height
    end
    
    print("DEBUG: List config created with " .. #list_config.sprites .. " sprites")
    
    -- Initialize entry states with grid layout
    self:initializeSpriteGrid(list_config)
    
    local list_data = {
        config = list_config,
        backdrop_id = nil,
        state = self.states.waiting,
        start_time = os.clock(),
        all_finished = false,
        finished_timer = 0,
        marked_for_removal = false
    }
    
    -- Pre-allocate all sprites for this list
    print("DEBUG: Pre-allocating sprites...")
    self:preallocateSprites(player_id, list_id, list_config)
    
    -- Draw backdrop if specified
    if list_config.backdrop then
        list_data.backdrop_id = self:drawListBackdrop(player_id, list_id, list_config)
        print("DEBUG: Backdrop drawn with ID: " .. tostring(list_data.backdrop_id))
    end
    
    player_data.active_lists[list_id] = list_data
    
    -- Start the first entry immediately if no delay
    if #list_config.sprites > 0 and list_config.entry_delay <= 0 then
        list_config.entry_states[1].state = "scrolling"
        list_data.state = self.states.scrolling
        self:drawListEntry(player_id, list_id, 1, list_data)
    end
    
    print("DEBUG: Scrolling list created successfully")
    return list_id
end

-- NEW: Pre-allocate all sprites upfront
function ScrollingSpriteList:preallocateSprites(player_id, list_id, config)
    local unique_sprites = {}
    
    for i, sprite_def in ipairs(config.sprites) do
        local sprite_key = sprite_def.texture_path .. "|" .. (sprite_def.anim_path or "")
        if not unique_sprites[sprite_key] then
            unique_sprites[sprite_key] = true
            
            -- Create unique sprite ID for this list
            local sprite_id = list_id .. "_sprite_" .. i
            
            print("DEBUG: Pre-allocating sprite: " .. sprite_id)
            print("DEBUG: Texture path: " .. tostring(sprite_def.texture_path))
            print("DEBUG: Anim path: " .. tostring(sprite_def.anim_path))
            
            -- Try to allocate with error handling
            local success, err = pcall(function()
                if sprite_def.texture_path then
                    Net.provide_asset_for_player(player_id, sprite_def.texture_path)
                    print("DEBUG: Provided texture asset")
                end
                
                if sprite_def.anim_path then
                    Net.provide_asset_for_player(player_id, sprite_def.anim_path)
                    print("DEBUG: Provided anim asset")
                end
                
                Net.player_alloc_sprite(player_id, sprite_id, {
                    texture_path = sprite_def.texture_path,
                    anim_path = sprite_def.anim_path
                })
                print("DEBUG: Successfully allocated sprite: " .. sprite_id)
            end)
            
            if not success then
                print("DEBUG: FAILED to allocate sprite " .. sprite_id .. ": " .. tostring(err))
            end
        end
    end
end

function ScrollingSpriteList:initializeSpriteGrid(list_config)
    local sprites = list_config.sprites
    local max_columns = list_config.max_columns or 1
    local column_spacing = list_config.column_spacing or 5
    local row_spacing = list_config.row_spacing or 5
    
    -- Calculate maximum sprite dimensions for grid layout
    local max_sprite_width = 0
    local max_sprite_height = 0
    
    for i, sprite_def in ipairs(sprites) do
        local sprite_width = (sprite_def.width or sprite_def.sx or 1) * (sprite_def.scale or 1)
        local sprite_height = (sprite_def.height or sprite_def.sy or 1) * (sprite_def.scale or 1)
        
        max_sprite_width = math.max(max_sprite_width, sprite_width)
        max_sprite_height = math.max(max_sprite_height, sprite_height)
    end
    
    -- Calculate grid layout
    local cell_width = max_sprite_width + column_spacing
    local cell_height = max_sprite_height + row_spacing
    local actual_columns = math.min(max_columns, math.floor(list_config.bounds_width / cell_width))
    if actual_columns < 1 then actual_columns = 1 end
    
    -- Calculate horizontal alignment offset
    local align_offset = 0
    if list_config.align == "center" then
        local total_grid_width = actual_columns * cell_width - column_spacing
        align_offset = (list_config.bounds_width - total_grid_width) / 2
    elseif list_config.align == "right" then
        local total_grid_width = actual_columns * cell_width - column_spacing
        align_offset = list_config.bounds_width - total_grid_width
    end
    
    -- Initialize entry states with grid positions
    for i, sprite_def in ipairs(sprites) do
        local row = math.floor((i - 1) / actual_columns)
        local col = (i - 1) % actual_columns
        
        local grid_x = list_config.bounds_left + align_offset + (col * cell_width)
        local grid_y = list_config.bounds_bottom + (row * cell_height)
        
        list_config.entry_states[i] = {
            sprite_def = sprite_def,
            y_offset = 0,
            grid_x = grid_x,
            grid_y = grid_y,
            state = "waiting",
            display_objects = {},
            start_delay = (row * list_config.entry_delay),
            timer = 0,
            row_height = cell_height,
            sprite_id = list_id .. "_sprite_" .. i  -- Use pre-allocated sprite ID
        }
    end
    
    print("DEBUG: Grid initialized with " .. #sprites .. " entries, " .. actual_columns .. " columns")
end

function ScrollingSpriteList:drawListBackdrop(player_id, list_id, config)
    local backdrop_id = list_id .. "_backdrop"
    
    print("DEBUG: Drawing backdrop at " .. config.backdrop.x .. "," .. config.backdrop.y)
    
    Net.player_draw_sprite(
        player_id,
        "backdrop",
        {
            id = backdrop_id,
            x = config.backdrop.x,
            y = config.backdrop.y,
            z = config.z_order - 1,
            sx = config.backdrop.width,
            sy = config.backdrop.height
        }
    )
    
    return backdrop_id
end

function ScrollingSpriteList:drawListEntry(player_id, list_id, entry_index, list_data)
    local config = list_data.config
    local entry_state = config.entry_states[entry_index]
    
    -- Clear previous display objects
    self:clearEntryDisplay(player_id, entry_state)
    
    -- Calculate sprite position (accounting for scrolling)
    local sprite_x = entry_state.grid_x
    local sprite_y = entry_state.grid_y + entry_state.y_offset
    
    -- Only draw if within visible bounds
    if sprite_y + (entry_state.sprite_def.height or 10) >= config.bounds_top and 
       sprite_y <= config.bounds_bottom then
        
        local sprite_def = entry_state.sprite_def
        
        local unique_display_id = list_id .. "_entry_" .. entry_index
        local sprite_id = entry_state.sprite_id or ("sprite_" .. entry_index)
        
        print("DEBUG: Attempting to draw sprite " .. sprite_id .. " at " .. sprite_x .. "," .. sprite_y)
        
        -- Try to draw the sprite
        local draw_success, draw_err = pcall(function()
            Net.player_draw_sprite(
                player_id,
                sprite_id,
                {
                    id = unique_display_id,
                    x = sprite_x,
                    y = sprite_y,
                    z = config.z_order,
                    sx = sprite_def.sx or sprite_def.scale or 1,
                    sy = sprite_def.sy or sprite_def.scale or 1,
                    anim_state = sprite_def.anim_state or "UI"
                }
            )
        end)
        
        if draw_success then
            print("DEBUG: Successfully drew sprite " .. sprite_id)
            table.insert(entry_state.display_objects, {
                type = "sprite",
                id = unique_display_id,
                sprite_id = sprite_id
            })
        else
            print("DEBUG: FAILED to draw sprite " .. sprite_id .. ": " .. tostring(draw_err))
            -- Draw error placeholder
            self:drawErrorPlaceholder(player_id, unique_display_id, sprite_x, sprite_y, config.z_order)
            table.insert(entry_state.display_objects, {
                type = "sprite", 
                id = unique_display_id,
                sprite_id = "error"
            })
        end
        
        -- Draw optional text if provided
        if sprite_def.text then
            local text_x = sprite_x + (sprite_def.text_offset_x or 0)
            local text_y = sprite_y + (sprite_def.text_offset_y or 0)
            
            print("DEBUG: Drawing text: " .. sprite_def.text)
            
            local text_display_id = self:drawSpriteText(
                player_id, 
                sprite_def.text, 
                text_x, 
                text_y, 
                sprite_def.text_font or "THICK", 
                sprite_def.text_scale or 2.0, 
                config.z_order + 1,
                list_id .. "_text_" .. entry_index
            )
            
            if text_display_id then
                table.insert(entry_state.display_objects, {
                    type = "text",
                    id = text_display_id
                })
            end
        end
    else
        print("DEBUG: Sprite " .. entry_index .. " outside bounds, y=" .. sprite_y)
    end
end

function ScrollingSpriteList:drawErrorPlaceholder(player_id, display_id, x, y, z_order)
    local success, err = pcall(function()
        -- Use the backdrop sprite as a placeholder
        Net.player_draw_sprite(
            player_id,
            "backdrop",
            {
                id = display_id,
                x = x,
                y = y,
                z = z_order,
                sx = 16,
                sy = 16,
                r = 1.0, g = 0.0, b = 0.0, a = 0.7
            }
        )
    end)
    
    if not success then
        print("DEBUG: Even error placeholder failed: " .. tostring(err))
    end
end

function ScrollingSpriteList:drawSpriteText(player_id, text, x, y, font, scale, z_order, display_id)
    local font_system_success, font_system = pcall(require, "scripts/net-games/displayer/font-system")
    
    if font_system_success and font_system and font_system.drawText then
        return font_system:drawText(player_id, display_id, text, x, y, font, scale, z_order)
    else
        print("DEBUG: Font system not available")
    end
end

function ScrollingSpriteList:clearEntryDisplay(player_id, entry_state)
    for _, display_obj in ipairs(entry_state.display_objects) do
        if display_obj.type == "sprite" then
            Net.player_erase_sprite(player_id, display_obj.id)
        elseif display_obj.type == "text" then
            local font_system_success, font_system = pcall(require, "scripts/net-games/displayer/font-system")
            if font_system_success and font_system and font_system.eraseTextDisplay then
                font_system:eraseTextDisplay(player_id, display_obj.id)
            else
                Net.player_erase_sprite(player_id, display_obj.id)
            end
        end
    end
    entry_state.display_objects = {}
end

function ScrollingSpriteList:updateScrollingLists(delta)
    if not delta or delta <= 0 then return end
    
    for player_id, player_data in pairs(self.player_lists) do
        for list_id, list_data in pairs(player_data.active_lists) do
            if list_data.marked_for_removal then
                -- Remove lists marked for removal
                self:removeScrollingList(player_id, list_id)
            elseif list_data.state ~= self.states.finished then
                self:updateScrollingList(player_id, list_id, list_data, delta)
            else
                -- Handle finished lists that are waiting for auto-removal
                self:updateFinishedList(player_id, list_id, list_data, delta)
            end
        end
    end
end

function ScrollingSpriteList:updateScrollingList(player_id, list_id, list_data, delta)
    local config = list_data.config
    local all_entries_finished = true
    local any_entry_scrolling = false
    
    for i, entry_state in ipairs(config.entry_states) do
        if entry_state.state == "waiting" then
            -- Check if it's time to start this entry
            entry_state.timer = entry_state.timer + delta
            if entry_state.timer >= entry_state.start_delay then
                entry_state.state = "scrolling"
                list_data.state = self.states.scrolling
                self:drawListEntry(player_id, list_id, i, list_data)
            else
                all_entries_finished = false
            end
        end
        
        if entry_state.state == "scrolling" then
            any_entry_scrolling = true
            -- Update position
            entry_state.y_offset = entry_state.y_offset - (config.scroll_speed * delta)
            
            -- Redraw at new position
            self:drawListEntry(player_id, list_id, i, list_data)
            
            -- Check if this entry has scrolled completely off screen
            local sprite_height = entry_state.sprite_def.height or 10
            if entry_state.y_offset + config.bounds_bottom + sprite_height < config.bounds_top then
                entry_state.state = "finished"
                self:clearEntryDisplay(player_id, entry_state)
            else
                all_entries_finished = false
            end
        end
    end
    
    -- Update list state
    if all_entries_finished and #config.entry_states > 0 then
        list_data.state = self.states.finished
        list_data.all_finished = true
        
        if config.destroy_when_finished then
            -- Start the removal timer
            list_data.finished_timer = 0
        end
    elseif not any_entry_scrolling and list_data.state == self.states.scrolling then
        list_data.state = self.states.waiting
    end
end

function ScrollingSpriteList:updateFinishedList(player_id, list_id, list_data, delta)
    local config = list_data.config
    
    if config.destroy_when_finished and list_data.all_finished then
        list_data.finished_timer = list_data.finished_timer + delta
        
        if list_data.finished_timer >= config.destroy_delay then
            -- Mark for removal (will be removed in next update cycle)
            list_data.marked_for_removal = true
        end
    end
end

function ScrollingSpriteList:addSpriteToList(player_id, list_id, sprite_def)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    local config = list_data.config
    
    -- If list was marked as finished, reset its state
    if list_data.state == self.states.finished then
        list_data.state = self.states.waiting
        list_data.all_finished = false
        list_data.finished_timer = 0
        list_data.marked_for_removal = false
    end
    
    -- Add new sprite
    table.insert(config.sprites, sprite_def)
    
    -- Reinitialize the grid with the new sprite
    self:initializeSpriteGrid(config)
    
    return true
end

function ScrollingSpriteList:setListSprites(player_id, list_id, sprites)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    -- Clear current displays
    for _, entry_state in ipairs(list_data.config.entry_states) do
        self:clearEntryDisplay(player_id, entry_state)
    end
    
    -- Reset list
    list_data.config.sprites = sprites or {}
    list_data.config.entry_states = {}
    list_data.state = self.states.waiting
    list_data.start_time = os.clock()
    list_data.all_finished = false
    list_data.finished_timer = 0
    list_data.marked_for_removal = false
    
    -- Initialize new entry states with grid layout
    self:initializeSpriteGrid(list_data.config)
    
    -- Start first entry if no delay
    if #list_data.config.sprites > 0 and list_data.config.entry_delay <= 0 then
        list_data.config.entry_states[1].state = "scrolling"
        list_data.state = self.states.scrolling
        self:drawListEntry(player_id, list_id, 1, list_data)
    end
    
    return true
end

function ScrollingSpriteList:getListState(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return nil end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return nil end
    
    local active_entries = 0
    for _, entry_state in ipairs(list_data.config.entry_states) do
        if entry_state.state == "scrolling" then
            active_entries = active_entries + 1
        end
    end
    
    return {
        state = list_data.state,
        all_finished = list_data.all_finished,
        total_entries = #list_data.config.sprites,
        active_entries = active_entries,
        marked_for_removal = list_data.marked_for_removal
    }
end

function ScrollingSpriteList:pauseList(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.paused = true
    return true
end

function ScrollingSpriteList:resumeList(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.paused = false
    return true
end

function ScrollingSpriteList:setListSpeed(player_id, list_id, speed)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.config.scroll_speed = speed or self.default_config.scroll_speed
    return true
end

function ScrollingSpriteList:removeScrollingList(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return end
    
    -- Clear all entry displays
    for _, entry_state in ipairs(list_data.config.entry_states) do
        self:clearEntryDisplay(player_id, entry_state)
    end
    
    -- Remove backdrop
    if list_data.backdrop_id then
        Net.player_erase_sprite(player_id, list_data.backdrop_id)
    end
    
    player_data.active_lists[list_id] = nil
end

function ScrollingSpriteList:setListPosition(player_id, list_id, x, y)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    local config = list_data.config
    
    -- Update position
    config.x = x
    config.y = y
    
    -- Update bounds if no backdrop
    if not config.backdrop then
        config.bounds_left = x
        config.bounds_top = y
        config.bounds_right = x + config.width
        config.bounds_bottom = y + config.height
    end
    
    -- Update backdrop position if exists
    if list_data.backdrop_id and config.backdrop then
        Net.player_erase_sprite(player_id, list_data.backdrop_id)
        list_data.backdrop_id = self:drawListBackdrop(player_id, list_id, config)
    end
    
    -- Reinitialize grid with new positions
    self:initializeSpriteGrid(config)
    
    -- Redraw all active entries at new positions
    for i, entry_state in ipairs(config.entry_states) do
        if entry_state.state == "scrolling" then
            self:drawListEntry(player_id, list_id, i, list_data)
        end
    end
    
    return true
end
-- Initialize the scrolling sprite list system
local scrollingSpriteListSystem = setmetatable({}, ScrollingSpriteList)
scrollingSpriteListSystem:init()

return scrollingSpriteListSystem