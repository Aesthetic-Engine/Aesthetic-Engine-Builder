# Aesthetic Engine Builder

**Build complete 1983-style wireframe games entirely via AI prompting — no sprites, no textures, no editor. Just math and lines.**

Answer 5 game design questions in the Godot editor, copy the generated prompt, paste it into Cursor Agent chat, and watch a fully playable CRT wireframe game appear. Scanlines, phosphor glow, barrel distortion — the full 1983 microcomputer aesthetic, all code-generated.

## What You Get

- **5-pillar design wizard** — answer questions about Goals, Rules, Interaction, Conflict, and Outcomes to describe any game you can imagine
- **CRT shader pipeline** — phosphor decay, scanlines, barrel distortion, glow, glass reflection. Looks like a real monitor from 1983
- **Wireframe drawing engine** — lines, rectangles, polygons. Resolution-independent, proportional coordinates. Everything is math
- **AI-verified builds** — generated prompts tell Cursor to launch the game via GRB, take a screenshot, and verify the result before reporting done
- **Built-in sound editor** — optional retro synth + step sequencer (Intel 8253 pitch quantization, WAV export) that can be toggled into your game's main menu
- **Zero generative AI art** — all visuals are code-drawn vector graphics. No copyright concerns, no controversy, no dependencies on image models

## How It Works

1. Install the addon in Godot 4.5+
2. Click the **Aesthetic Engine Builder** tab in the bottom panel
3. Answer the 5 design pillar questions (examples and tooltips guide you)
4. Optionally toggle **Include Sound Editor** to add a retro synth to your game
5. Click **Generate Prompt** → **Copy to Clipboard**
6. Paste into Cursor Agent chat
7. Cursor builds your game, launches it, and screenshots the result

From there, keep prompting. *"Add a title screen." "Make the enemies faster." "Add a high score table."* The game is yours to extend.

## Quick Start

**Option 1 — Manual steps**

1. Clone this repo or download from the Godot Asset Library.
2. Open the project in Godot 4.5+ to import.
3. Open the project folder in Cursor: **File → Open Folder**.
4. Configure `.cursor/mcp.json` with the GRB MCP server and your `GODOT_PATH` (path to your Godot executable):

```json
{
  "mcpServers": {
    "godot-runtime-bridge": {
      "command": "node",
      "args": ["C:/path/to/mcp/index.js"],
      "env": {
        "GODOT_PATH": "C:/path/to/Godot_v4.x.exe"
      }
    }
  }
}
```

5. In Cursor: **Settings → Tools & MCP** → enable **godot-runtime-bridge**.
6. Click the **Aesthetic Engine Builder** tab, answer the 5 design questions, generate a prompt, paste into Cursor Agent chat.

**Option 2 — Let Cursor set it up**

1. Clone this repo, open in Godot once to import, then open the folder in Cursor.
2. Drop this prompt into **Cursor Agent mode**:

   > Set up the Godot Runtime Bridge (GRB) for this project. Install the addon if missing, create .cursor/mcp.json with the GRB MCP server (args: path to mcp/index.js), add GODOT_PATH to env with the path to my Godot executable — search common locations or ask me. Run npm install in the mcp folder if needed. Tell me when done.

3. Go to **Cursor Settings → Tools & MCP** and verify **godot-runtime-bridge** is enabled under Installed MCP Servers.
4. Ask Cursor: *"Connect to Godot via the GRB bridge and confirm once connected."*
5. Click the **Aesthetic Engine Builder** tab, answer the 5 design questions, and go.

## Includes

- **Godot Runtime Bridge (GRB)** — TCP debug server and MCP bridge that lets Cursor launch, observe, control, and test your running game
- **WireframeCanvas** — command-buffer renderer with `dl()`, `dr()`, `dp()` drawing API
- **CRTPipeline** — SubViewport rendering chain with phosphor decay, CRT shader, and glass reflection
- **EntityRenderer** — animated wireframe entities with jitter, line-drop, and phase effects
- **RoomLoader** — JSON-driven room system with hotspots and actions
- **Sound Editor** — retro synth + step sequencer with Intel 8253 pitch quantization and WAV export
- **15 QA missions** — automated test loops Cursor can run against your game

## Architecture

```
WireframeCanvas (320×200 virtual resolution)
    └─ Room drawers: dl(), dr(), dp() → command buffer → _draw()
         └─ CRTPipeline: SubViewport → phosphor decay → CRT shader → glass reflection
              └─ Full-screen output
```

## Tutorials

- [Building a Tennis Game](docs/TENNIS_TUTORIAL.md) — step-by-step walkthrough of the included sample game
- [Cursor Workflow](docs/CURSOR_WORKFLOW.md) — how to build rooms and games via prompts

## Requirements

- Godot 4.5+
- [Cursor](https://cursor.sh) (or any MCP-compatible AI agent)
- Node.js (for the MCP bridge)

## License

MIT
