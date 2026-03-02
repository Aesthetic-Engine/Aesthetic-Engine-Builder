# The Future of Aesthetic Engine Builder

*A roadmap toward NES-style math-generated graphics, an honest audit of current limits, and the signals that tell you it's time for version 2.0.*

---

## Where We Are

Aesthetic Engine Builder 1.0 produces **1983-style vector/wireframe graphics** — the aesthetic of Vectrex, early Atari arcade cabinets, and Apple II games. A 320×200 virtual canvas, green phosphor glow, scanlines, barrel distortion. Everything is lines, rectangles, and polygons drawn in GDScript by a Cursor agent that's never touched an image file.

This is genuinely useful and genuinely novel. But it is not yet NES.

The NES era (1985–1994) introduced **tile-based raster graphics** — a completely different visual paradigm. Sprites, background tilemaps, character ROM, palette tables, hardware scrolling. Going there from here is not a shader tweak. It's a different engine.

Here's what it takes.

---

## The Aesthetic Gap: Wireframe → NES

### What NES graphics actually are

The NES Picture Processing Unit (PPU) renders:

- **Tiles** — 8×8 pixel blocks drawn from a 256-tile character ROM
- **Background tilemaps** — a 32×30 grid of tile indices + palette selectors
- **Sprites** — up to 64 hardware sprites (8×8 or 8×16), each with an x/y position, tile index, palette, and flip flags
- **Palettes** — 4 background palettes + 4 sprite palettes, each with 4 colors from a 54-color master palette
- **Hardware scrolling** — the background tilemap scrolls pixel-by-pixel via a scroll register

None of this is diffusion model art. All of it is **math and data** — tile patterns defined as bitmaps, tilemaps defined as integer arrays, palettes defined as color index tables. A sufficiently capable AI can generate all of it as code.

### What AE Builder 1.0 can't do

| NES Capability | AE Builder 1.0 |
|----------------|----------------|
| Tile rendering | ❌ No tile system |
| Sprite system | ❌ No sprite layer |
| Palette tables | ❌ Single green phosphor palette |
| Hardware scrolling | ❌ Static canvas |
| Raster scanline effects | Partial (shader only) |
| Color | ❌ Monochrome |
| Background/foreground layers | ❌ Single draw layer |

---

## The Roadmap to AE Builder 2.0

### Phase 1 — Color (Near-term, buildable now)

The CRTPipeline already supports arbitrary shader output. The first step toward NES is adding **palette-based color** to WireframeCanvas.

- Replace `DEFAULT_COLOR` / `DIM_COLOR` constants with a configurable 4-color palette (background + 3 foreground colors)
- Add `set_palette(colors: Array[Color])` to WireframeCanvas
- Update the CRT shader to apply palette-to-phosphor color mapping
- The BuilderDock wizard adds a palette question: "What 3 colors define this game's world?"

**Bottleneck:** The BuilderDock prompt currently hardcodes green. Palette support requires the prompt generator to communicate a color scheme to the agent, and the agent to apply it consistently. This is a prompt engineering problem as much as a code problem.

**Effort:** Medium. Achievable in a focused sprint.

---

### Phase 2 — Tile Engine (The Big Leap)

This is the heart of NES-style graphics. You need:

1. **A TileCanvas class** to replace or extend WireframeCanvas
   - Stores a character ROM: an array of 256 tiles, each a `PackedByteArray` of 64 pixels (8×8)
   - Stores a tilemap: a 32×30 grid of `[tile_index, palette_index]` pairs
   - Renders via Godot's `draw_texture_rect` or a custom shader that samples the tile ROM

2. **A SpriteLayer** on top of the tilemap
   - Up to 64 sprites with x, y, tile_index, palette, flip_h, flip_v
   - Rendered as a separate SubViewport composited over the background

3. **A palette system**
   - 8 palettes (4 bg + 4 sprite), 4 colors each
   - Colors drawn from a configurable master palette

4. **Scroll registers** — offset the tilemap viewport by (scroll_x, scroll_y) pixels

**The hard part for AI generation:** Tiles are bitmaps. An AI agent writing GDScript cannot "see" what a tile looks like while generating it. It writes:
```gdscript
# Tile 0: solid ground block
_tiles[0] = PackedByteArray([
    1,1,1,1,1,1,1,1,
    1,0,0,0,0,0,0,1,
    1,0,1,1,1,1,0,1,
    ...
])
```

This works — but iterating on the visual result requires a screenshot-feedback loop for every tile change, which is slow. The agent is essentially doing pixel art blind.

**Bottleneck:** Context window and iteration speed. A full NES-style game might have 100+ tiles, each 64 bytes of pixel data. That's 6,400 bytes of tile ROM to specify, plus tilemap data, plus sprite data. This is at the edge of what current context windows can hold and reason about coherently in a single pass.

**Effort:** High. This phase probably defines AE Builder 2.0 rather than being a 1.x update.

---

### Phase 3 — GRB as the Tile Debugger

Once a tile engine exists, GRB becomes dramatically more powerful for iteration:

- `grb_run_custom_command(name="set_tile", args={"index": 5, "data": [...]})` — hot-swap a single tile at runtime
- `grb_run_custom_command(name="set_tilemap_cell", args={"x": 4, "y": 2, "tile": 5, "palette": 1})` — paint the map live
- `grb_run_custom_command(name="dump_tile_rom")` — export current tile ROM as GDScript array for the agent to edit
- `grb_screenshot()` — immediately shows the result

This closes the feedback loop. Instead of restarting the game for every tile change, the agent can:
1. Request current tile ROM via `dump_tile_rom`
2. Generate modified GDScript array
3. Hot-swap via `set_tile`
4. Screenshot to verify
5. Repeat

**This is where the NES workflow becomes viable for AI agents.** Without hot-swap, the tile iteration loop is too slow. With it, an agent can converge on correct pixel art through screenshot feedback — no human eyes required.

**Effort:** Medium, dependent on Phase 2 being complete.

---

### Phase 4 — Audio

The NES audio processing unit (APU) generates:
- 2 pulse wave channels (square waves with variable duty cycle)
- 1 triangle wave channel
- 1 noise channel  
- 1 DPCM sample channel

AE Builder 1.0 already has a **retro synth** with Intel 8253 pitch quantization and WAV export. This is closer to the APU than it looks — the 8253 timer chip is what the NES APU is based on.

**Phase 4 work:**
- Constrain the synth to APU channel types (no arbitrary waveforms)
- Add a duty cycle control to the pulse channels (12.5%, 25%, 50%, 75%)
- Add noise channel with period table matching NES noise periods
- Add the NES master pitch table (the 88 note frequencies the APU actually supports)
- Expose these as `grb_run_custom_command` targets for agent control

**Bottleneck:** The synth is already built. This is a constraint and API question, not a capability question.

---

## The Absolute Limits

### Limit 1: Context window vs. game complexity

A 1983 wireframe game fits in a context window. A 1987 NES game does not.

A complete NES game (say, a Mega Man level) has:
- ~200 unique tiles × 64 bytes = 12,800 bytes of tile data
- ~960 tilemap cells × 2 bytes = 1,920 bytes of map data
- ~50 sprites × 6 bytes = 300 bytes of sprite data
- Sound patterns, enemy AI state machines, physics parameters

Total: 20,000+ bytes of structured game data, plus all the GDScript logic. Current 200K token context windows can hold this — but barely, and the agent's coherence degrades toward the end. Complex enemy AI + full tile ROM + tilemap in a single prompt risks drift, hallucination, and silent parse failures.

**The wall:** You cannot generate a full NES-quality game in one prompt. You need multi-session, incremental, saved-state workflows where the agent picks up where it left off. This requires either much larger context windows, or a fundamentally different architecture where game data is stored in files the agent reads and writes incrementally.

### Limit 2: GDScript parse errors at scale

We already hit this in Test 3. A 350-line GDScript file with complex data structures silently fails to load. A NES-style game with tile ROM arrays could easily be 800-1,200 lines.

The fix we built (stderr capture, incremental build strategy, `get_child_count()` diagnostics) works — but it requires the agent to be disciplined about incremental commits. One bad line in a 1,000-line file is still a silent failure with no line number.

**The wall:** GDScript is not designed for data-heavy files. A tile ROM should live in a binary file or a resource, not as a GDScript array. AE Builder 2.0 probably needs a custom binary tile ROM format (`.aetiles`) that the engine loads directly and the agent generates separately from the game logic.

### Limit 3: Screenshot feedback latency

Currently the agent loop is:
1. Write code (fast — LLM generation)
2. Launch Godot (1-2 seconds)
3. Screenshot (near-instant)
4. Quit (near-instant)
5. Analyze screenshot (fast — LLM vision)
6. Iterate

Total loop: ~3-5 seconds per iteration. For wireframe games this is fine — each iteration changes the whole visual dramatically.

For tile art iteration, you might need 50+ iterations to converge on a single correct tile. At 5 seconds each, that's 4+ minutes for one tile. For 100 tiles: over 6 hours of iteration time.

**The wall:** The screenshot-restart loop does not scale to tile art iteration. You need hot-swap (Phase 3) to make this viable. Even then, LLM vision models have limited resolution — they can tell "this tile is wrong" but struggle to specify exactly which pixels need to change.

### Limit 4: LLM vision and pixel-level reasoning

Current vision models (GPT-4o, Claude) can analyze screenshots well at the scene level. They can say "the player character looks blocky" or "the background pattern is too busy." They cannot reliably say "pixel at row 3, column 5 should be color index 2 instead of 1."

For NES tile art, you need pixel-level feedback. This requires either:
- Dramatically better vision model spatial reasoning, or
- A GRB tool that returns the raw pixel data of a tile from the running game, so the agent can reason about it numerically rather than visually

**The wall:** Vision model spatial resolution is currently insufficient for reliable pixel-art iteration. This is a capability that needs to advance before the NES workflow fully closes.

### Limit 5: Godot's tile system overhead

Godot 4 has a `TileMapLayer` built in, but it's designed for human authorship (the TileSet editor, collision shapes, physics layers). Procedurally generating a TileSet entirely from GDScript — bypassing the editor — is possible but fights the engine's design. The API is verbose and the resource system expects assets to originate from the editor.

A cleaner approach for AE Builder is a **custom tile renderer** (a Control node with a custom shader that samples a tile ROM texture), completely bypassing `TileMapLayer`. This is more work upfront but gives total control and is fully agent-compatible.

**The wall:** Godot's TileMapLayer is editor-first. Pure-code tile rendering requires building around it, not through it.

---

## The Signals: When to Build AE Builder 2.0

Watch for these inflection points. When several of them arrive together, it's time.

### Signal 1: Context windows reach 1M tokens reliably
*Current: GPT-4o ~128K, Claude ~200K*

When leading models sustain 1M+ tokens with strong coherence at the tail, a complete NES game — tile ROM, tilemap, sprites, AI, audio — fits in a single context. The incremental build workaround becomes optional rather than mandatory.

### Signal 2: LLM vision can specify pixel coordinates accurately
*Current: Scene-level analysis only*

When you can say "here's a screenshot of tile 5" and the model replies "pixel (3,5) should be #1 and pixel (4,5) should be #2" reliably, tile art iteration via screenshot becomes viable without a custom GRB pixel-dump tool.

### Signal 3: Agent tools support persistent state across sessions
*Current: Each Cursor agent session starts cold*

When AI coding agents maintain project memory across sessions — knowing what tiles exist, what the tilemap looks like, what's been built and what hasn't — multi-session NES game construction becomes natural. Right now, a fresh session has to re-read the entire codebase to understand where things stand.

### Signal 4: Code generation speed drops below 1 second per file
*Current: 5-30 seconds for complex files*

Tile iteration requires many fast loops. When code generation is near-instant, the human time cost of "50 tile iterations" drops from "come back tomorrow" to "watch it happen."

### Signal 5: AE Builder 1.0 consistently produces complete, playable games
*Current: Test 4 of 4 required multiple debug sessions*

The wireframe foundation needs to be rock-solid before adding the NES layer. When agents reliably build complete 1983-style games in one pass — no silent parse failures, no coordinate system confusion, no `queue_redraw()` mistakes — the foundation is ready for the next floor.

**This signal is the most important and the most in your control.** Every test game you build, every post-mortem you write, every fix you add to the BuilderDock prompt makes the foundation more solid. AE Builder 2.0 starts with AE Builder 1.0 working perfectly.

---

## The Version That Lives Between

Before NES, there's a natural **v1.5** that doesn't require a tile engine:

- **Color palettes** — 4-color palettes selectable in the wizard (Phase 1)
- **Sprite-like entities** — EntityRenderer extended to support multiple simultaneous animated entities with z-ordering
- **Horizontal scrolling** — WireframeCanvas extended with a viewport offset for side-scrolling levels
- **Sound constraints** — APU-faithful audio (Phase 4)

This gets you to **early Atari 2600 / ZX Spectrum** aesthetic territory — still math-drawn, still code-generated, but with color and motion complexity that approaches early NES games.

v1.5 is achievable with the current architecture. It keeps the project moving while you wait for the signals that make full NES viable.

---

## Summary

| Milestone | Blocker | Timeline |
|-----------|---------|----------|
| **v1.0 — Wireframe, green phosphor** | ✅ Shipped | Now |
| **v1.5 — Color palettes, scrolling** | Prompt engineering, WireframeCanvas extension | Months |
| **v2.0 — Tile engine, sprites** | Context window coherence, hot-swap via GRB | 1-2 years |
| **v2.5 — Full NES fidelity** | LLM pixel-level vision, agent persistent memory | 2-4 years |

The wireframe era is not a compromise. The constraint of math-only graphics is what makes the tool work today — it fits in a context window, it generates in a single pass, it verifies via screenshot in seconds. The 1983 aesthetic is not a stepping stone. It's the product.

But the road is clearly visible from here. And the signals will tell you when to start building it.
