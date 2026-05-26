--[[
SUIT REFERENCE — Practical guide for demomino integration
lib/suit is an Immediate-Mode GUI library for Love2D by Matthias Richter.

=============================================================================
LOADING
=============================================================================

local SUIT = require("lib.suit")        -- shared default instance
local myUI = SUIT.new()                 -- OR: independent instance (own state/theme)

=============================================================================
LOVE2D HOOK-UP (add to main.lua)
=============================================================================

function love.keypressed(key)
    SUIT.keypressed(key)
    -- existing Touch/game handlers...
end

function love.textinput(char)
    SUIT.textinput(char)
end

function love.textedited(text, start, length)   -- candidate text (IME / mobile)
    SUIT.textedited(text, start, length)
end

-- Mouse input: SUIT polls love.mouse.getX/Y/isDown(1) automatically in
-- enterFrame(), so NO love.mousepressed hook needed for basic use.
-- Touch (mobile): SUIT does NOT receive touch events automatically.
-- For mobile menus, manually call:  SUIT.updateMouse(x, y, true/false)
-- in love.touchpressed / love.touchreleased / love.touchmoved.

=============================================================================
PER-FRAME PATTERN  (inside love.draw)
=============================================================================

function love.draw()
    -- ... existing game drawing ...

    -- Declare SUIT widgets here (between frames).
    -- SUIT.draw() was called last frame, which ended with enterFrame(),
    -- so state is fresh. Widget declarations run their logic NOW.

    if SUIT.Button("OK", 100, 200, 80, 30).hit then
        -- button was clicked/released
    end

    SUIT.draw()   -- flushes draw queue, then calls enterFrame() for next frame
end

-- SUIT.draw() MUST be the last SUIT call each frame.
-- Do NOT call SUIT.enterFrame() manually unless you skip SUIT.draw().

=============================================================================
WIDGETS — full API
=============================================================================

--- Button --------------------------------------------------------------------
local btn = SUIT.Button(text, [opt,] x, y, w, h)
-- btn.hit      true on mouse-release (clicked)
-- btn.hovered  true while mouse is over
-- btn.entered  true on the frame mouse enters
-- btn.left     true on the frame mouse leaves

--- Label (non-interactive text) -----------------------------------------------
local lbl = SUIT.Label(text, [opt,] x, y, w, h)

--- Checkbox ------------------------------------------------------------------
local chk = {checked = false, text = "Enable music"}
local result = SUIT.Checkbox(chk, [opt,] x, y, w, h)
-- chk.checked is toggled automatically on hit
-- result.hit = true on click

--- Slider --------------------------------------------------------------------
local slider = {value = 0.5, min = 0, max = 1, step = 0.1}
local result = SUIT.Slider(slider, [opt,] x, y, w, h)
-- result.changed = true when value changed this frame
-- slider.value holds the current value
-- opt.vertical = true for a vertical slider

--- Input (text field) --------------------------------------------------------
local input = {text = ""}
local result = SUIT.Input(input, [opt,] x, y, w, h)
-- result.submitted = true when Enter pressed
-- result.hit       = true when clicked (gains focus)
-- input.text       holds the current string
-- input.forcefocus = true  to programmatically give focus

--- ImageButton ---------------------------------------------------------------
-- opt.normal, opt.hovered, opt.active = love.graphics.Image objects
local result = SUIT.ImageButton(normal_img, {hovered=hov_img, active=act_img}, x, y)
-- OR pass images as positional: {normal_img, hov_img, act_img}
-- opt.mask = ImageData for alpha-test hit detection

=============================================================================
OPTIONS TABLE (opt) — common fields
=============================================================================

opt.id           -- unique widget ID; defaults to text/object reference
                 -- REQUIRED when two widgets share the same text label
opt.font         -- love.Font object; defaults to love.graphics.getFont()
opt.align        -- "left" | "center" (default) | "right"
opt.valign       -- "top" | "middle" (default) | "bottom"
opt.cornerRadius -- override theme.cornerRadius for this widget
opt.draw         -- custom draw function: function(text, opt, x, y, w, h)
opt.color        -- per-widget color override (see Theme section)
opt.vertical     -- true for vertical Slider

-- Example: labeled button with unique id
SUIT.Button("Play", {id="btn_play", font=myFont, align="center"}, x, y, 120, 40)

=============================================================================
THEME CUSTOMIZATION
=============================================================================

-- Global theme colors (replace any or all):
SUIT.theme.color = {
    normal  = {bg = {0.15, 0.10, 0.20}, fg = {0.90, 0.78, 0.95}},
    hovered = {bg = {0.55, 0.10, 0.55}, fg = {1,    1,    1   }},
    active  = {bg = {0.80, 0.20, 0.20}, fg = {1,    1,    1   }},
}
SUIT.theme.cornerRadius = 6

-- Per-widget color via opt.color:
local pinkButton = {
    color = {
        normal  = {bg = {0.6, 0.1, 0.4}, fg = {1, 1, 1}},
        hovered = {bg = {0.8, 0.2, 0.6}, fg = {1, 1, 1}},
        active  = {bg = {1.0, 0.3, 0.7}, fg = {1, 1, 1}},
    }
}
SUIT.Button("New Game", pinkButton, x, y, 160, 40)

-- Fully custom draw function for a widget:
SUIT.Button("Settings", {draw = function(text, opt, x, y, w, h)
    -- opt.state = "normal" | "hovered" | "active"
    love.graphics.setColor(myColors[opt.state])
    love.graphics.rectangle("fill", x, y, w, h, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(opt.font)
    love.graphics.printf(text, x, y + (h - opt.font:getHeight()) / 2, w, "center")
end}, x, y, 140, 36)

-- Replace a theme draw function globally:
SUIT.theme.Button = function(text, opt, x, y, w, h)
    -- custom rendering for ALL buttons
end

=============================================================================
LAYOUT SYSTEM
=============================================================================

--- Immediate mode (manual flow) -------------------------------------------
SUIT.layout:reset(startX, startY, padX, padY)  -- reset cursor

x,y,w,h = SUIT.layout:row(w, h)    -- next cell below, returns position
x,y,w,h = SUIT.layout:col(w, h)    -- next cell to the right
x,y,w,h = SUIT.layout:up(w, h)     -- next cell above
x,y,w,h = SUIT.layout:left(w, h)   -- next cell to the left

-- Omit w or h to reuse the last value:
SUIT.layout:reset(50, 100, 0, 8)
SUIT.Button("New Game", SUIT.layout:row(160, 36))
SUIT.Button("Continue", SUIT.layout:row())         -- same size as above
SUIT.Button("Options",  SUIT.layout:row())

-- Stack/unstack sub-regions:
SUIT.layout:push(x, y)   -- save state, reset to x,y
SUIT.layout:pop()         -- restore state

--- Retained mode (compute layout up-front) ---------------------------------

local layout = SUIT.layout:rows{
    pos     = {startX, startY},   -- top-left origin
    padding = {padX, padY},       -- cell gap
    {160, 36},   -- row 1: w=160, h=36
    {nil, 36},   -- row 2: same w, h=36
    "max",       -- row 3: max seen w & h
    "median",    -- row 4: median
    "fill",      -- row 5: fill remaining height (needs min_height)
}
-- iterate:
for i, x, y, w, h in layout() do
    -- use cell by index
end
-- or access by index:
local x,y,w,h = layout:cell(2)

-- Horizontal version:
local layout = SUIT.layout:cols{
    pos = {startX, startY},
    min_width = 520,   -- minimum total width for "fill" calculation
    {100, 70},
    "max",
    "fill",    -- fills: (min_width - sum_of_fixed_widths) / n_fill_cols
    "min",
}

=============================================================================
MULTIPLE INSTANCES (per-screen)
=============================================================================

local TitleUI  = SUIT.new()
local PauseUI  = SUIT.new()
local ShopUI   = SUIT.new()

-- Each instance has independent hover/active/hit state and its own theme.
-- Call each instance's .draw() at the right point in love.draw().
-- Hook keypressed/textinput to only the active instance.

=============================================================================
TOUCH / MOBILE NOTES
=============================================================================

-- SUIT uses love.mouse.* polling, which DOES work on mobile IF
-- love translates touch → mouse (enabled by default in Love2D).
-- If touch-to-mouse translation is OFF, manually feed input:

function love.touchpressed(id, x, y)
    SUIT.updateMouse(x, y, true)
end
function love.touchreleased(id, x, y)
    SUIT.updateMouse(x, y, false)
end
function love.touchmoved(id, x, y)
    SUIT.updateMouse(x, y, true)
end

-- The existing Touch module in this game intercepts mouse/touch events.
-- SUIT's polling approach coexists fine for separate game phases —
-- just ensure SUIT.draw() is called during phases where SUIT menus are active.

=============================================================================
INTEGRATION PATTERN FOR DEMOMINO PHASES
=============================================================================

-- In ui/renderer.lua (or a new ui/suit_menus.lua), declare widgets inside
-- the relevant drawXxx() function and pass a phase-specific SUIT instance.

-- Example: settings menu using SUIT
local SettingsUI = require("lib.suit").new()

function UI.Renderer.drawSettingsMenuSUIT()
    local cx = gameState.screen.width / 2
    local cy = gameState.screen.height / 2
    local bw, bh = 180, 40

    SettingsUI.layout:reset(cx - bw/2, cy - 80, 0, 10)

    local musicChk = {checked = gameState.musicEnabled, text = "Music"}
    SettingsUI.Checkbox(musicChk, SettingsUI.layout:row(bw, bh))
    if musicChk.checked ~= gameState.musicEnabled then
        UI.Audio.toggleMusic()
    end

    if SettingsUI.Button("Restart Run", SettingsUI.layout:row()).hit then
        -- restart logic
    end
    if SettingsUI.Button("Return to Title", SettingsUI.layout:row()).hit then
        -- return to title logic
    end

    SettingsUI.draw()
end

-- Register keypressed in main.lua love.keypressed:
--   SettingsUI.keypressed(key)  (or whichever instance is active)

=============================================================================
WIDGET RETURN VALUES SUMMARY
=============================================================================

-- All widgets return a table with:
-- .hit      bool  — fired once on mouse-release over widget
-- .hovered  bool  — true while mouse is inside widget bounds
-- .entered  bool  — true the frame mouse enters bounds
-- .left     bool  — true the frame mouse leaves bounds
-- .id             — the widget's resolved id

-- Slider also returns:
-- .changed  bool  — true if value changed this frame

-- Input also returns:
-- .submitted bool — true when Enter/Return pressed while focused

=============================================================================
]]
