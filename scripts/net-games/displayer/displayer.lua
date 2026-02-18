-- Displayer API - Unified Interface for Timer and Text Display Systems
-- Version 1.2 - Complete Method Implementation
local Displayer = {}
Displayer.__index = Displayer
function Displayer:init()
    -- Initialize sub-APIs first (as empty tables)
    self.Timer = {}
    self.TimerDisplay = {}
    self.Text = {}
    self.Font = {}
    self.ScrollingText = {}
    self.ScrollingSprite = {} 
    
    -- Load all subsystems with error handling
    local success, err = pcall(function()
        self._subsystems = {
            TimerSystem = require("scripts/net-games/displayer/timer-system"),
            TimerDisplaySystem = require("scripts/net-games/displayer/timer-display"),
            TextDisplaySystem = require("scripts/net-games/displayer/text-display"),
            FontSystem = require("scripts/net-games/displayer/font-system"),
            ScrollingTextListSystem = require("scripts/net-games/displayer/scrolling-text-list"),
            ScrollingSpriteListSystem = require("scripts/net-games/displayer/scrolling-sprite-list") 
        }
        
        -- Initialize subsystems
        for name, subsystem in pairs(self._subsystems) do
            if subsystem and subsystem.init then
                local subsystem_success, subsystem_err = pcall(function()
                    subsystem:init()
                end)
                if not subsystem_success then
                    print("WARNING: Failed to initialize " .. name .. ": " .. tostring(subsystem_err))
                end
            end
        end
    end)

    if not success then
        print("Error loading Displayer subsystems: " .. tostring(err))
        -- Don't return nil, just continue with limited functionality
    end
    
    -- Set up sub-APIs with proper access to main instance
    self:_setupSubAPIs()
    
    --print("Displayer API v1.2 initialized successfully!")
    return self
end

-- Internal helper function for safe subsystem access
function Displayer:_getSubsystem(name, method)
    if not self._subsystems then
        print("ERROR: Displayer not properly initialized")
        return nil
    end
    
    local subsystem = self._subsystems[name]
    if not subsystem then
        print("ERROR: Subsystem '" .. name .. "' not available")
        return nil
    end
    
    if method and not subsystem[method] then
        print("ERROR: Method '" .. method .. "' not found in " .. name)
        return nil
    end
    
    return subsystem
end

-- Set up sub-APIs with access to main instance
function Displayer:_setupSubAPIs()
    local mainInstance = self
    
    -- Timer System API (new)

    self.Timer.pausePlayerTimer = function(player_id, timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "pausePlayerTimer")
        return subsystem:pausePlayerTimer(player_id, timer_id)
    end

    self.Timer.resumePlayerTimer = function(player_id, timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "resumePlayerTimer")
        return subsystem:resumePlayerTimer(player_id, timer_id)
    end

    self.Timer.pausePlayerCountdown = function(player_id, countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "pausePlayerCountdown")
        return subsystem:pausePlayerCountdown(player_id, countdown_id)
    end

    self.Timer.resumePlayerCountdown = function(player_id, countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "resumePlayerCountdown")
        return subsystem:resumePlayerCountdown(player_id, countdown_id)
    end

    self.Timer.removePlayerTimer = function(player_id, timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "removePlayerTimer")
       return subsystem:removePlayerTimer(player_id, timer_id)
    end

    self.Timer.removePlayerCountdown = function(player_id, countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "removePlayerCountdown")
        return subsystem:removePlayerCountdown(player_id, countdown_id)
    end


    -- Timer System API (original)

    self.Timer.createGlobalTimer = function(timer_id, duration, callback, loop)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "createGlobalTimer")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:createGlobalTimer(timer_id, duration or 0, callback, loop or false)
    end

    self.Timer.createGlobalCountdown = function(countdown_id, duration, callback, loop)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "createGlobalCountdown")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:createGlobalCountdown(countdown_id, duration or 0, callback, loop or false)
    end

    self.Timer.pauseGlobalTimer = function(timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "pauseGlobalTimer")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:pauseGlobalTimer(timer_id)
    end

    self.Timer.resumeGlobalTimer = function(timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "resumeGlobalTimer")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:resumeGlobalTimer(timer_id)
    end

    self.Timer.pauseGlobalCountdown = function(countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "pauseGlobalCountdown")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:pauseGlobalCountdown(countdown_id)
    end

    self.Timer.resumeGlobalCountdown = function(countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "resumeGlobalCountdown")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:resumeGlobalCountdown(countdown_id)
    end

    self.Timer.removeGlobalTimer = function(timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "removeGlobalTimer")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:removeGlobalTimer(timer_id)
    end

    self.Timer.removeGlobalCountdown = function(countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "removeGlobalCountdown")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:removeGlobalCountdown(countdown_id)
    end

    self.Timer.getGlobalTimer = function(timer_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "getGlobalTimer")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return 0 
        end
        return subsystem:getGlobalTimer(timer_id) or 0
    end

    self.Timer.getGlobalCountdown = function(countdown_id)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "getGlobalCountdown")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return 0 
        end
        return subsystem:getGlobalCountdown(countdown_id) or 0
    end

    self.Timer.getAllGlobalTimers = function()
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "getAllGlobalTimers")
        return subsystem and subsystem:getAllGlobalTimers() or {}
    end

    self.Timer.getAllGlobalCountdowns = function()
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "getAllGlobalCountdowns")
        return subsystem and subsystem:getAllGlobalCountdowns() or {}
    end

    self.Timer.clearAllGlobalTimers = function()
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "clearAllGlobalTimers")
        return subsystem and subsystem:clearAllGlobalTimers()
    end

    self.Timer.clearAllGlobalCountdowns = function()
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "clearAllGlobalCountdowns")
        return subsystem and subsystem:clearAllGlobalCountdowns()
    end

    self.Timer.createPlayerTimer = function(player_id, timer_id, duration, callback, loop)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "createPlayerTimer")
        if not subsystem or not player_id or not timer_id then 
            print("Error: player_id and timer_id are required")
            return nil 
        end
        return subsystem:createPlayerTimer(player_id, timer_id, duration or 0, callback, loop or false)
    end

    self.Timer.createPlayerCountdown = function(player_id, countdown_id, duration, callback, loop)
        local subsystem = mainInstance:_getSubsystem("TimerSystem", "createPlayerCountdown")
        if not subsystem or not player_id or not countdown_id then 
            print("Error: player_id and countdown_id are required")
            return nil 
        end
        return subsystem:createPlayerCountdown(player_id, countdown_id, duration or 0, callback, loop or false)
    end

    -- Timer Display API
    self.TimerDisplay.createPlayerTimerDisplay = function(player_id, timer_id, x, y, config_name)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "createPlayerTimerDisplay")
        if not subsystem or not player_id or not timer_id then 
            print("Error: player_id and timer_id are required")
            return nil 
        end
        return subsystem:createPlayerTimerDisplay(player_id, timer_id, x or 0, y or 0, config_name or "default")
    end

    self.TimerDisplay.createPlayerCountdownDisplay = function(player_id, countdown_id, x, y, config_name)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "createPlayerCountdownDisplay")
        if not subsystem or not player_id or not countdown_id then 
            print("Error: player_id and countdown_id are required")
            return nil 
        end
        return subsystem:createPlayerCountdownDisplay(player_id, countdown_id, x or 0, y or 0, config_name or "default")
    end

    self.TimerDisplay.updatePlayerTimerDisplay = function(player_id, timer_id, value)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "updatePlayerTimerDisplay")
        if not subsystem or not player_id or not timer_id then 
            print("Error: player_id and timer_id are required")
            return nil 
        end
        return subsystem:updatePlayerTimerDisplay(player_id, timer_id, value or 0)
    end

    self.TimerDisplay.updatePlayerCountdownDisplay = function(player_id, countdown_id, value)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "updatePlayerCountdownDisplay")
        if not subsystem or not player_id or not countdown_id then 
            print("Error: player_id and countdown_id are required")
            return nil 
        end
        return subsystem:updatePlayerCountdownDisplay(player_id, countdown_id, value or 0)
    end

    self.TimerDisplay.removePlayerDisplay = function(player_id, display_id)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "removePlayerDisplay")
        if not subsystem or not player_id or not display_id then 
            print("Error: player_id and display_id are required")
            return nil 
        end
        return subsystem:removePlayerDisplay(player_id, display_id)
    end

    self.TimerDisplay.setDisplayPosition = function(player_id, display_id, x, y)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "setDisplayPosition")
        if not subsystem or not player_id or not display_id then 
            print("Error: player_id and display_id are required")
            return nil 
        end
        return subsystem:setDisplayPosition(player_id, display_id, x or 0, y or 0)
    end

    self.TimerDisplay.createGlobalTimerDisplay = function(timer_id, x, y, config_name)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "createGlobalTimerDisplay")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:createGlobalTimerDisplay(timer_id, x or 0, y or 0, config_name or "default")
    end

    self.TimerDisplay.createGlobalCountdownDisplay = function(countdown_id, x, y, config_name)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "createGlobalCountdownDisplay")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:createGlobalCountdownDisplay(countdown_id, x or 0, y or 0, config_name or "default")
    end

    self.TimerDisplay.updateGlobalTimerDisplay = function(timer_id, value)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "updateGlobalTimerDisplay")
        if not subsystem or not timer_id then 
            print("Error: timer_id is required")
            return nil 
        end
        return subsystem:updateGlobalTimerDisplay(timer_id, value or 0)
    end

    self.TimerDisplay.updateGlobalCountdownDisplay = function(countdown_id, value)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "updateGlobalCountdownDisplay")
        if not subsystem or not countdown_id then 
            print("Error: countdown_id is required")
            return nil 
        end
        return subsystem:updateGlobalCountdownDisplay(countdown_id, value or 0)
    end

    self.TimerDisplay.removeGlobalDisplay = function(display_id)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "removeGlobalDisplay")
        if not subsystem or not display_id then 
            print("Error: display_id is required")
            return nil 
        end
        return subsystem:removeGlobalDisplay(display_id)
    end

    self.TimerDisplay.setGlobalDisplayPosition = function(display_id, x, y)
        local subsystem = mainInstance:_getSubsystem("TimerDisplaySystem", "setGlobalDisplayPosition")
        if not subsystem or not display_id then 
            print("Error: display_id is required")
            return nil 
        end
        return subsystem:setGlobalDisplayPosition(display_id, x or 0, y or 0)
    end

    -- Text Display API
    self.Text.drawText = function(player_id, text_id, text, x, y, z_order, font_name, scale)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "drawText")
        if not subsystem or not player_id or not text then 
            print("Error: player_id and text are required...")
            return nil 
        end
        return subsystem:drawText(player_id, text_id, text, x or 0, y or 0, z_order or 100, font_name or "THICK", scale or 2.0)
    end

    self.Text.updateText = function(player_id, text_id, new_text)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "updateText")
        if not subsystem or not player_id or not text_id or not new_text then 
            print("Error: player_id, text_id and new_text are required")
            return nil 
        end
        return subsystem:updateText(player_id, text_id, new_text)
    end

    self.Text.removeText = function(player_id, text_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "removeText")
        if not subsystem or not player_id or not text_id then 
            print("Error: player_id and text_id are required")
            return nil 
        end
        return subsystem:removeText(player_id, text_id)
    end

    self.Text.setTextPosition = function(player_id, text_id, x, y)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "setTextPosition")
        if not subsystem or not player_id or not text_id then 
            print("Error: player_id and text_id are required")
            return nil 
        end
        return subsystem:setTextPosition(player_id, text_id, x or 0, y or 0)
    end

    self.Text.drawMarqueeText = function(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "drawMarqueeText")
        if not subsystem or not player_id or not marquee_id or not text then 
            print("Error: player_id, marquee_id and text are required")
            return nil 
        end
        return subsystem:drawMarqueeText(
            player_id, 
            marquee_id, 
            text, 
            y or 0, 
            font_name or "THICK", 
            scale or 2.0, 
            z_order or 100, 
            speed or "medium", 
            backdrop
        )
    end

    self.Text.setMarqueeSpeed = function(player_id, text_id, speed)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "setMarqueeSpeed")
        if not subsystem or not player_id or not text_id then 
            print("Error: player_id and text_id are required")
            return nil 
        end
        return subsystem:setMarqueeSpeed(player_id, text_id, speed)
    end

    self.Text.createTextBox = function(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "createTextBox")
        if not subsystem or not player_id or not box_id or not text then 
            print("Error: player_id, box_id and text are required")
            return nil 
        end

        return subsystem:createTextBox(
            player_id,
            box_id,
            text,
            x or 0,
            y or 0,
            width or 200,
            height or 100,
            font_name or "THICK",
            scale or 2.0,
            z_order or 100,
            backdrop_config,
            speed or 30,
            opts or nil
        )
    end

    self.Text.resetTextBox = function(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "resetTextBox")
        if not subsystem or not player_id or not box_id or text == nil then
            print("Error: player_id, box_id and text are required")
            return nil
        end

        return subsystem:resetTextBox(
            player_id,
            box_id,
            text,
            x or 0,
            y or 0,
            width or 200,
            height or 100,
            font_name or "THICK",
            scale or 2.0,
            z_order or 100,
            backdrop_config,
            speed or 30,
            opts or nil
        )
    end

    -- snake_case alias
    if self.Text.resetTextBox and not self.Text.reset_text_box then
      self.Text.reset_text_box = function(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
        return self.Text.resetTextBox(
          player_id,
          box_id,
          text,
          x, y, width, height,
          font_name, scale, z_order,
          backdrop_config,
          speed,
          opts
        )
      end
    end



    self.Text.getTextBoxData = function(player_id, box_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "getTextBoxData")
        return subsystem:getTextBoxData(player_id, box_id)
    end

    self.Text.advanceTextBox = function(player_id, box_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "advanceTextBox")
        if not subsystem or not player_id or not box_id then 
            print("Error: player_id and box_id are required")
            return nil 
        end
        return subsystem:advanceTextBox(player_id, box_id)
    end

    -- =====================================================
    -- Compatibility + documentation-friendly snake_case API
    -- (Additive: does not change existing methods)
    -- =====================================================

    -- create_text_box(box_id, player_id, ...)
    if self.Text.createTextBox and not self.Text.create_text_box then
      self.Text.create_text_box = function(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
        return self.Text.createTextBox(
          player_id,
          box_id,
          text,
          x, y, width, height,
          font_name,
          scale,
          z_order,
          backdrop_config,
          speed,
          opts
        )
      end
    end

    -- advance_text_box(player_id, box_id)
    if self.Text.advanceTextBox and not self.Text.advance_text_box then
      self.Text.advance_text_box = function(player_id, box_id)
        return self.Text.advanceTextBox(player_id, box_id)
      end
    end


    self.Text.removeTextBox = function(player_id, box_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "removeTextBox")
        if not subsystem or not player_id or not box_id then 
            print("Error: player_id and box_id are required")
            return nil 
        end
        return subsystem:removeTextBox(player_id, box_id)
    end

    -- Soft-close (plays close animation, then removes later)
    self.Text.closeTextBox = function(player_id, box_id, opts)
      local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "closeTextBox")
      if not subsystem or not player_id or not box_id then
        print("Error: player_id and box_id are required")
        return nil
      end
      return subsystem:closeTextBox(player_id, box_id, opts)
    end


    self.Text.isTextBoxCompleted = function(player_id, box_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "isTextBoxCompleted")
        if not subsystem or not player_id or not box_id then 
            print("Error: player_id and box_id are required")
            return false 
        end
        return subsystem:isTextBoxCompleted(player_id, box_id) or false
    end

    self.Text.getTextBoxState = function(player_id, box_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "getTextBoxState")
        if not subsystem or not player_id or not box_id then
           print("Error: player_id and box_id are required")
           return "completed"
        end
    return subsystem:getTextBoxState(player_id, box_id) or "completed"
    end

    self.Text.setTextBoxPosition = function(player_id, box_id, x, y)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "setTextBoxPosition")
        if not subsystem or not player_id or not box_id then 
            print("Error: player_id and box_id are required")
            return nil 
        end
        return subsystem:setTextBoxPosition(player_id, box_id, x or 0, y or 0)
    end

    self.Text.addBackdrop = function(player_id, text_id, backdrop_config)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "addBackdrop")
        if not subsystem or not player_id or not text_id or not backdrop_config then 
            print("Error: player_id, text_id and backdrop_config are required")
            return nil 
        end
        return subsystem:addBackdrop(player_id, text_id, backdrop_config)
    end

    self.Text.removeBackdrop = function(player_id, text_id)
        local subsystem = mainInstance:_getSubsystem("TextDisplaySystem", "removeBackdrop")
        if not subsystem or not player_id or not text_id then 
            print("Error: player_id and text_id are required")
            return nil 
        end
        return subsystem:removeBackdrop(player_id, text_id)
    end

    -- Font System API
    self.Font.drawTextWithId = function(player_id, text, x, y, font_name, scale, z_order, display_id)
        local subsystem = mainInstance:_getSubsystem("FontSystem", "drawTextWithId")
        if not subsystem or not player_id or not text or not display_id then 
            print("Error: player_id, text and display_id are required")
            return nil 
        end
        return subsystem:drawTextWithId(player_id, text, x or 0, y or 0, font_name or "THICK", scale or 2.0, z_order or 100, display_id)
    end

    self.Font.drawText = function(player_id, text_id, text, x, y, z_order, font_name, scale)
        local subsystem = mainInstance:_getSubsystem("FontSystem", "drawText")
        if not subsystem or not player_id or not text then 
            print("Error: player_id and text are required")
            return nil 
        end
        return subsystem:drawText(player_id, text_id, text, x or 0, y or 0, z_order or 100, font_name or "THICK", scale or 2.0)
    end

    self.Font.eraseTextDisplay = function(player_id, display_id)
        local subsystem = mainInstance:_getSubsystem("FontSystem", "eraseTextDisplay")
        if not subsystem or not player_id or not display_id then 
            print("Error: player_id and display_id are required")
            return nil 
        end
        return subsystem:eraseTextDisplay(player_id, display_id)
    end

    self.Font.getTextWidth = function(text, font_name, scale)
        local subsystem = mainInstance:_getSubsystem("FontSystem", "getTextWidth")
        if not subsystem or not text then 
            print("Error: text is required")
            return 0 
        end
        return subsystem:getTextWidth(text, font_name or "THICK", scale or 2.0) or 0
    end

    -- Scrolling Text List System API
    self.ScrollingText.createList = function(player_id, list_id, x, y, width, height, config)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "createScrollingList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return nil 
        end
        return subsystem:createScrollingList(player_id, list_id, x or 0, y or 0, width or 200, height or 100, config or {})
    end

    self.ScrollingText.addText = function(player_id, list_id, text)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "addTextToList")
        if not subsystem or not player_id or not list_id or not text then 
            print("Error: player_id, list_id and text are required")
            return false 
        end
        return subsystem:addTextToList(player_id, list_id, text)
    end

    self.ScrollingText.setTexts = function(player_id, list_id, texts)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "setListTexts")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:setListTexts(player_id, list_id, texts or {})
    end

    self.ScrollingText.getState = function(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "getListState")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return nil 
        end
        return subsystem:getListState(player_id, list_id)
    end

    self.ScrollingText.pause = function(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "pauseList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:pauseList(player_id, list_id)
    end

    self.ScrollingText.resume = function(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "resumeList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:resumeList(player_id, list_id)
    end

    self.ScrollingText.setSpeed = function(player_id, list_id, speed)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "setListSpeed")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        speed = speed or 30
        return subsystem:setListSpeed(player_id, list_id, speed)
    end

    self.ScrollingText.removeList = function(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "removeScrollingList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return nil 
        end
        return subsystem:removeScrollingList(player_id, list_id)
    end

    self.ScrollingText.setPosition = function(player_id, list_id, x, y)
        local subsystem = mainInstance:_getSubsystem("ScrollingTextListSystem", "setListPosition")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        x = x or 0
        y = y or 0
        return subsystem:setListPosition(player_id, list_id, x, y)
    end

      -- Scrolling Sprite List System API
    self.ScrollingSprite = {}
   -- Change it to this (swap player_id and list_id):
function self.ScrollingSprite:createList(list_id, player_id, x, y, width, height, config)
    local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "createScrollingList")
    if not subsystem or not player_id or not list_id then 
        print("Error: player_id and list_id are required")
        return nil 
    end
    return subsystem:createScrollingList(player_id, list_id, x or 0, y or 0, width or 200, height or 100, config or {})
end

    function self.ScrollingSprite:addSprite(player_id, list_id, sprite_def)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "addSpriteToList")
        if not subsystem or not player_id or not list_id or not sprite_def then 
            print("Error: player_id, list_id and sprite_def are required")
            return false 
        end
        return subsystem:addSpriteToList(player_id, list_id, sprite_def)
    end

    function self.ScrollingSprite:setSprites(player_id, list_id, sprites)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "setListSprites")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:setListSprites(player_id, list_id, sprites or {})
    end

    function self.ScrollingSprite:getState(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "getListState")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return nil 
        end
        return subsystem:getListState(player_id, list_id)
    end

    function self.ScrollingSprite:pause(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "pauseList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:pauseList(player_id, list_id)
    end

    function self.ScrollingSprite:resume(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "resumeList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        return subsystem:resumeList(player_id, list_id)
    end

    function self.ScrollingSprite:setSpeed(player_id, list_id, speed)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "setListSpeed")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        speed = speed or 30
        return subsystem:setListSpeed(player_id, list_id, speed)
    end

    function self.ScrollingSprite:removeList(player_id, list_id)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "removeScrollingList")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return nil 
        end
        return subsystem:removeScrollingList(player_id, list_id)
    end

    function self.ScrollingSprite:setPosition(player_id, list_id, x, y)
        local subsystem = mainInstance:_getSubsystem("ScrollingSpriteListSystem", "setListPosition")
        if not subsystem or not player_id or not list_id then 
            print("Error: player_id and list_id are required")
            return false 
        end
        x = x or 0
        y = y or 0
        return subsystem:setListPosition(player_id, list_id, x, y)
    end
end

-- Utility Functions
function Displayer:getScreenDimensions()
    local subsystem = self:_getSubsystem("TextDisplaySystem", "getScreenDimensions")
    return subsystem and subsystem:getScreenDimensions() or 240, 160
end

function Displayer:formatTime(seconds, is_countdown)
    seconds = seconds or 0
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

function Displayer:hidePlayerHUD(player_id)
    if not player_id then 
        print("Error: player_id is required")
        return 
    end
    if Net and Net.toggle_player_hud then
        Net.toggle_player_hud(player_id)
    end
end

function Displayer:isValid()
    return self._subsystems ~= nil
end

-- Quick setup function
function Displayer:quickSetup(player_id, options)
    if not player_id then 
        print("Error: player_id is required")
        return false
    end
    
    options = options or {}
    --self:hidePlayerHUD(player_id)
    
    -- Create common UI elements
    if options.show_global_timer then
        self.TimerDisplay.createGlobalTimerDisplay("global_timer", 10, 10, "default")
    end
    
    if options.show_player_timers then
        self.TimerDisplay.createPlayerTimerDisplay(player_id, "player_timer", 10, 50, "default")
        self.TimerDisplay.createPlayerCountdownDisplay(player_id, "player_countdown", 10, 70, "default")
    end
    
    return true
end

-- Export the API
local displayerInstance = setmetatable({}, Displayer)
return displayerInstance
