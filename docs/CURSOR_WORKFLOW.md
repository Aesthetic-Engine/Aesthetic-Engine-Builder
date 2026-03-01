# Aesthetic Engine Builder — Cursor Workflow

Build 1983-style wireframe games entirely in Cursor. No editor, no sprites, no generative AI — pure math-generated graphics.

## Quick Start

1. Open the project folder in Cursor.
2. Open the project once in Godot to let it import (File → Open Project).
3. From now on, edit `.gd` and `.json` files in Cursor. Run via GRB.

## Adding a New Room

### Step 1: Create the room JSON

Create `content/rooms/<room_id>.json`:

```json
{
  "id": "kitchen",
  "title": "Kitchen",
  "procedural": true,
  "procedural_scene": "kitchen",
  "hotspots": [
    {
      "id": "sink",
      "name": "Kitchen Sink",
      "rect": [0.6, 0.3, 0.15, 0.15],
      "verbs": ["look", "use"],
      "tags": ["fixture"]
    }
  ],
  "actions": [
    {
      "verb": "look",
      "target": "sink",
      "then": [{ "print": "A stainless steel sink. The faucet drips steadily." }]
    },
    {
      "verb": "use",
      "target": "sink",
      "then": [{ "print": "You turn the tap. Brown water sputters out." }]
    }
  ],
  "events": [
    {
      "trigger": "enter",
      "do": [{ "print": "The kitchen smells of old grease and forgotten meals." }]
    }
  ]
}
```

### Step 2: Write the drawer function

In `game/WireframeMain.gd`, add a registration and drawer:

```gdscript
func _register_room_drawers() -> void:
    _canvas.register_room_drawer("foyer", _draw_foyer)
    _canvas.register_room_drawer("kitchen", _draw_kitchen)  # new

func _draw_kitchen(canvas: WireframeCanvas) -> void:
    var green := WireframeCanvas.DEFAULT_COLOR
    var dim := WireframeCanvas.DIM_COLOR
    var wall_y := canvas.draw_interior_base(0.42)

    # Countertop along right wall
    var counter_x := canvas.px(0.55)
    var counter_y := wall_y + 8
    canvas.dr(Rect2(counter_x, counter_y, canvas.px(0.4), 4), green)

    # Sink basin
    var sink_x := canvas.px(0.65)
    canvas.dr(Rect2(sink_x, counter_y + 4, 20, 12), dim)

    # Faucet
    canvas.dl(Vector2(sink_x + 10, counter_y), Vector2(sink_x + 10, counter_y - 14), green)
    canvas.dl(Vector2(sink_x + 10, counter_y - 14), Vector2(sink_x + 16, counter_y - 10), green)

    # Stove on left wall
    var stove_x := canvas.px(0.1)
    canvas.dr(Rect2(stove_x, counter_y, canvas.px(0.18), canvas.py(0.12)), dim)
    # Burners
    for i in range(4):
        var bx := stove_x + 6 + (i % 2) * 16
        var by := counter_y + 4 + (i / 2) * 10
        canvas.dr(Rect2(bx, by, 8, 8), dim)
```

### Step 3: Load it

```gdscript
load_room("kitchen")
```

Or via GRB: send `run_custom_command` with `{ "cmd_name": "load_room", "args": { "room_id": "kitchen" } }`

## Drawing Tips

### Proportional coordinates
Use `canvas.px(frac)` and `canvas.py(frac)` so rooms look right at any resolution. The virtual resolution is 320×200.

### Interior perspective
`canvas.draw_interior_base(wall_frac)` draws floor, walls, ceiling lines, and vanishing-point perspective. It returns the wall_y position so you can place furniture relative to it.

### Furniture patterns
- **Tables/shelves**: Use `canvas.dr()` for rectangular surfaces
- **Chairs**: Combine `canvas.dl()` lines for legs and back
- **Windows**: `canvas.dr()` for frame + `canvas.dl()` for mullions
- **Lamps**: `canvas.dl()` for stand + small `canvas.dr()` filled for shade

### Entity animation
Use `EntityRenderer` for anything that should jitter, flicker, or phase in/out:

```gdscript
var entity_renderer := EntityRenderer.new()
add_child(entity_renderer)
entity_renderer.register_entity("shadow", _draw_shadow)
entity_renderer.show_entity("shadow")
entity_renderer.set_jitter_strength(0.7)
entity_renderer.set_phase(EntityRenderer.Phase.LINE_DROP)
```

## Testing with GRB

With GRB running, use these commands in Cursor:

```
grb_screenshot                          # capture current viewport
run_custom_command load_room kitchen    # switch rooms
run_custom_command list_rooms           # list available rooms
grb_scene_tree                          # inspect scene
grb_call_method Main load_room kitchen  # alternative room load
```

## Project Structure

```
aesthetic-engine-builder/
├── project.godot                       # Godot project config
├── main.tscn                           # Main scene
├── addons/
│   ├── godot-runtime-bridge/           # GRB addon (symlink or copy)
│   └── grb-builder/                    # Aesthetic Engine Builder addon
│       ├── plugin.cfg
│       ├── runtime/
│       │   ├── WireframeCanvas.gd      # Command-buffer renderer
│       │   ├── RoomLoader.gd           # JSON room loader
│       │   ├── CRTPipeline.gd          # CRT post-processing
│       │   └── EntityRenderer.gd       # Animated entities
│       └── shaders/
│           ├── crt_green_glow.gdshader
│           ├── crt_screen.gdshader
│           ├── phosphor_decay.gdshader
│           └── crt_reflection.gdshader
├── content/
│   └── rooms/                          # Room JSON files
│       ├── foyer.json
│       └── empty.json
├── game/
│   └── WireframeMain.gd               # Game controller
├── .cursor/
│   └── rules/
│       └── grb-builder.mdc            # Cursor rules
└── docs/
    └── CURSOR_WORKFLOW.md              # This file
```
