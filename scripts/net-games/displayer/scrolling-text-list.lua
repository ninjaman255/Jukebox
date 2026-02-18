-- Scrolling Text List System - Vertical text scroller for multiple strings
ScrollingTextList = {}
ScrollingTextList.__index = ScrollingTextList

function ScrollingTextList:init()
    self.player_lists = {}
    self.font_system = require("scripts/net-games/displayer/font-system")
    
    -- Default configurations
    self.default_config = {
        font = "THICK",
        scale = 1.0,
        z_order = 100,
        scroll_speed = 30, -- pixels per second
        line_spacing = 15, -- pixels between lines
        entry_delay = 1.0, -- seconds between entries starting to scroll
        loop = false,
        destroy_when_finished = true,
        destroy_delay = 1.0 -- seconds to wait before auto-removal
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
    
    -- Update scrolling lists every tick
    Net:on("tick", function(event)
        self:updateScrollingLists(event.delta_time)
    end)
    
    return self
end

function ScrollingTextList:setupPlayerLists(player_id)
    self.player_lists[player_id] = {
        active_lists = {},
        next_list_id = 1
    }
end

function ScrollingTextList:cleanupPlayerLists(player_id)
    local player_data = self.player_lists[player_id]
    if player_data then
        for list_id, list_data in pairs(player_data.active_lists) do
            self:removeScrollingList(player_id, list_id)
        end
        self.player_lists[player_id] = nil
    end
end

function ScrollingTextList:createScrollingList(player_id, list_id, x, y, width, height, config)
    config = config or {}
    
    local player_data = self.player_lists[player_id]
    if not player_data then return nil end
    
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
    list_config.texts = config.texts or {}
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
    
    -- Initialize entry states
    for i, text in ipairs(list_config.texts) do
        list_config.entry_states[i] = {
            text = text,
            y_offset = 0,
            state = "waiting", -- waiting, scrolling, finished
            display_objects = {},
            start_delay = (i - 1) * list_config.entry_delay,
            timer = 0
        }
    end
    
    local list_data = {
        config = list_config,
        backdrop_id = nil,
        state = self.states.waiting,
        start_time = os.clock(),
        all_finished = false,
        finished_timer = 0, -- Track time since finished for auto-removal
        marked_for_removal = false
    }
    
    -- Draw backdrop if specified
    if list_config.backdrop then
        list_data.backdrop_id = self:drawListBackdrop(player_id, list_id, list_config)
    end
    
    player_data.active_lists[list_id] = list_data
    
    -- Start the first entry immediately if no delay
    if #list_config.texts > 0 and list_config.entry_delay <= 0 then
        list_config.entry_states[1].state = "scrolling"
        list_data.state = self.states.scrolling
        self:drawListEntry(player_id, list_id, 1, list_data)
    end
    
    return list_id
end

function ScrollingTextList:drawListBackdrop(player_id, list_id, config)
    local backdrop_id = list_id .. "_backdrop"
    
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

-- FIXED: Use direct font system drawing instead of relying on display IDs that might conflict
function ScrollingTextList:drawListEntry(player_id, list_id, entry_index, list_data)
    local config = list_data.config
    local entry_state = config.entry_states[entry_index]
    
    -- Clear previous display objects
    self:clearEntryDisplay(player_id, entry_state)
    
    -- Calculate text position (centered horizontally, positioned vertically by y_offset)
    local text_width = self.font_system:getTextWidth(entry_state.text, config.font, config.scale)
    local text_x = config.bounds_left + (config.bounds_width - text_width) / 2
    local text_y = config.bounds_bottom + entry_state.y_offset
    
    -- Only draw if within visible bounds
    if text_y + (10 * config.scale) >= config.bounds_top and text_y <= config.bounds_bottom then
        -- Use a unique ID for this specific entry to avoid conflicts
        local unique_display_id = list_id .. "_entry_" .. entry_index
        
        local display_id = self.font_system:drawText(
            player_id,
            nil,
            entry_state.text,
            text_x,
            text_y,
            config.font,
            config.scale,
            config.z_order
        )
        
        table.insert(entry_state.display_objects, {
            type = "text",
            id = display_id,
            unique_id = unique_display_id
        })
    end
end

function ScrollingTextList:clearEntryDisplay(player_id, entry_state)
    for _, display_obj in ipairs(entry_state.display_objects) do
        if display_obj.type == "text" then
            self.font_system:eraseTextDisplay(player_id, display_obj.id)
        end
    end
    entry_state.display_objects = {}
end

function ScrollingTextList:updateScrollingLists(delta)
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

function ScrollingTextList:updateScrollingList(player_id, list_id, list_data, delta)
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
            local text_height = 10 * config.scale -- Approximate text height
            if entry_state.y_offset + config.bounds_bottom + text_height < config.bounds_top then
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
            -- Start the removal timer instead of using non-existent Net:create_timer
            list_data.finished_timer = 0
        end
    elseif not any_entry_scrolling and list_data.state == self.states.scrolling then
        list_data.state = self.states.waiting
    end
end

function ScrollingTextList:updateFinishedList(player_id, list_id, list_data, delta)
    local config = list_data.config
    
    if config.destroy_when_finished and list_data.all_finished then
        list_data.finished_timer = list_data.finished_timer + delta
        
        if list_data.finished_timer >= config.destroy_delay then
            -- Mark for removal (will be removed in next update cycle)
            list_data.marked_for_removal = true
        end
    end
end

function ScrollingTextList:addTextToList(player_id, list_id, text)
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
    
    -- Calculate start delay based on current list state
    local start_delay = 0
    if #config.entry_states > 0 then
        local last_entry = config.entry_states[#config.entry_states]
        start_delay = last_entry.start_delay + config.entry_delay
    end
    
    local new_index = #config.entry_states + 1
    
    config.entry_states[new_index] = {
        text = text,
        y_offset = 0,
        state = "waiting",
        display_objects = {},
        start_delay = start_delay,
        timer = 0
    }
    
    -- Update the texts array as well
    table.insert(config.texts, text)
    
    return true
end

function ScrollingTextList:setListTexts(player_id, list_id, texts)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    -- Clear current displays
    for _, entry_state in ipairs(list_data.config.entry_states) do
        self:clearEntryDisplay(player_id, entry_state)
    end
    
    -- Reset list
    list_data.config.texts = texts or {}
    list_data.config.entry_states = {}
    list_data.state = self.states.waiting
    list_data.start_time = os.clock()
    list_data.all_finished = false
    list_data.finished_timer = 0
    list_data.marked_for_removal = false
    
    -- Initialize new entry states
    for i, text in ipairs(list_data.config.texts) do
        list_data.config.entry_states[i] = {
            text = text,
            y_offset = 0,
            state = "waiting",
            display_objects = {},
            start_delay = (i - 1) * list_data.config.entry_delay,
            timer = 0
        }
    end
    
    -- Start first entry if no delay
    if #list_data.config.texts > 0 and list_data.config.entry_delay <= 0 then
        list_data.config.entry_states[1].state = "scrolling"
        list_data.state = self.states.scrolling
        self:drawListEntry(player_id, list_id, 1, list_data)
    end
    
    return true
end

function ScrollingTextList:getListState(player_id, list_id)
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
        total_entries = #list_data.config.texts,
        active_entries = active_entries,
        marked_for_removal = list_data.marked_for_removal
    }
end

function ScrollingTextList:pauseList(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.paused = true
    return true
end

function ScrollingTextList:resumeList(player_id, list_id)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.paused = false
    return true
end

function ScrollingTextList:setListSpeed(player_id, list_id, speed)
    local player_data = self.player_lists[player_id]
    if not player_data then return false end
    
    local list_data = player_data.active_lists[list_id]
    if not list_data then return false end
    
    list_data.config.scroll_speed = speed or self.default_config.scroll_speed
    return true
end

function ScrollingTextList:removeScrollingList(player_id, list_id)
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

function ScrollingTextList:setListPosition(player_id, list_id, x, y)
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
    
    -- Redraw all active entries at new positions
    for i, entry_state in ipairs(config.entry_states) do
        if entry_state.state == "scrolling" then
            self:drawListEntry(player_id, list_id, i, list_data)
        end
    end
    
    return true
end

-- Initialize the scrolling text list system
local scrollingTextListSystem = setmetatable({}, ScrollingTextList)
scrollingTextListSystem:init()

return scrollingTextListSystem