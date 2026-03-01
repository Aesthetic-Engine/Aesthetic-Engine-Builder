# Aesthetic Engine Builder — Developer Reference

A guide for developers who want to understand how the pieces fit together, extend their game manually, or customize the pipeline beyond what the AI-generated prompt covers.

> **Note:** You don't need to read this to use Aesthetic Engine Builder. The generated prompt gives Cursor everything it needs. This is for when you want to go deeper.

## Architecture Overview

```
WireframeCanvas (320×200 virtual resolution)
    └─ Room drawers: dl(), dr(), dp() → command buffer → _draw()
         └─ CRTPipeline: SubViewport → phosphor decay → CRT shader → glass reflection
              └─ Full-screen output
```

All game visuals are code-drawn — lines, rectangles, and polygons rendered into a 320×200 virtual canvas, then processed through a CRT shader pipeline.

## Drawing API

WireframeCanvas provides these drawing functions (all use absolute pixel coordinates, 320×200):

| Function | Purpose |
|----------|---------|
| `dl(from, to, color, width)` | Draw a line |
| `dr(rect, color, filled)` | Draw a rectangle |
| `dp(points, color, filled, width)` | Draw a polygon/polyline |
| `dt(text, x, y, color, scale)` | Draw text (built-in 3×5 pixel font) |
| `ds(value, x, y, color, digits, scale)` | Draw seven-segment score display |

Colors: `WireframeCanvas.DEFAULT_COLOR` (bright green), `DIM_COLOR`, `BG_COLOR`.

## Room System

Rooms combine a JSON file (data, hotspots, actions) with a GDScript drawer function (visuals).

### Room JSON (`content/rooms/<id>.json`)

```json
{
  "id": "workshop",
  "title": "Workshop",
  "procedural": true,
  "procedural_scene": "workshop",
  "hotspots": [
    {
      "id": "workbench",
      "name": "Workbench",
      "rect": [120, 80, 60, 40],
      "verbs": ["look", "use"],
      "tags": ["furniture"]
    }
  ],
  "actions": [
    {
      "verb": "look",
      "target": "workbench",
      "then": [{ "print": "A sturdy wooden bench covered in tools." }]
    }
  ],
  "events": [
    {
      "trigger": "enter",
      "do": [{ "print": "Sawdust crunches underfoot." }]
    }
  ]
}
```

### Room Drawer Function

Register a drawable function in `WireframeMain.gd`:

```gdscript
_canvas.register_room_drawer("workshop", _draw_workshop)

func _draw_workshop(c: WireframeCanvas) -> void:
    var green := WireframeCanvas.DEFAULT_COLOR
    var dim := WireframeCanvas.DIM_COLOR

    # Workbench
    c.dr(Rect2(120, 80, 60, 8), green, false)

    # Tools hanging on wall
    c.dl(Vector2(130, 40), Vector2(130, 70), dim)
    c.dl(Vector2(150, 35), Vector2(150, 70), dim)
    c.dl(Vector2(170, 42), Vector2(170, 70), dim)
```

Load a room at runtime:

```gdscript
_canvas.load_scene("workshop")
```

## Entity Animation

Use `EntityRenderer` for things that should jitter, flicker, or phase in/out:

```gdscript
var entity_renderer := EntityRenderer.new()
add_child(entity_renderer)
entity_renderer.register_entity("ghost", _draw_ghost)
entity_renderer.show_entity("ghost")
entity_renderer.set_jitter_strength(0.7)
entity_renderer.set_phase(EntityRenderer.Phase.LINE_DROP)
```

## CRT Pipeline

The `CRTPipeline` node handles all post-processing:

- **Phosphor decay** — trails and afterglow
- **CRT screen shader** — scanlines, barrel distortion, glow
- **Glass reflection** — subtle screen reflection overlay

Toggle complex effects at runtime:

```gdscript
_pipeline.extra_crt_effects = true   # phosphor decay, shimmer, breathing, reflection
_pipeline.extra_crt_effects = false  # clean output, just scanlines and barrel distortion
```

## Testing with GRB

With Godot Runtime Bridge running, use these MCP tools:

| Tool | Purpose |
|------|---------|
| `grb_launch` | Start the game |
| `grb_screenshot` | Capture current viewport |
| `grb_get_errors` | Check for runtime errors |
| `grb_call_method` | Call methods on nodes |
| `grb_run_custom_command` | Run registered game commands |
| `grb_scene_tree` | Inspect the scene tree |
| `grb_quit` | Stop the game |

## Project Structure

```
aesthetic-engine-builder/
├── project.godot
├── main.tscn
├── addons/
│   ├── godot-runtime-bridge/       # GRB addon — TCP debug server + MCP bridge
│   └── grb-builder/                # Aesthetic Engine Builder addon
│       ├── plugin.cfg
│       ├── editor/
│       │   └── BuilderDock.gd      # Design wizard + prompt generator
│       ├── runtime/
│       │   ├── WireframeCanvas.gd  # Command-buffer renderer
│       │   ├── CRTPipeline.gd     # CRT post-processing
│       │   ├── RoomLoader.gd      # JSON room loader
│       │   └── EntityRenderer.gd  # Animated entities
│       └── shaders/
│           ├── crt_screen.gdshader
│           ├── crt_green_glow.gdshader
│           ├── phosphor_decay.gdshader
│           └── crt_reflection.gdshader
├── content/
│   └── rooms/                      # Room JSON files
├── game/
│   ├── WireframeMain.gd           # Your game code (AI writes here)
│   └── sound_editor/              # Retro synth + step sequencer
└── docs/
    ├── CURSOR_WORKFLOW.md          # This file
    └── TENNIS_TUTORIAL.md          # Sample game walkthrough
```
