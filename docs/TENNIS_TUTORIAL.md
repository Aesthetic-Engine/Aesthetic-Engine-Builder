# Building a Tennis Game with Aesthetic Engine Builder

This walkthrough shows how to build a complete tennis/paddle-ball game using Aesthetic Engine Builder's wireframe graphics pipeline. The whole game is one GDScript file. No sprites, no textures, no editor work.

## What you'll end up with

- Two paddles (player on left, AI on right)
- A bouncing ball with collision and speed ramp
- Seven-segment score display
- Center court dashed line
- Full CRT post-processing (scanlines, barrel distortion, phosphor glow)

## Prerequisites

- Aesthetic Engine Builder project set up and running (see the main README)
- Cursor connected to your project via GRB

## Step 1 — Tell Cursor what to build

Open Cursor Agent mode and paste:

> Replace the starter game with a tennis game using Aesthetic Engine Builder's wireframe pipeline. The game should have: a left paddle controlled by arrow keys, a right paddle controlled by AI, a bouncing ball, score display at the top, and a dashed center line. Use WireframeCanvas drawing commands (dl, dr, dp) for all rendering. Disable draw-in animation since the scene redraws every frame. Launch the game via GRB and take a screenshot to verify.

Cursor will rewrite `game/WireframeMain.gd`, launch the game, and show you the result.

## What Cursor builds (and why)

If you want to understand what's happening or build it yourself, here's the breakdown.

### The game script structure

The entire game lives in `game/WireframeMain.gd`. It extends `Control` (the main scene root) and sets up three things in `_ready()`:

1. **CRTPipeline** — the post-processing chain (phosphor decay, scanlines, barrel distortion)
2. **WireframeCanvas** — the drawing surface, added as a child of the pipeline's content viewport
3. **A room drawer** — a callable registered as `"tennis"` that draws the game state each frame

```gdscript
func _ready() -> void:
    _pipeline = CRTPipeline.new()
    _pipeline.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_pipeline)

    _canvas = WireframeCanvas.new()
    _canvas.draw_in_enabled = false  # No reveal animation — we redraw every frame
    _canvas.size = Vector2(_pipeline.virtual_width, _pipeline.virtual_height)
    _pipeline.get_content_root().add_child(_canvas)

    _canvas.register_room_drawer("tennis", _draw_tennis)
    _canvas.load_scene("tennis")
```

Key detail: `draw_in_enabled = false`. The canvas normally does a line-by-line reveal animation when loading a scene. For a real-time game, you want instant full redraws every frame.

### Game state — all proportional coordinates

All positions use 0.0–1.0 proportional coordinates. The drawing function converts to pixels at render time. This means the game works at any resolution.

```gdscript
var _left_y: float = 0.5       # Paddle center Y (0-1)
var _right_y: float = 0.5
var _ball_x: float = 0.5       # Ball position (0-1)
var _ball_y: float = 0.5
var _ball_vx: float = 0.4      # Ball velocity (units per second)
var _ball_vy: float = 0.3
```

### Game loop

`_process(delta)` runs every frame:

1. **AI update** — the right paddle tracks the ball's Y position at 70% of paddle speed (so it's beatable)
2. **Input update** — the left paddle responds to `ui_up` / `ui_down` (arrow keys)
3. **Ball update** — move ball, bounce off top/bottom walls, check paddle collisions, detect scoring
4. **Redraw** — `_canvas.queue_redraw()` triggers the drawing function

### Paddle collision

Collision is simple: if the ball crosses a paddle's X position while moving toward it, check if the ball's Y is within the paddle's height. On hit, reverse X velocity and add some Y deflection based on where the ball hit the paddle.

```gdscript
var lp_x: float = 0.04 + PADDLE_W
if _ball_x <= lp_x and _ball_vx < 0.0:
    if absf(_ball_y - _left_y) < PADDLE_HALF_H + 0.015:
        _ball_x = lp_x
        _ball_vx = absf(_ball_vx) * 1.05   # Speed up slightly each hit
        _ball_vy += (_ball_y - _left_y) * 1.5  # Angle based on hit position
```

### Drawing with WireframeCanvas

The drawing function receives the canvas and uses three commands:

- `canvas.dl(from, to, color, width)` — draw a line
- `canvas.dr(rect, color, filled, width)` — draw a rectangle
- `canvas.dp(points, color, filled)` — draw a polygon/polyline

Colors available: `WireframeCanvas.DEFAULT_COLOR` (bright green) and `WireframeCanvas.DIM_COLOR` (darker green).

**Paddles** — filled rectangles:

```gdscript
var lp_top: float = (_left_y - PADDLE_HALF_H) * h
canvas.dr(Rect2(lp_left, lp_top, PADDLE_W * w, PADDLE_HALF_H * 2.0 * h), green, true)
```

**Ball** — small filled rectangle:

```gdscript
canvas.dr(Rect2(bx - 2, by - 2, 4, 4), green, true)
```

**Center line** — dashed by drawing every other segment:

```gdscript
for i in range(15):
    if i % 2 == 0:
        canvas.dr(Rect2(w * 0.5 - 1, dy, 2, dh), dim)
```

### Seven-segment score digits

Each digit (0-9) is drawn with 7 line segments. A lookup table stores which segments are on for each digit:

```gdscript
var top := [1, 0, 1, 1, 0, 1, 1, 1, 1, 1]
var mid := [0, 0, 1, 1, 1, 1, 1, 0, 1, 1]
# ... etc for bot, tl, tr, bl, br
```

Then draw each active segment as a line:

```gdscript
if top[clamped]:
    canvas.dl(Vector2(x, y), Vector2(x + dw, y), col, 2.0)
```

## Step 2 — Verify with GRB

After Cursor builds the game, it should automatically launch via `grb_launch` and take a screenshot. You should see:

- Green paddles on left and right edges
- A small green ball bouncing between them
- Score numbers at the top
- Dashed center line
- CRT scanlines, barrel distortion, and phosphor glow

If the AI is scoring because your input isn't reaching the game (synthetic input mode blocks real devices), that's expected during GRB testing. When you run the game normally from Godot, arrow keys will control the left paddle.

## Step 3 — Customize

Some things to tell Cursor to add:

- *"Add a title screen that says TENNIS with a Start button"*
- *"Make the ball leave a phosphor trail when it moves fast"*
- *"Add a sound effect when the ball hits a paddle"*
- *"Make the score go to 11 and show a winner screen"*
- *"Add a second player mode using W/S keys"*

Each of these is a single prompt. Cursor will edit the script, relaunch, screenshot, and verify.

## Key takeaways

- **One script, one scene** — the entire game is `game/WireframeMain.gd` attached to `main.tscn`
- **Proportional coordinates** — all game logic uses 0-1 ranges, converted to pixels only at draw time
- **No sprites** — everything is lines and rectangles via `dl()` and `dr()`
- **CRT for free** — the pipeline handles all post-processing automatically
- **Disable draw-in** — set `draw_in_enabled = false` for real-time games that redraw every frame
- **`queue_redraw()` every frame** — call it in `_process()` to trigger the drawing function
