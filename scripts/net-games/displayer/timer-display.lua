-- Timer Display System (Following example_sprites pattern)
TimerDisplay = {}
TimerDisplay.__index = TimerDisplay

function TimerDisplay:init()
    self.player_displays = {}
    self.global_displays = {}
    self.font_system = require("scripts/net-games/displayer/font-system")
    
    -- Use very high base IDs for timer displays to avoid conflicts
    self.timer_sprite_base_id = 10000
    
    self.display_configs = {
        default = {
            font = "THICK",
            scale = 2.0,
            z_order = 100
        },
        large = {
            font = "BATTLE", 
            scale = 1.5,
            z_order = 100
        },
        gradient = {
            font = "GRADIENT",
            scale = 1.2,
            z_order = 100
        },
        small = {
            font = "THICK",
            scale = 0.8,
            z_order = 100
        }
    }
    
    Net:on("player_join", function(event)
        self:setupPlayerDisplays(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerDisplays(event.player_id)
    end)
    
    -- Listen for timer system events
    self:setupTimerEventHandlers()
    
    return self
end

function TimerDisplay:setupTimerEventHandlers()
    -- Global timer events
    Net:on("timer_global_create", function(event)
        self:handleGlobalTimerCreate(event)
    end)
    
    Net:on("countdown_global_create", function(event)
        self:handleGlobalCountdownCreate(event)
    end)
    
    Net:on("countdown_global_update", function(event)
        self:updateGlobalCountdownDisplay(event.countdown_id, event.current)
    end)
    
    Net:on("timer_global_update", function(event)
        self:updateGlobalTimerDisplay(event.timer_id, event.current)
    end)
    
    Net:on("timer_global_remove", function(event)
        self:removeGlobalDisplay(event.timer_id)
    end)
    
    Net:on("countdown_global_remove", function(event)
        self:removeGlobalDisplay(event.countdown_id)
    end)
    
    -- Player-specific timer events - FIXED: Extract player_id from event data
    Net:on("timer_update", function(event)
        if event.player_id then
            self:updatePlayerTimerDisplay(event.player_id, event.timer_id, event.current)
        end
    end)
    
    Net:on("countdown_update", function(event)
        if event.player_id then
            self:updatePlayerCountdownDisplay(event.player_id, event.countdown_id, event.current)
        end
    end)
    
    Net:on("timer_create", function(event)
        -- We don't need to do anything special here since displays are created manually
        print("Timer created: " .. (event.timer_id or "unknown") .. " for player " .. (event.player_id or "unknown"))
    end)
    
    Net:on("countdown_create", function(event)
        -- We don't need to do anything special here since displays are created manually
        print("Countdown created: " .. (event.countdown_id or "unknown") .. " for player " .. (event.player_id or "unknown"))
    end)
    
    Net:on("timer_remove", function(event)
        if event.player_id then
            self:removePlayerDisplay(event.player_id, event.timer_id)
        end
    end)
    
    Net:on("countdown_remove", function(event)
        if event.player_id then
            self:removePlayerDisplay(event.player_id, event.countdown_id)
        end
    end)
end

function TimerDisplay:setupPlayerDisplays(player_id)
    self.player_displays[player_id] = {
        active_displays = {}
    }
    
    -- Hide default HUD like in the example
    --Net.toggle_player_hud(player_id)
    
    -- Setup any existing global displays for this player
    self:setupExistingGlobalDisplays(player_id)
end

function TimerDisplay:setupExistingGlobalDisplays(player_id)
    for display_id, global_display in pairs(self.global_displays) do
        self:setupGlobalDisplayForPlayer(player_id, display_id)
    end
end

function TimerDisplay:cleanupPlayerDisplays(player_id)
    local player_data = self.player_displays[player_id]
    if player_data then
        for display_id, _ in pairs(player_data.active_displays) do
            self:removePlayerDisplay(player_id, display_id)
        end
        self.player_displays[player_id] = nil
    end
end

function TimerDisplay:createPlayerTimerDisplay(player_id, timer_id, x, y, config_name)
    local config = self.display_configs[config_name] or self.display_configs.default
    local display_data = {
        type = "timer",
        timer_id = timer_id,
        x = x,
        y = y,
        font = config.font,
        scale = config.scale,
        z_order = config.z_order,
        display_id = nil,
        current_value = 0
    }
    
    self.player_displays[player_id].active_displays[timer_id] = display_data
    self:updateDisplay(player_id, display_data, 0)
    return timer_id
end

function TimerDisplay:createPlayerCountdownDisplay(player_id, countdown_id, x, y, config_name)
    local config = self.display_configs[config_name] or self.display_configs.default
    local display_data = {
        type = "countdown", 
        countdown_id = countdown_id,
        x = x,
        y = y,
        font = config.font,
        scale = config.scale,
        z_order = config.z_order,
        display_id = nil,
        current_value = 0
    }
    
    self.player_displays[player_id].active_displays[countdown_id] = display_data
    self:updateDisplay(player_id, display_data, 0)
    return countdown_id
end

function TimerDisplay:createGlobalTimerDisplay(timer_id, x, y, config_name)
    local config = self.display_configs[config_name] or self.display_configs.default
    self.global_displays[timer_id] = {
        type = "timer",
        timer_id = timer_id,
        x = x,
        y = y,
        font = config.font,
        scale = config.scale,
        z_order = config.z_order
    }
    
    for player_id, _ in pairs(self.player_displays) do
        self:setupGlobalDisplayForPlayer(player_id, timer_id)
    end
    return timer_id
end

function TimerDisplay:createGlobalCountdownDisplay(countdown_id, x, y, config_name)
    local config = self.display_configs[config_name] or self.display_configs.default
    self.global_displays[countdown_id] = {
        type = "countdown",
        countdown_id = countdown_id,
        x = x,
        y = y,
        font = config.font,
        scale = config.scale,
        z_order = config.z_order
    }
    
    for player_id, _ in pairs(self.player_displays) do
        self:setupGlobalDisplayForPlayer(player_id, countdown_id)
    end
    return countdown_id
end

function TimerDisplay:setupGlobalDisplayForPlayer(player_id, display_id)
    local global_display = self.global_displays[display_id]
    if global_display then
        local display_data = {
            type = global_display.type,
            [global_display.type .. "_id"] = display_id,
            x = global_display.x,
            y = global_display.y,
            font = global_display.font,
            scale = global_display.scale,
            z_order = global_display.z_order,
            display_id = nil,
            current_value = 0
        }
        
        self.player_displays[player_id].active_displays[display_id] = display_data
        self:updateDisplay(player_id, display_data, 0)
    end
end

function TimerDisplay:handleGlobalTimerCreate(event)
    self:createGlobalTimerDisplay(event.timer_id, 100, 50, "default")
end

function TimerDisplay:handleGlobalCountdownCreate(event)
    self:createGlobalCountdownDisplay(event.countdown_id, 100, 80, "default")
end

function TimerDisplay:updatePlayerTimerDisplay(player_id, timer_id, value)
    local player_data = self.player_displays[player_id]
    if player_data then
        local display = player_data.active_displays[timer_id]
        if display and display.type == "timer" then
            self:updateDisplay(player_id, display, value)
        end
    end
end

function TimerDisplay:updatePlayerCountdownDisplay(player_id, countdown_id, value)
    local player_data = self.player_displays[player_id]
    if player_data then
        local display = player_data.active_displays[countdown_id]
        if display and display.type == "countdown" then
            self:updateDisplay(player_id, display, value)
        end
    end
end

function TimerDisplay:updateGlobalTimerDisplay(timer_id, value)
    for player_id, player_data in pairs(self.player_displays) do
        local display = player_data.active_displays[timer_id]
        if display and display.type == "timer" then
            self:updateDisplay(player_id, display, value)
        end
    end
end

function TimerDisplay:updateGlobalCountdownDisplay(countdown_id, value)
    for player_id, player_data in pairs(self.player_displays) do
        local display = player_data.active_displays[countdown_id]
        if display and display.type == "countdown" then
            self:updateDisplay(player_id, display, value)
        end
    end
end

function TimerDisplay:updateDisplay(player_id, display, value)
    -- Only update if value changed significantly
    if math.floor(display.current_value) == math.floor(value) and display.display_id ~= nil then
        return
    end
    
    display.current_value = value
    local display_string = self:formatTime(value, display.type == "countdown")
    
    -- Remove previous display if it exists
    if display.display_id then
        self.font_system:eraseTextDisplay(player_id, display.display_id)
    end
    
    -- Use high ID for timer displays to avoid conflicts with other systems
    local display_suffix = display.timer_id or display.countdown_id or "timer"
    local high_id_display_id = "timer_" .. self.timer_sprite_base_id .. "_" .. display_suffix
    
    -- Draw new display with high ID
    local new_display_id = self.font_system:drawTextWithId(
        player_id,
        display_string, 
        display.x, 
        display.y, 
        display.font, 
        display.scale,
        display.z_order,
        high_id_display_id  -- Pass the high ID to ensure no conflicts
    )
    display.display_id = new_display_id
end

function TimerDisplay:formatTime(seconds, is_countdown)
    if is_countdown then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d", mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    end
end

function TimerDisplay:removePlayerDisplay(player_id, display_id)
    local player_data = self.player_displays[player_id]
    if player_data then
        local display = player_data.active_displays[display_id]
        if display and display.display_id then
            self.font_system:eraseTextDisplay(player_id, display.display_id)
            player_data.active_displays[display_id] = nil
        end
    end
end

function TimerDisplay:removeGlobalDisplay(display_id)
    self.global_displays[display_id] = nil
    for player_id, player_data in pairs(self.player_displays) do
        self:removePlayerDisplay(player_id, display_id)
    end
end

function TimerDisplay:setDisplayPosition(player_id, display_id, x, y)
    local player_data = self.player_displays[player_id]
    if player_data then
        local display = player_data.active_displays[display_id]
        if display then
            display.x = x
            display.y = y
            self:updateDisplay(player_id, display, display.current_value)
        end
    end
end

function TimerDisplay:setGlobalDisplayPosition(display_id, x, y)
    local global_display = self.global_displays[display_id]
    if global_display then
        global_display.x = x
        global_display.y = y
        
        for player_id, player_data in pairs(self.player_displays) do
            local display = player_data.active_displays[display_id]
            if display then
                display.x = x
                display.y = y
                self:updateDisplay(player_id, display, display.current_value)
            end
        end
    end
end

function TimerDisplay:getTextWidth(text, font_name, scale)
    return self.font_system:getTextWidth(text, font_name, scale)
end

local timerDisplaySystem = setmetatable({}, TimerDisplay)
timerDisplaySystem:init()

return timerDisplaySystem