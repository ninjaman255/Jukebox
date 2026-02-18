-- Font System for Timer Display (Following example_sprites pattern)
FontSystem = {}
FontSystem.__index = FontSystem

function FontSystem:init()
    local COMP_TEX  = "/server/assets/net-games/fonts_compressed.png"
    local COMP_ANIM = "/server/assets/net-games/fonts_compressed.animation"
    local DARK_TEX  = "/server/assets/net-games/fonts_dark_compressed.png"
    local DARK_ANIM = "/server/assets/net-games/fonts_dark_compressed.animation"

    self.font_sprites = {
        -- Light
        THICK = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "THICK_0" },
        THIN  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "THIN_0" },
        WIDE  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "WIDE_0" },
        TINY  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "TINY_0" },
        BATTLE= { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "BATTLE_0" },

        GRADIENT        = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_0" },
        GRADIENT_GOLD   = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_GOLD_0" },
        GRADIENT_ORANGE = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_ORANGE_0" },
        GRADIENT_GREEN  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_GREEN_0" },
        GRADIENT_TALL   = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_TALL_0" },

        -- Dark
        THICK_BLACK = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "THICK_0" },
        THIN_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "THIN_0" },
        WIDE_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "WIDE_0" },
        TINY_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "TINY_0" },
        BATTLE_BLACK= { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "BATTLE_0" },

        GRADIENT_BLACK        = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_0" },
        GRADIENT_GOLD_BLACK   = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_GOLD_0" },
        GRADIENT_ORANGE_BLACK = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_ORANGE_0" },
        GRADIENT_GREEN_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_GREEN_0" },
        GRADIENT_TALL_BLACK   = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_TALL_0" },
    }

    
    -- Character width data for consistent spacing - FIXED: Now includes all common characters
    self.char_widths = {
        THICK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6, ["A"] = 6, ["B"] = 6, ["C"] = 6, ["D"] = 6,
            ["E"] = 6, ["F"] = 6, ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6,
            ["K"] = 6, ["L"] = 6, ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6,
            ["Q"] = 6, ["R"] = 6, ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6,
            ["W"] = 6, ["X"] = 6, ["Y"] = 6, ["Z"] = 6, ["a"] = 6, ["b"] = 6,
            ["c"] = 6, ["d"] = 6, ["e"] = 6, ["f"] = 6, ["g"] = 6, ["h"] = 6,
            ["i"] = 6, ["j"] = 6, ["k"] = 6, ["l"] = 6, ["m"] = 6, ["n"] = 6,
            ["o"] = 6, ["p"] = 6, ["q"] = 6, ["r"] = 6, ["s"] = 6, ["t"] = 6,
            ["u"] = 6, ["v"] = 6, ["w"] = 6, ["x"] = 6, ["y"] = 6, ["z"] = 6,
            ["!"] = 6, ["@"] = 6, ["#"] = 6, ["$"] = 6, ["%"] = 6, ["^"] = 6,
            ["&"] = 6, ["*"] = 6, ["("] = 6, [")"] = 6, ["_"] = 6, ["+"] = 6,
            ["="] = 6, ["["] = 6, ["]"] = 6, ["{"] = 6, ["}"] = 6, ["|"] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, [","] = 6, ["?"] = 6
        },
        GRADIENT_GOLD = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5

        },
        WIDE = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        },
        THICK_BLACK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6, ["A"] = 6, ["B"] = 6, ["C"] = 6, ["D"] = 6,
            ["E"] = 6, ["F"] = 6, ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6,
            ["K"] = 6, ["L"] = 6, ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6,
            ["Q"] = 6, ["R"] = 6, ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6,
            ["W"] = 6, ["X"] = 6, ["Y"] = 6, ["Z"] = 6, ["a"] = 6, ["b"] = 6,
            ["c"] = 6, ["d"] = 6, ["e"] = 6, ["f"] = 6, ["g"] = 6, ["h"] = 6,
            ["i"] = 6, ["j"] = 6, ["k"] = 6, ["l"] = 6, ["m"] = 6, ["n"] = 6,
            ["o"] = 6, ["p"] = 6, ["q"] = 6, ["r"] = 6, ["s"] = 6, ["t"] = 6,
            ["u"] = 6, ["v"] = 6, ["w"] = 6, ["x"] = 6, ["y"] = 6, ["z"] = 6,
            ["!"] = 6, ["@"] = 6, ["#"] = 6, ["$"] = 6, ["%"] = 6, ["^"] = 6,
            ["&"] = 6, ["*"] = 6, ["("] = 6, [")"] = 6, ["_"] = 6, ["+"] = 6,
            ["="] = 6, ["["] = 6, ["]"] = 6, ["{"] = 6, ["}"] = 6, ["|"] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, [","] = 6, ["?"] = 6
        },
        GRADIENT_GOLD_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN_BLACK = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY_BLACK = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5
        },
        WIDE_BLACK = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        }
    }

    --=====================================================
    -- Alias *_BLACK width tables to their non-black equivalents
    -- This keeps glyph support checks (lowercase, punctuation, etc.)
    -- consistent across light/dark textures.
    --=====================================================
    local function alias_widths(black_name)
        local base = black_name:gsub("_BLACK$", "")
        if self.char_widths[base] and not self.char_widths[black_name] then
            self.char_widths[black_name] = self.char_widths[base]
        end
    end

    for font_name, _ in pairs(self.font_sprites) do
        if font_name:match("_BLACK$") then
            alias_widths(font_name)
        end
    end

    
    self.player_fonts = {}
    
    Net:on("player_join", function(event)
        self:setupPlayerFonts(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerFonts(event.player_id)
    end)
    
    return self
end

function FontSystem:setupPlayerFonts(player_id)
    self.player_fonts[player_id] = {
        active_displays = {},
        next_obj_id = 10000  -- Start with high ID to avoid conflicts
    }
    
    -- Provide assets and allocate sprites for each font type
    for font_name, sprite_data in pairs(self.font_sprites) do
        Net.provide_asset_for_player(player_id, sprite_data.texture_path)
        if sprite_data.anim_path then
            Net.provide_asset_for_player(player_id, sprite_data.anim_path)
        end
        
        Net.player_alloc_sprite(player_id, font_name, sprite_data)
    end
end

function FontSystem:cleanupPlayerFonts(player_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        -- Erase all active displays
        for display_id, display in pairs(player_data.active_displays) do
            self:eraseTextDisplay(player_id, display_id)
        end
        
        -- Deallocate all font sprites
        for font_name, _ in pairs(self.font_sprites) do
            Net.player_dealloc_sprite(player_id, font_name)
        end
        
        self.player_fonts[player_id] = nil
    end
end

-- Returns the animation prefix for a font.
-- Dark fonts reuse the SAME animation state names as their base font.
-- Example: THICK_BLACK uses THICK_* states (but draws with THICK_BLACK texture).
local function anim_prefix_for_font(font_name)
    -- strip ONLY a trailing "_BLACK"
    return (font_name and font_name:gsub("_BLACK$", "")) or font_name
end

-- Smart punctuation normalization (FontSystem needs this too; nameplates use FontSystem directly)
local function normalize_glyph(raw)
    if not raw or raw == "" then return nil end
    if raw == " " then return " " end

    -- single quotes
    if raw == "’" or raw == "‘" then raw = "'" end

    -- double quotes
    if raw == "“" or raw == "”" then raw = '"' end

    -- dashes
    if raw == "–" or raw == "—" then raw = "-" end

    return raw
end


-- Normalize punctuation into ASCII BEFORE we iterate by bytes.
-- Handles both UTF-8 punctuation and CP1252 "smart" punctuation bytes (common on Windows).
local function normalize_text(text)
    if not text or text == "" then return text end

    text = text:gsub("\r", "")
    text = text:gsub("\239\187\191", "") -- UTF-8 BOM
    text = text:gsub("\194\160", " ")    -- NBSP

    -- UTF-8 smart punctuation
    text = text:gsub("’", "'"):gsub("‘", "'")
    text = text:gsub("“", '"'):gsub("”", '"')
    text = text:gsub("–", "-"):gsub("—", "-")
    text = text:gsub("…", "...")

    -- CP1252 smart punctuation bytes (Windows-1252)
    -- 0x91 ‘  0x92 ’  0x93 “  0x94 ”  0x96 –  0x97 —  0x85 …
    local b = string.char
    text = text:gsub(b(0x91), "'"):gsub(b(0x92), "'")
    text = text:gsub(b(0x93), '"'):gsub(b(0x94), '"')
    text = text:gsub(b(0x96), "-"):gsub(b(0x97), "-")
    text = text:gsub(b(0x85), "...")

    return text
end

local DEBUG_UNKNOWN_GLYPHS = true

local function dbg_unknown(font_name, raw_byte, state, text, i)
    if not DEBUG_UNKNOWN_GLYPHS then return end
    local byte = string.byte(raw_byte)
    print(string.format("[FontSystem] unknown glyph: font=%s i=%d byte=0x%02X state=%s context=%q",
        tostring(font_name), i, byte, tostring(state), tostring(text)))
end



-- Table with each letter of the alphabet as separate strings
local alphabet = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
}

-- Function to check if a string is in the alphabet table
function isInAlphabet(str)
    for _, letter in ipairs(alphabet) do
        if letter == str then
            return true
        end
    end
    return false
end

function FontSystem:drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id, tint)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local existing = player_data.active_displays[display_id]

    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale

    -- Normalize tint values once (fonts should use opacity, not `a`)
    local tint_r, tint_g, tint_b, tint_opacity, tint_color_mode
    if type(tint) == "table" then
        tint_r = tint.r
        tint_g = tint.g
        tint_b = tint.b
        tint_opacity = tint.opacity or tint.a -- accept old callers, but we will APPLY via opacity only
        tint_color_mode = tint.color_mode
    end

    local function build_and_draw(start_x, start_y)
        local current_x = start_x
        local obj_i = 0

        -- ensure table exists
        if not existing then
            existing = {
                font = font_name,
                x = start_x, y = start_y,
                scale = scale,
                z_order = z_order,
                character_objects = {},
                text = "",
                tint_r = tint_r,
                tint_g = tint_g,
                tint_b = tint_b,
                tint_opacity = tint_opacity,
                tint_color_mode = tint_color_mode
            }
            player_data.active_displays[display_id] = existing
        end


        local prefix = anim_prefix_for_font(font_name)

        -- Draw/update glyph sprites in place using stable obj ids
        for i = 1, #text do
            local raw = text:sub(i, i)
            local char = normalize_glyph(raw) or raw

            if (font_name == "BATTLE" or font_name == "WIDE") and char:match("%a") then
                char = char:upper()
            end

            local char_width = char_widths[char] or char_widths["A"] or 6
            local scaled_width = char_width * scale

            -- Space: advance only (no sprite)
            if char == " " then
                current_x = current_x + scaled_width + scaled_spacing
            else
                obj_i = obj_i + 1
                local obj_id = display_id .. "_char_" .. (10000 + obj_i)

                local state
                if char == char:lower() and isInAlphabet(char) then
                    state = prefix .. "_LOWER_" .. char:upper()
                else
                    state = prefix .. "_" .. char
                end

                local spr_opts = {
                    id = obj_id,
                    x = current_x,
                    y = start_y,
                    z = z_order,
                    sx = scale,
                    sy = scale,
                    anim_state = state,

                    -- IMPORTANT: always reset sprite opacity so "dim" doesn't stick
                    opacity = 255
                }


-- Optional tint (used for dimming menu items, etc.)
if type(tint) == "table" then
    if tint.r then spr_opts.r = tint.r end
    if tint.g then spr_opts.g = tint.g end
    if tint.b then spr_opts.b = tint.b end
    if tint.a then spr_opts.a = tint.a end
    if tint.color_mode then spr_opts.color_mode = tint.color_mode end

    -- IMPORTANT: accept "opacity" from callers (PromptVertical uses tint.opacity)
    -- Use ~= nil so opacity=0 still works.
    if tint.opacity ~= nil then
        spr_opts.opacity = tint.opacity
    end
end


                Net.player_draw_sprite(player_id, font_name, spr_opts)


                existing.character_objects[obj_i] = { obj_id = obj_id, width = scaled_width }
                current_x = current_x + scaled_width + scaled_spacing
            end
        end

        -- Erase any leftover glyph sprites from the previous longer string
        for j = obj_i + 1, #existing.character_objects do
            local tail = existing.character_objects[j]
            if tail and tail.obj_id then
                Net.player_erase_sprite(player_id, tail.obj_id)
            end
            existing.character_objects[j] = nil
        end

        existing.font = font_name
        existing.x = start_x
        existing.y = start_y
        existing.scale = scale
        existing.z_order = z_order
        existing.text = text

        existing.tint_r = tint_r
        existing.tint_g = tint_g
        existing.tint_b = tint_b
        existing.tint_opacity = tint_opacity
        existing.tint_color_mode = tint_color_mode


        return display_id
    end

    -- If same text/style and same position (and same tint): no-op
    if existing
        and existing.text == text
        and existing.font == font_name
        and existing.scale == scale
        and existing.z_order == z_order
        and existing.x == x
        and existing.y == y
        and existing.tint_r == tint_r
        and existing.tint_g == tint_g
        and existing.tint_b == tint_b
        and existing.tint_opacity == tint_opacity
        and existing.tint_color_mode == tint_color_mode
    then
        return display_id
    end


    -- If same text/style but moved: just redraw positions (still no erase)
    -- If text/style changed: update in place + trim tail
    return build_and_draw(x, y)
end


function FontSystem:drawText(player_id, text_id, text, x, y, z_order, font_name, scale)
    font_name = font_name or "THICK"
    scale = tonumber(scale) or 2.0
    z_order = z_order or 100
    text = normalize_text(text)


    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local display_id = text_id or ("text_" .. player_data.next_obj_id)
    player_data.next_obj_id = player_data.next_obj_id + 1

    local display_data = {
        font = font_name,
        x = x, y = y,
        scale = scale,
        z_order = z_order,
        character_objects = {},
        text = text
    }

    local current_x = x
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale

    for i = 1, #text do
        local raw = text:sub(i, i)
        local char = normalize_glyph(raw) or raw

        if (font_name == "BATTLE" or font_name == "WIDE") and char:match("%a") then
            char = char:upper()
        end

        local char_width = char_widths[char] or char_widths["A"] or 6
        local scaled_width = char_width * scale

        local obj_id = display_id .. "_char_" .. (10000 + i)

        local prefix = anim_prefix_for_font(font_name)
        local state
        if char == char:lower() and isInAlphabet(char) then
            state = prefix .. "_LOWER_" .. char:upper()
        else
            state = prefix .. "_" .. char
        end

        -- DEBUG: log any glyph that is not in the width table
        if char ~= " " and not char_widths[char] then
            dbg_unknown(font_name, raw, state, text, i)
        end


        -- Space: advance only (no sprite)
        if char == " " then
            current_x = current_x + scaled_width + scaled_spacing
            goto continue
        end

        Net.player_draw_sprite(player_id, font_name, {
            id = obj_id,
            x = current_x, y = y, z = z_order,
            sx = scale, sy = scale,
            anim_state = state
        })

        table.insert(display_data.character_objects, { obj_id = obj_id, width = scaled_width })
        current_x = current_x + scaled_width + scaled_spacing

        ::continue::
    end


    player_data.active_displays[display_id] = display_data
    return display_id
end


function FontSystem:eraseTextDisplay(player_id, display_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        local display = player_data.active_displays[display_id]
        if display then
            for _, char_data in ipairs(display.character_objects) do
                Net.player_erase_sprite(player_id, char_data.obj_id)
            end
            player_data.active_displays[display_id] = nil
        end
    end
end

function FontSystem:getTextWidth(text, font_name, scale)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    text = normalize_text(text)

    
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local total_width = 0
    
    -- FIXED: Calculate spacing that scales properly
    local base_spacing = 1  -- Base spacing at scale 1.0
    local scaled_spacing = base_spacing * scale
    
    for i = 1, #text do
        local raw = text:sub(i, i)
        local char = normalize_glyph(raw) or raw
        local char_width = char_widths[char] or char_widths["A"] or 6
        total_width = total_width + (char_width * scale) + scaled_spacing
    end
    
    -- Remove trailing spacing
    if #text > 0 then
        total_width = total_width - scaled_spacing
    end
    
    return total_width
end

local fontSystem = setmetatable({}, FontSystem)
fontSystem:init()

return fontSystem
