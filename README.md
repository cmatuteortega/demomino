# DEMOMINO Deckbuilder

A roguelike deckbuilding game built with dominoes! Strategic tile placement meets progression systems in this pixel-art domino adventure.

![Love2D](https://img.shields.io/badge/LÖVE-11.5-EA316E?logo=love2d)
![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

Domino Deckbuilder is a unique blend of classic domino mechanics and modern deckbuilding roguelike gameplay. Place dominoes on a board to create scoring combinations, unlock new tiles, face challenges, and progress through a procedurally generated map.

## Features

- **Classic Domino Gameplay**: Standard 28-tile domino set (0-0 through 6-6) with traditional matching rules
- **Deckbuilding Mechanics**: Build your tile collection by purchasing new dominoes and special tiles
- **Roguelike Progression**: Navigate a procedurally generated map with combat, shops, and special encounters
- **Challenge System**: Face unique gameplay modifiers that change how you score and play
- **Special Tiles**: Unlock powerful odd/even tiles that match multiple values
- **Scoring Combos**: Chain tiles together for multipliers and bonuses
- **Currency System**: Earn coins from victories and spend them wisely
- **Cross-Platform**: Works on desktop (Windows, macOS, Linux) and mobile (Android, iOS)

## Technology Stack

### Framework
- **[LÖVE (Love2D)](https://love2d.org/)**: Lua-based 2D game framework
- **Lua 5.1**: Programming language
- **GLSL Shaders**: Custom CRT post-processing effect

### Architecture
The game follows a modular architecture with clear separation of concerns:

```
dominer/
├── game/              # Core game logic
│   ├── domino.lua     # Tile creation and manipulation
│   ├── hand.lua       # Player hand management
│   ├── board.lua      # Board state and placement
│   ├── validation.lua # Game rule validation
│   ├── scoring.lua    # Score calculation
│   ├── challenges.lua # Challenge system
│   └── map.lua        # Map generation (DAG-based)
├── ui/                # User interface
│   ├── renderer.lua   # Visual rendering
│   ├── layout.lua     # Responsive layout
│   ├── touch.lua      # Input handling
│   ├── animation.lua  # Animation system
│   ├── fonts.lua      # Font management
│   ├── colors.lua     # Color palette
│   └── audio.lua      # Sound and music
├── sprites/           # Game assets
│   ├── tiles/         # Domino sprites (vertical)
│   ├── titled_tiles/  # Domino sprites (tilted)
│   ├── demon_tiles/   # Special challenge tiles
│   ├── nodes/         # Map node icons
│   └── currency/      # Coin sprite
├── shaders/           # GLSL shader files
├── main.lua          # Entry point and game loop
└── Pixellari.ttf     # Pixel art font
```

## Color Palette

The game uses a carefully chosen retro-inspired color palette:

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| Background | `#3E2D35` | `62, 45, 53` | Main background |
| Background Light | `#5D3949` | `93, 57, 73` | Lighter panels |
| Font White | `#F9D8D8` | `249, 216, 216` | Primary text |
| Font Pink | `#F0939B` | `240, 147, 155` | Secondary text |
| Font Red | `#D85B56` | `216, 91, 86` | Score, warnings |
| Font Red Dark | `#98403C` | `152, 64, 60` | Critical warnings |
| Outline | `#1A1E23` | `26, 30, 35` | Borders, outlines |

## Game Loop

### Main Loop Structure

```lua
love.load()           -- Initialize game state, load assets, create deck
  ↓
love.update(dt)       -- Update game logic, animations, input
  ↓
love.draw()           -- Render game to canvas, apply CRT shader
```

### Game Phases

1. **Map Phase**: Navigate procedurally generated map with 8-12 depth levels
2. **Combat Phase**: Play dominoes to reach target score
3. **Shop Phases**: Purchase new tiles, artifacts, or contracts
4. **Victory/Defeat**: Earn coins and progress or restart

### Core Gameplay Loop

```
Start Combat Round
    ↓
Initialize 7-tile hand from deck
    ↓
Player places tiles on board (drag-and-drop)
    ↓
Validate connections (matching pip values)
    ↓
Calculate score (base value × multiplier + bonuses)
    ↓
    ├─→ Play tiles (remove from hand, refill)
    └─→ Discard tiles (limited to 2 per round)
    ↓
Check win/loss conditions
    ↓
    ├─→ Win: Earn coins, proceed to next node
    └─→ Lose: Return to map or game over
```

## Scoring System

### Base Score
- Sum of all pip values in a play
- Special tiles (odd/even) count as 3 points each

### Bonuses
- **Double Tiles**: +10 points per double
- **Chain Bonus**:
  - 3+ tiles: +10 points
  - 5+ tiles: +20 points
- **Multiplier**: Based on most recurring pip value across all tiles

### Example
```
Play: [2-4], [4-4], [4-3]
Base: (2+4) + (4+4) + (4+3) = 21
Double bonus: +10 (for 4-4)
Multiplier: ×3 (three tiles have 4)
Total: 31 × 3 = 93 points
```

## Running the Game

### Prerequisites
Install [LÖVE 11.5](https://love2d.org/) or later

### Desktop
```bash
# From project directory
love .

# Or run the .love file directly
love dominatrix.love
```

### Mobile
Use LÖVE's mobile build tools:
- **Android**: Package as APK using [love-android](https://github.com/love2d/love-android)
- **iOS**: Build with [love-ios](https://github.com/love2d/love-ios)

## Controls

- **Mouse/Touch**: Drag tiles to place them on the board
- **Tap**: Select/deselect tiles
- **Play Button**: Confirm and score your current tile placement
- **Discard Button**: Discard selected tiles (limited uses)

## Development

### Adding New Tiles
1. Create sprite in `sprites/tiles/` (vertical) and `sprites/titled_tiles/` (tilted)
2. Name format: `{left}{right}.png` (e.g., `23.png` for 2-3 domino)
3. Update `loadDominoSprites()` in [main.lua](main.lua) if needed

### Creating Custom Challenges
Implement in [game/challenges.lua](game/challenges.lua):
```lua
{
    id = "unique_id",
    name = "Challenge Name",
    description = "What it does",
    initialize = function(state) end,
    onHandComplete = function(state) end,
    modifyScore = function(state, tiles, baseScore) end
}
```

### Modifying the Color Palette
Edit values in [ui/colors.lua](ui/colors.lua) (colors use 0-1 range)

## Project Structure Details

### Module Loading Order
Modules are loaded in a specific order for dependency management:
1. Core game modules (domino, hand, board, validation, scoring, challenges, map)
2. UI modules (touch, layout, fonts, colors, renderer, animation, audio)
3. Sprite loading

### State Management
Global `gameState` table contains:
- `deck`: Current tile deck
- `hand`: Player's 7-tile hand
- `board`: Board grid state
- `placedTiles`: Tiles currently on the board
- `score`: Current score
- `coins`: Player currency
- `tileCollection`: Owned tiles
- `activeChallenges`: Active gameplay modifiers
- `currentMap`: Procedural map state

### Animation System
Comprehensive animation framework with:
- Easing functions (easeOutQuart, easeOutBack, easeOutElastic)
- Score popups and floating text
- Coin drop animations
- Tile placement effects
- Button press feedback

## License

MIT License - See LICENSE file for details

## Credits

- **Font**: Pixellari by Zacchary Dempsey-Plante
- **Framework**: LÖVE (Love2D)
- **Art**: Custom pixel art sprites

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

Built with ❤️ using LÖVE
