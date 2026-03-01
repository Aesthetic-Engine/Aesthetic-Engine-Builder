@tool
extends VBoxContainer

const VERSION := "1.0.0"

# ── Pillar definitions ──

const PILLARS: Array[Dictionary] = [
	{
		"label": "1. Goals and Objectives",
		"question": "What is the ultimate triumph in this digital world, and what single, repeatable action brings the player closer to achieving it?",
		"placeholder": "e.g. Surviving an endless swarm by absorbing their core energy",
		"tooltip": "Examples:\n• Absorb enemy core energy to survive increasingly dense waves\n• Descend through a procedural cavern, collecting artifacts before the light runs out\n• Rotate star clusters to match target patterns before time expires",
	},
	{
		"label": "2. Rules and Constraints",
		"question": "What universal physical laws govern this space, and what strict limitations are placed upon the player's capabilities?",
		"placeholder": "e.g. Zero gravity, but every movement expends finite fuel",
		"tooltip": "Examples:\n• No gravity — each thrust burns finite fuel; stop moving or die floating\n• Player can only move in 4 cardinal directions on a strict grid\n• World wraps horizontally but has solid ceiling and floor",
	},
	{
		"label": "3. Interaction and Agency",
		"question": "How does the player exert their will upon the world? Describe the tactile sensation of movement and action.",
		"placeholder": "e.g. Aim a reticle with the mouse, charge like a slingshot, release to propel",
		"tooltip": "Examples:\n• Aim reticle with mouse, hold to charge, release to propel projectile\n• Tap spacebar on beat to morph between 3 shapes, each with different physics\n• Left stick controls avatar, right stick controls a floating shield",
	},
	{
		"label": "4. Conflict and Opposition",
		"question": "What specific forces or entities actively push back against the player, and how do their behaviors manifest geometrically?",
		"placeholder": "e.g. A relentless hunter algorithm that learns the player's pathing preferences",
		"tooltip": "Examples:\n• Enemy tracks player's movement history and predicts next position\n• Arena shrinks concentrically each wave, forcing closer combat\n• Small enemies cluster, then detonate in geometric shrapnel patterns",
	},
	{
		"label": "5. Outcomes and Feedback",
		"question": "When a crucial interaction succeeds or fails, how does the world physically shatter, flash, or shake to communicate this outcome?",
		"placeholder": "e.g. Enemies fracture into shards that retain momentum and bounce off walls",
		"tooltip": "Examples:\n• Destroyed enemies split into vector shards that bounce off walls\n• Successful parry freezes screen for 2 frames and inverts all colors\n• Each explosion permanently burns a dark crater into the terrain",
	},
]

# ── UI state ──
var _content: VBoxContainer
var _pillar_edits: Array[TextEdit] = []

var _title_edit: LineEdit
var _godot_exe_edit: LineEdit
var _project_path_edit: LineEdit
var _sound_toggle: CheckButton
var _crt_effects_toggle: CheckButton
var _extra_edit: TextEdit
var _generate_btn: Button

var _output_section: VBoxContainer
var _prompt_display: TextEdit
var _copy_btn: Button


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 300

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	_build_header()
	_build_title_field()
	_build_path_fields()
	_build_pillar_fields()
	_build_options()
	_build_prompt_output()


func _build_header() -> void:
	var title := Label.new()
	title.text = "Aesthetic Engine Builder v%s" % VERSION
	title.add_theme_font_size_override("font_size", 15)
	_content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Answer the 5 design pillars below, then generate a prompt for Cursor."
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(subtitle)

	_content.add_child(HSeparator.new())


func _build_title_field() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Game Title (optional):"
	lbl.custom_minimum_size.x = 140
	row.add_child(lbl)
	_title_edit = LineEdit.new()
	_title_edit.placeholder_text = "My Game"
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title_edit)
	_content.add_child(row)


func _build_path_fields() -> void:
	var godot_row := HBoxContainer.new()
	godot_row.add_theme_constant_override("separation", 8)
	var godot_lbl := Label.new()
	godot_lbl.text = "Godot Executable:"
	godot_lbl.custom_minimum_size.x = 140
	godot_row.add_child(godot_lbl)
	_godot_exe_edit = LineEdit.new()
	_godot_exe_edit.placeholder_text = "C:/path/to/Godot_v4.x.exe"
	_godot_exe_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Engine.is_editor_hint():
		_godot_exe_edit.text = OS.get_executable_path().replace("\\", "/")
	godot_row.add_child(_godot_exe_edit)
	_content.add_child(godot_row)

	var proj_row := HBoxContainer.new()
	proj_row.add_theme_constant_override("separation", 8)
	var proj_lbl := Label.new()
	proj_lbl.text = "Project Path:"
	proj_lbl.custom_minimum_size.x = 140
	proj_row.add_child(proj_lbl)
	_project_path_edit = LineEdit.new()
	_project_path_edit.placeholder_text = "C:/path/to/project"
	_project_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Engine.is_editor_hint():
		_project_path_edit.text = ProjectSettings.globalize_path("res://").replace("\\", "/")
	proj_row.add_child(_project_path_edit)
	_content.add_child(proj_row)


func _build_pillar_fields() -> void:
	for pillar: Dictionary in PILLARS:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 2)

		var heading := Label.new()
		heading.text = pillar["label"]
		heading.add_theme_font_size_override("font_size", 13)
		section.add_child(heading)

		var question := Label.new()
		question.text = pillar["question"]
		question.add_theme_font_size_override("font_size", 10)
		question.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(question)

		var edit := TextEdit.new()
		edit.placeholder_text = pillar["placeholder"]
		edit.tooltip_text = pillar["tooltip"]
		edit.custom_minimum_size = Vector2(0, 60)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		section.add_child(edit)
		_pillar_edits.append(edit)

		_content.add_child(section)


func _build_options() -> void:
	_content.add_child(HSeparator.new())

	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "Include Sound Editor"
	_sound_toggle.tooltip_text = "Adds a retro synth + step sequencer to the game's main menu"
	_content.add_child(_sound_toggle)

	_crt_effects_toggle = CheckButton.new()
	_crt_effects_toggle.text = "Extra CRT Effects"
	_crt_effects_toggle.tooltip_text = "Enables phosphor shimmer, breathing, beam refresh, phosphor decay trails, and glass reflection. Turn off for a cleaner display."
	_crt_effects_toggle.button_pressed = false
	_crt_effects_toggle.toggled.connect(_on_crt_effects_toggled)
	_content.add_child(_crt_effects_toggle)

	var extra_lbl := Label.new()
	extra_lbl.text = "Extra instructions for Cursor (optional):"
	extra_lbl.add_theme_font_size_override("font_size", 11)
	extra_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_content.add_child(extra_lbl)

	_extra_edit = TextEdit.new()
	_extra_edit.placeholder_text = "Any special requests... (e.g. 'add a title screen', 'make the enemies faster')"
	_extra_edit.custom_minimum_size = Vector2(0, 50)
	_extra_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extra_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_content.add_child(_extra_edit)

	_generate_btn = Button.new()
	_generate_btn.text = "Generate Prompt"
	_generate_btn.tooltip_text = "Build a Cursor prompt from your answers"
	_generate_btn.pressed.connect(_on_generate_pressed)
	_content.add_child(_generate_btn)


func _build_prompt_output() -> void:
	_output_section = VBoxContainer.new()
	_output_section.add_theme_constant_override("separation", 4)
	_output_section.visible = false

	_content.add_child(HSeparator.new())

	var heading := Label.new()
	heading.text = "Your prompt — paste into Cursor Agent chat"
	heading.add_theme_font_size_override("font_size", 13)
	_output_section.add_child(heading)

	_prompt_display = TextEdit.new()
	_prompt_display.editable = false
	_prompt_display.custom_minimum_size = Vector2(0, 140)
	_prompt_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_display.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output_section.add_child(_prompt_display)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy to Clipboard"
	_copy_btn.tooltip_text = "Copy the generated prompt to your clipboard"
	_copy_btn.pressed.connect(_on_copy_pressed)
	btn_row.add_child(_copy_btn)

	var hint := Label.new()
	hint.text = "Then paste into Cursor Agent chat and hit Enter."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(hint)

	_output_section.add_child(btn_row)
	_content.add_child(_output_section)


# ── Callbacks ──

func _on_generate_pressed() -> void:
	var has_any := false
	for edit: TextEdit in _pillar_edits:
		if not edit.text.strip_edges().is_empty():
			has_any = true
			break
	if not has_any:
		_generate_btn.text = "Please answer at least one question first"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(_generate_btn):
				_generate_btn.text = "Generate Prompt"
		)
		return

	_prompt_display.text = _build_prompt()
	_output_section.visible = true

	_generate_btn.text = "Prompt generated — scroll down to copy"
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(_generate_btn):
			_generate_btn.text = "Generate Prompt"
	)


func _on_crt_effects_toggled(enabled: bool) -> void:
	var pipeline := _find_crt_pipeline()
	if pipeline:
		pipeline.set_extra_crt_effects(enabled)


func _find_crt_pipeline() -> CRTPipeline:
	var root := get_tree().get_root()
	if not root:
		return null
	var main := root.get_node_or_null("Main")
	if not main:
		return null
	for child in main.get_children():
		if child is CRTPipeline:
			return child
	return null


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_prompt_display.text)
	_copy_btn.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(_copy_btn):
			_copy_btn.text = "Copy to Clipboard"
	)


# ── Prompt Builder ──

func _build_prompt() -> String:
	var p: PackedStringArray = []
	var godot_exe := _godot_exe_edit.text.strip_edges()
	var project_path := _project_path_edit.text.strip_edges()

	p.append("You are building a game using Aesthetic Engine Builder's wireframe CRT pipeline in Godot 4.6.")
	p.append("")

	var title_text := _title_edit.text.strip_edges()
	if not title_text.is_empty():
		p.append("The game title is \"%s\"." % title_text)
		p.append("")

	# Build strategy — FIRST so agents read it before anything else
	p.append("## Build Strategy (MANDATORY — read this first)")
	p.append("You MUST build incrementally. Do NOT write the entire game in one pass.")
	p.append("Each increment must be under 150 lines of new code. If you write more than")
	p.append("200 lines without verifying, you WILL hit a silent parse error and waste the entire attempt.")
	p.append("")
	p.append("Steps:")
	p.append("1. Write boilerplate + menu screen with room drawer. Launch and verify.")
	p.append("2. Add player movement and input handling. Launch and verify.")
	p.append("3. Add game mechanics (enemies, collision, scoring). Launch and verify.")
	p.append("4. Add HUD, win/lose states, polish. Launch and verify.")
	p.append("")
	p.append("After EVERY launch, check if the script loaded:")
	p.append("```")
	p.append("grb_call_method(node=\"/root/Main\", method=\"get_child_count\")")
	p.append("```")
	p.append("If result is 0, the script failed to load. Diagnose:")
	p.append("  1. Check grb_get_errors() — if errors exist, it is a runtime crash in _ready()")
	p.append("  2. If no errors, it is a silent parse failure")
	p.append("  3. NEVER rewrite the entire file. Revert to the last working version,")
	p.append("     then add half the new code and test. Bisect until you find the bad line.")
	p.append("")

	# Pillar sections with architectural guidance
	var pillar_labels: Array[String] = [
		"Goals and Objectives",
		"Rules and Constraints",
		"Interaction and Agency",
		"Conflict and Opposition",
		"Outcomes and Feedback",
	]
	var pillar_arch: Array[String] = [
		"Architecture: Define victory/loss states as int constants (const ST_MENU := 0, const ST_PLAY := 1, etc.). Track progress in _process(delta) with state variables. Use _canvas.ds() for score display and _canvas.dt() for text rendering — these are built into WireframeCanvas.",
		"Architecture: Implement physics bounds in _physics_process(). Enforce limits as constants at the top of the file. Collision shapes must stay in sync with visual geometry.",
		"Architecture: Poll input with Input.is_action_just_pressed() in _process() for GRB compatibility — do NOT use _input(event) for keyboard actions. Use _unhandled_input(event) only for mouse events. Map to Godot actions (ui_up, ui_down, ui_left, ui_right, ui_accept). Godot's default actions map arrow keys only; for WASD support, poll raw keys via Input.is_key_pressed(KEY_W), Input.is_key_pressed(KEY_A), etc.",
		"Architecture (if applicable): Implement enemy/opponent behaviors as state machines with clear geometric movement patterns. Use PackedVector2Array for efficient bulk rendering. Centralized _draw() manager — avoid spawning individual nodes per entity. Skip this guidance if the design has no enemies or opponents.",
		"Architecture: Feedback effects (screen shake, flash, particle bursts) as immediate visual responses via queue_redraw(). Keep all effects purely procedural — no sprite assets.",
	]

	for i in range(PILLARS.size()):
		var answer := _pillar_edits[i].text.strip_edges()
		if answer.is_empty():
			continue
		p.append("## %s" % pillar_labels[i])
		p.append(answer)
		p.append(pillar_arch[i])
		p.append("")

	# CRT aesthetic constraints
	p.append("## CRT Aesthetic Constraints")
	p.append("- 1-bit monochrome phosphor palette (green on black)")
	p.append("- No antialiasing, integer-snapped coordinates only")
	p.append("- Raw vector/matrix math, no Sprite2D or texture assets")
	p.append("- WireframeCanvas drawing commands: dl() for lines, dr() for rectangles, dp() for polylines, dt() for text, ds() for scores")
	p.append("- DEFAULT_COLOR for player/interactive elements, DIM_COLOR for environment/background")
	p.append("")

	# Technical requirements
	p.append("## Technical Requirements")
	p.append("- Write game in game/WireframeMain.gd (extends Control, attached to main.tscn)")
	p.append("- Virtual canvas is 320×200 pixels. All game geometry uses absolute pixel coordinates in this space (not proportional 0.0-1.0 fractions). Use canvas.size.x and canvas.size.y for runtime access.")
	p.append("- Set draw_in_enabled = false for real-time rendering (true only for room-reveal animations)")
	p.append("- Use _physics_process(delta) for movement, gravity, and collision. Use _process(delta) for state timers, animation, input polling, and queue_redraw().")
	p.append("- Call _canvas.queue_redraw() every frame in _process() — you MUST call it on _canvas, not on self. Self has no _draw() override; only WireframeCanvas renders.")
	p.append("- Performance: centralized _draw() managers, PackedVector2Array for bulk geometry, avoid node bloat")
	p.append("")

	# GDScript 4.x Compatibility
	p.append("## GDScript 4.x Compatibility (CRITICAL)")
	p.append("Godot silently discards scripts with parse errors — no crash, no error log, just a blank screen.")
	p.append("Follow these rules to avoid silent parse failures:")
	p.append("- Do NOT use `enum` — use plain int constants: `const ST_MENU := 0`")
	p.append("- Do NOT use `const` for Array or Dictionary literals — use `var` initialized in `_ready()`")
	p.append("- Do NOT reference a `const` in a class-level `var` initializer — use the literal value: `var _state: int = 0` (not `var _state: int = ST_MENU`)")
	p.append("- Do NOT use `\\` line continuations — they can silently break parsing. Restructure long lines as multiple shorter statements instead.")
	p.append("- Use `str_val.to_int()` instead of `int(str_val)` for string-to-integer conversion")
	p.append("- Use `abs()` and `max()` (not `absf()` / `maxf()` which may not exist in all 4.x)")
	p.append("- Variable names must not shadow builtins (`exp`, `log`, `sin`, `clamp`, `lerp`, etc.)")
	p.append("- Avoid complex `match` statements — prefer `if`/`elif` chains")
	p.append("- Keep lines under 120 characters")
	p.append("- When reading from untyped Arrays, wrap values in float() or int() before arithmetic — Array[i] returns Variant, and operators like -= or % on Variants can silently fail")
	p.append("")

	# Canonical setup boilerplate
	p.append("## Setup Boilerplate")
	p.append("Minimum code to initialize the CRT pipeline in WireframeMain.gd:")
	p.append("```gdscript")
	p.append("extends Control")
	p.append("")
	p.append("var _pipeline: CRTPipeline")
	p.append("var _canvas: WireframeCanvas")
	p.append("")
	p.append("func _ready() -> void:")
	p.append("    _pipeline = CRTPipeline.new()")
	p.append("    _pipeline.set_anchors_preset(Control.PRESET_FULL_RECT)")
	if not _crt_effects_toggle.button_pressed:
		p.append("    _pipeline.extra_crt_effects = false")
	p.append("    add_child(_pipeline)")
	p.append("    _canvas = WireframeCanvas.new()")
	p.append("    _canvas.draw_in_enabled = false")
	p.append("    _canvas.size = Vector2(_pipeline.virtual_width, _pipeline.virtual_height)")
	p.append("    _pipeline.get_content_root().add_child(_canvas)")
	p.append("")
	p.append("func _process(_delta: float) -> void:")
	p.append("    _canvas.queue_redraw()  # MUST call on _canvas, not self")
	p.append("```")
	p.append("")

	# WireframeCanvas API Reference
	p.append("## WireframeCanvas API Reference")
	p.append("```")
	p.append("Constants:")
	p.append("  DEFAULT_COLOR = Color(0.2, 1.0, 0.2, 1.0)   # bright phosphor green — player/interactive")
	p.append("  DIM_COLOR     = Color(0.14, 0.55, 0.14, 1.0) # dim green — environment/background")
	p.append("  BG_COLOR      = Color(0.02, 0.03, 0.02, 1.0) # near-black — canvas background")
	p.append("")
	p.append("Drawing (call inside room drawer callbacks):")
	p.append("  dl(from: Vector2, to: Vector2, col: Color = DEFAULT_COLOR, width: float = 1.0) — line")
	p.append("  dr(rect: Rect2, col: Color = DEFAULT_COLOR, filled: bool = false, width: float = 1.0) — rectangle")
	p.append("  dp(points: PackedVector2Array, col: Color = DEFAULT_COLOR, filled: bool = false) — polygon/polyline")
	p.append("  dt(text: String, cx: float, y: float, col: Color = DEFAULT_COLOR) — centered text (3x5 font, A-Z 0-9 !)")
	p.append("  ds(val: int, x: float, y: float, col: Color = DEFAULT_COLOR) — seven-segment score (5 digits, 0-padded)")
	p.append("")
	p.append("Coordinate helpers (for proportional positioning if needed):")
	p.append("  px(frac: float) -> float  — fraction of canvas width to pixels")
	p.append("  py(frac: float) -> float  — fraction of canvas height to pixels")
	p.append("")
	p.append("Scene management:")
	p.append("  register_room_drawer(room_id: String, drawer: Callable)")
	p.append("    — drawer is called as drawer.call(canvas) where canvas is the WireframeCanvas")
	p.append("    — your function MUST accept one argument: func _draw_menu(c: WireframeCanvas) -> void")
	p.append("  load_scene(room_id: String)  — activate a room drawer")
	p.append("  clear_scene()  — deactivate drawing")
	p.append("```")
	p.append("")

	# main.tscn structure
	p.append("## main.tscn Structure")
	p.append("```")
	p.append("Root node: \"Main\" (Control) with script res://game/WireframeMain.gd")
	p.append("Node path for GRB calls: /root/Main")
	p.append("```")
	p.append("")

	# GRB Launch Command
	p.append("## GRB Launch Command")
	p.append("Use this exact MCP call to launch the game:")
	p.append("```")
	if not project_path.is_empty() and not godot_exe.is_empty():
		p.append("grb_launch(project_path=\"%s\"," % project_path)
		p.append("           godot_exe=\"%s\"," % godot_exe)
		p.append("           tier=2)")
	elif not project_path.is_empty():
		p.append("grb_launch(project_path=\"%s\", tier=2)" % project_path)
	elif not godot_exe.is_empty():
		p.append("grb_launch(godot_exe=\"%s\", tier=2)" % godot_exe)
	else:
		p.append("grb_launch(project_path=\"<SET IN BUILDER>\", godot_exe=\"<SET IN BUILDER>\", tier=2)")
	p.append("```")
	p.append("After launch: grb_get_errors() then grb_screenshot() to verify.")
	p.append("For state checks: grb_get_property(node=\"/root/Main\", property=\"_state\")")
	p.append("")

	# Reference snippets (trimmed — font/seven-seg now built into WireframeCanvas)
	p.append("## Reference Snippets (Known-Good GDScript 4.6)")
	p.append("Copy these verbatim. They are tested and compile cleanly.")
	p.append("")
	p.append("### State machine pattern")
	p.append("```gdscript")
	p.append("const ST_MENU := 0")
	p.append("const ST_PLAY := 1")
	p.append("const ST_WIN := 2")
	p.append("const ST_LOSE := 3")
	p.append("var _state: int = 0")
	p.append("var _state_timer: float = 0.0")
	p.append("```")
	p.append("")
	p.append("### Game loop pattern")
	p.append("```gdscript")
	p.append("func _process(delta: float) -> void:")
	p.append("    if _state == ST_PLAY:")
	p.append("        # ... game logic, input polling, timers ...")
	p.append("        pass")
	p.append("    _canvas.queue_redraw()  # MUST call on _canvas, not self")
	p.append("```")
	p.append("")
	p.append("### GRB command registration (for remote state queries)")
	p.append("```gdscript")
	p.append("func _register_grb_commands() -> void:")
	p.append("    var cmds := get_node_or_null(\"/root/GRBCommands\")")
	p.append("    if cmds and cmds.has_method(\"register_command\"):")
	p.append("        cmds.register_command(\"get_state\", func(_args: Dictionary) -> Dictionary:")
	p.append("            return {\"state\": _state, \"score\": _score, \"alive\": _alive}")
	p.append("        )")
	p.append("        cmds.register_command(\"set_state\", func(args: Dictionary) -> Dictionary:")
	p.append("            if args.has(\"state\"): _state = int(args[\"state\"])")
	p.append("            return {\"state\": _state}")
	p.append("        )")
	p.append("```")
	p.append("")

	# Sound editor
	if _sound_toggle.button_pressed:
		p.append("## Sound Editor Integration")
		p.append("The project includes a self-contained retro synth + step sequencer at res://game/sound_editor/SoundEditor.tscn.")
		p.append("Add a \"SOUND EDITOR\" button to the game's main menu or title screen.")
		p.append("Wire it to: get_tree().change_scene_to_file(\"res://game/sound_editor/SoundEditor.tscn\")")
		p.append("The sound editor handles its own back-navigation to res://main.tscn.")
		p.append("")

	# Extra instructions
	var extra := _extra_edit.text.strip_edges()
	if not extra.is_empty():
		p.append("## Additional Instructions")
		p.append(extra)
		p.append("")

	# Verification loop
	p.append("## Verification Loop")
	p.append("Using the installed MCP server godot-runtime-bridge:")
	p.append("1. Write the next increment of code (max 150 lines)")
	p.append("2. Launch with the exact grb_launch call above")
	p.append("3. grb_call_method(node=\"/root/Main\", method=\"get_child_count\") — if 0, see Build Strategy for diagnosis")
	p.append("4. grb_get_errors() — fix any runtime errors")
	p.append("5. grb_screenshot() — capture and analyze the current state")
	p.append("6. Iterate until the game matches the design intent")
	p.append("Never report \"FINISHED\" without visual confirmation via screenshot.")
	p.append("")
	p.append("### Testing Tips")
	p.append("- For interactive testing (jumping, timing-dependent gameplay), use grb_set_property(node=\"/root/Main\", ...) to teleport entities and grb_call_method(node=\"/root/Main\", ...) to trigger state changes directly rather than simulating real-time input sequences.")
	p.append("- Register a get_state command (see Reference Snippets) and query with: grb_run_custom_command(name=\"get_state\")")
	p.append("- Transient states (WIN/LOSE) auto-return to MENU after 3-4 seconds. To verify them: use grb_run_custom_command(name=\"set_state\", args={\"state\": 2}) to jump directly, then IMMEDIATELY screenshot — don't wait.")
	p.append("- GRB click events inject at window viewport coordinates, NOT the 320×200 SubViewport. For mouse-dependent features, test with grb_call_method instead of grb_click.")

	return "\n".join(p)
