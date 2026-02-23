# Technical Systems

This document covers the RNG system, save/load serialization, game state machine, animation systems, and other technical infrastructure.

**Source files:** `functions/rng.lua`, `functions/saveload.lua`, `main.lua`, `functions/tween.lua`, `functions/particles.lua`, `functions/transition.lua`, `functions/settings.lua`

---

## Random Number Generation

### Seeded RNG

The game uses LÖVE2D's `RandomGenerator` object, which is separate from Lua's `math.random`. This allows deterministic seeded runs — the same seed always produces the same game.

```lua
local rng = love.math.newRandomGenerator()
```

### Seed Hashing (DJB2)

Player-entered seeds are strings (alphanumeric, up to 16 characters). They're hashed to a numeric seed using the DJB2 algorithm:

```lua
function RNG.setSeed(seed_str)
    local hash = 5381
    for i = 1, #seed_str do
        hash = ((hash * 33) + seed_str:byte(i)) % 2147483647
    end
    rng:setSeed(hash)
end
```

DJB2 properties:
- Deterministic: same string always produces the same hash
- Good distribution: similar strings produce very different hashes
- Modulo 2^31-1 keeps the hash within Lua's safe integer range

### Seed Generation

When no seed is entered, a random 8-character seed is generated:

```lua
function RNG.generateSeed()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local seed = ""
    math.randomseed(os.time() + love.timer.getTime() * 1000000)
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        seed = seed .. chars:sub(idx, idx)
    end
    return seed
end
```

This uses `math.random` (not the seeded RNG) since we need non-deterministic behavior for seed generation.

### State Persistence

The RNG state can be saved and restored for save/load determinism:

```lua
function RNG.getState()
    return rng:getState()
end

function RNG.setState(state)
    rng:setState(state)
end
```

LÖVE2D's `RandomGenerator:getState()` returns an opaque string that fully captures the generator's internal state. Restoring it guarantees the same sequence of future random values.

### API

| Function | Returns | Description |
|----------|---------|-------------|
| `RNG.random()` | float [0,1) | Uniform random float |
| `RNG.random(n)` | int [1,n] | Uniform random integer |
| `RNG.random(a,b)` | int [a,b] | Uniform random integer in range |
| `RNG.setSeed(str)` | — | Hash string and seed the generator |
| `RNG.generateSeed()` | string | Create a random 8-char seed |
| `RNG.getState()` | string | Snapshot RNG state |
| `RNG.setState(str)` | — | Restore RNG state |

---

## Save/Load System

### Save File

Saves are written to `savedata.lua` in LÖVE2D's save directory (`love.filesystem.getSaveDirectory()`). The save identity is `letdieride`, so saves go to:

- **macOS:** `~/Library/Application Support/LOVE/letdieride/savedata.lua`
- **Windows:** `%APPDATA%\LOVE\letdieride\savedata.lua`
- **Linux:** `~/.local/share/love/letdieride/savedata.lua`

### Serialization

The game uses a custom Lua table serializer (not JSON or binary). It recursively serializes tables, strings, numbers, and booleans into valid Lua syntax:

```lua
function SaveLoad.serialize(val, indent)
    if type(val) == "number" then return tostring(val) end
    if type(val) == "string" then return string.format("%q", val) end
    if type(val) == "boolean" then return tostring(val) end
    if type(val) == "table" then
        -- recursive table serialization with indentation
    end
end
```

The save file is a `return { ... }` statement that can be loaded via `love.filesystem.load()`.

### Save Data Structure

```lua
return {
    save_version = 1,
    state = "round",          -- or "shop"
    seed = "ABCD1234",
    rng_state = "...",         -- opaque RNG state string
    round = 5,
    currency = 42,
    base_rerolls = 3,
    dice = {
        { name = "Heavy Die", color = "blue", die_type = "heavy",
          value = 4, weights = {0, 0, 1, 1, 1, 1},
          glow_color = {0.2, 0.25, 0.7, 0.6}, sort_order = 1,
          upgrade_level = 1 },
        -- ... more dice
    },
    hands = {
        { name = "Pair", base_score = 13, multiplier = 2.0, upgrade_level = 1 },
        -- ... all 17 hands
    },
    items = { "Lucky Penny", "Even Steven" },  -- item names only
}
```

### Restore Process

On load:
1. Parse the save file via `love.filesystem.load()`
2. Reconstruct the Player object from saved stats
3. Recreate dice from templates (matching by `die_type`), applying saved weights, value, glow, and upgrade level
4. Recreate hands from templates, applying saved base_score, multiplier, and upgrade_level
5. Recreate items from templates by name (abilities are re-attached from `content/items.lua`)
6. Restore the RNG state for deterministic continuation
7. Initialize the appropriate game state (round or shop)

### Auto-Save Triggers

The game auto-saves at these points:
- `love.quit()` — closing the window
- `love.focus(false)` — alt-tabbing or losing focus
- After scoring a round (transitioning to shop)
- After completing a shop visit (starting next round)
- "Save & Menu" from the pause screen
- "Save & Exit" from the pause screen

### Save Deletion

Saves are deleted when:
- Starting a new game (`initNewGame`)
- Game over (the run is lost)

---

## Game State Machine

### States

```
splash ──→ seed_input ──→ round ←──→ shop
  ↑                         │          │
  │                         ↓          │
  │                     game_over      │
  └────────────────────────────────────┘
```

Overlays (can exist on top of any state):
- **pause** — overlays round or shop
- **settings** — overlays splash or pause
- **tutorial** — overlays round and shop
- **devmenu** — overlays splash

### State Transitions

All state transitions go through `Transition.fadeTo(callback, duration)`, which fades the screen to black, executes the callback (state change), then fades back in. This prevents visual pops.

### State Variables (main.lua)

```lua
local state = "splash"       -- current game state
local paused = false          -- pause overlay active
local unfocused = false       -- window lost focus
local tutorial_active = false -- tutorial overlay active
local devmenu_open = false    -- dev menu overlay active
```

### Input Routing

Input is routed hierarchically:
1. Check if transition is active → block all input
2. Check if unfocused + pause_on_unfocus → block all input
3. Check if tutorial is active → tutorial gets first crack, may consume input
4. Check if settings screen → route to settings
5. Check if devmenu → route to devmenu
6. Check if paused → route to pause overlay
7. Route to current state handler

---

## Tween System

### Architecture

The tween system animates numeric properties on any Lua table over time using easing functions.

```lua
Tween.to(target_table, duration, {property = end_value, ...}, easing, callback)
```

### Easing Functions

13 built-in easing functions:

| Function | Curve |
|----------|-------|
| `linear` | Constant speed |
| `inQuad` | Accelerating (power of 2) |
| `outQuad` | Decelerating (power of 2) |
| `inOutQuad` | Accelerate then decelerate |
| `inCubic` | Accelerating (power of 3) |
| `outCubic` | Decelerating (power of 3) |
| `inOutCubic` | Accelerate then decelerate (cubic) |
| `outBack` | Overshoots then settles |
| `inBack` | Pulls back then accelerates |
| `outElastic` | Bouncy overshoot |
| `inElastic` | Elastic pull-back |
| `outBounce` | Bouncing settle |
| `inExpo` / `outExpo` | Exponential acceleration/deceleration |

### Internal State

Each active tween stores:
- Reference to the target table
- Start values for each property
- End values for each property
- Elapsed time / total duration
- Easing function reference
- Completion callback

`Tween.update(dt)` iterates all active tweens, advances time, interpolates properties, and fires callbacks on completion.

### Cancellation

```lua
Tween.cancel(tween_handle)    -- cancel a specific tween
Tween.cancelAll(target_table) -- cancel all tweens on a target
Tween.reset()                 -- cancel everything
```

---

## Particle System

### Architecture

A CPU-driven particle system (doesn't use LÖVE's built-in ParticleSystem). Each emitter spawns particles with randomized properties within configured ranges.

### Emitter Configuration

```lua
Particles.emit({
    x = 400, y = 300,        -- spawn position
    count = 20,               -- number of particles
    angle_min = 0,            -- emission angle range (radians)
    angle_max = math.pi * 2,
    speed_min = 50,           -- initial speed range
    speed_max = 150,
    lifetime = 1.0,           -- seconds
    size = 4,                 -- pixel radius
    color = {1, 0.84, 0, 1}, -- RGBA
    gravity = 80,             -- downward acceleration
    friction = 0.98,          -- velocity multiplier per frame
    spread = 10,              -- random position offset
    shape = "circle",         -- "circle" or "rect"
})
```

### Presets

| Preset | Use Case | Gravity | Direction |
|--------|----------|---------|-----------|
| `burst` | Scoring wins | 80 (down) | Explosive outward |
| `sparkle` | Shop purchases | -40 (up) | Upward sparkles |
| `dust` | Subtle effects | -20 (up) | Gentle upward puff |
| `drift` | Game over background | 5 (slight down) | Slow horizontal drift |

### Per-Frame Update

```lua
for each particle:
    velocity *= friction
    velocity.y += gravity * dt
    position += velocity * dt
    lifetime -= dt
    if lifetime <= 0: remove particle
```

Alpha fades linearly with remaining lifetime.

---

## Settings System

### Storage

Settings are persisted to `settings.lua` in the LÖVE save directory as a Lua table (same serializer as save data).

### Default Values

| Setting | Default | Type |
|---------|---------|------|
| `master_volume` | 1.0 | float [0,1] |
| `music_volume` | 0.5 | float [0,1] |
| `pause_on_unfocus` | true | bool |
| `screenshake` | true | bool |
| `show_fps` | false | bool |
| `vsync` | true | bool |
| `fullscreen` | false | bool |
| `dice_sort_mode` | 1 | int [1,6] |

### Keybinds

| Action | Default Key |
|--------|-------------|
| `select_next` | tab |
| `move_left` | left |
| `move_right` | right |
| `toggle_lock` | space |
| `reroll` | r |
| `score` | return |
| `sort_cycle` | q |
| `show_tooltip` | e |

Keybinds are rebindable in the settings screen. The system listens for any keypress and assigns it to the selected action.

---

## Auto-Updater

### Architecture

The updater runs a background thread (LÖVE2D thread) to avoid blocking the game:

```
Main thread                     Background thread
    │                               │
    ├── Updater.check() ──────────→ │ curl GitHub API
    │                               │ parse response
    │   Updater.update() ←──────── │ push result to channel
    │   (polls channel each frame)  │
    │                               │
    ├── Compare versions            
    ├── Show toast if newer          
    └── Open browser on click       
```

### Version Comparison

Semantic versioning comparison (`major.minor.patch`):

```lua
function isNewer(remote, current)
    local r1, r2, r3 = parseVersion(remote)
    local c1, c2, c3 = parseVersion(current)
    if r1 ~= c1 then return r1 > c1 end
    if r2 ~= c2 then return r2 > c2 end
    return r3 > c3
end
```

### API Endpoint

```
GET https://api.github.com/repos/isaaclins/letdieride/releases/latest
```

The response is parsed for `tag_name` (version) and `html_url` (release page).

---

## Screen Shake

Used for emphasis on dramatic events (game over landing, boss activation):

```lua
if Settings.get("screenshake") then
    -- Apply random offset to camera transform
    local shake_x = (math.random() - 0.5) * intensity
    local shake_y = (math.random() - 0.5) * intensity
    love.graphics.translate(shake_x, shake_y)
end
```

Intensity decays over time. Can be disabled in settings.

---

## Toast Notification System

### Lifecycle

```
show() → "in" phase (0.3s fade+slide) → "hold" phase (2.5s) → "out" phase (0.3s fade)
```

### Stacking

Multiple toasts stack vertically from the bottom of the screen. Each toast occupies a slot that shifts up as new toasts appear.

### Types

| Type | Color | Use Case |
|------|-------|----------|
| `success` | Green | Purchases, upgrades |
| `error` | Red | Insufficient funds, invalid actions |
| `info` | Gold | Update available, round info |
| `neutral` | Gray | General messages |

---

## Coin Animation

### Sprite Sheet

6 frames loaded from `content/icon/currency/silver/1-6.png`:

```
Frame 1: Full face    →  Frame 2: Slight tilt  →  Frame 3: Edge-on
Frame 4: Back tilt    →  Frame 5: Back face     →  Frame 6: Return tilt
```

Animation runs at 8 FPS (0.125s per frame), looping continuously. Used for all currency displays in the UI.

### Rendering Modes

| Mode | Function | Use Case |
|------|----------|----------|
| Animated | `CoinAnim.draw(x, y, scale)` | Active currency displays |
| Static | `CoinAnim.drawStatic(x, y, scale)` | Labels, tooltips |
| With amount | `CoinAnim.drawWithAmount(str, x, y, align, w, scale)` | Shop prices, earnings |
