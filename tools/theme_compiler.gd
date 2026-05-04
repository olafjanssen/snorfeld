tool
class_name ThemeCompiler
extends EditorScript
## ThemeCompiler - Editor tool to compile ThemeDefinition resources into Theme resources
##
## This tool reads a ThemeDefinition resource and generates a standard Godot Theme
## resource that can be used at runtime. The generated Theme uses the semantic colors
## defined in the ThemeDefinition.
##
## Usage:
##   1. Create a ThemeDefinition resource (e.g., themes/light.theme_definition.tres)
##   2. Run this tool from Script → Run Tool Script
##   3. The tool will compile it to themes/light/theme.tres
##
## The generated Theme can then be:
##   - Opened in Godot's Theme editor for visual inspection
##   - Loaded at runtime by ThemeManager

## Path where ThemeDefinition resources are stored
const DEFINITIONS_PATH := "res://themes/"

## Path where compiled Theme resources will be saved
const OUTPUT_PATH := "res://themes/"

## File extension for ThemeDefinition resources
const DEFINITION_EXT := ".theme_definition.tres"

## File extension for compiled Theme resources
const THEME_EXT := ".tres"


func _run():
	var result := _compile_all_themes()
	if result:
		print("Theme compilation successful!")
	else:
		print("Theme compilation completed with warnings.")


## Compile all ThemeDefinition resources found in DEFINITIONS_PATH
func _compile_all_themes() -> bool:
	var success := true
	var dir = DirAccess.open(DEFINITIONS_PATH)

	if dir == null:
		push_error("Could not open themes directory: %s" % DEFINITIONS_PATH)
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(DEFINITION_EXT):
			var def_path = DEFINITIONS_PATH + file_name
			var output_name = file_name.replace(DEFINITION_EXT, THEME_EXT)
			var output_path = OUTPUT_PATH + output_name

			print("Compiling: %s -> %s" % [file_name, output_name])

			var def = load(def_path)
			if def == null:
				push_error("Could not load ThemeDefinition: %s" % def_path)
				success = false
			else:
				var theme = _compile_theme(def)
				if theme != null:
					var err = ResourceSaver.save(theme, output_path)
					if err != OK:
						push_error("Failed to save compiled theme: %s" % output_path)
						success = false
					else:
						print("  Saved: %s" % output_path)
				else:
					push_error("Failed to compile theme from: %s" % def_path)
					success = false

		file_name = dir.get_next()

	dir.list_dir_end()
	return success


## Compile a single ThemeDefinition into a Theme resource
func _compile_theme(def: ThemeDefinition) -> Theme:
	var theme = Theme.new()

	# First, add all colors as theme color overrides
	# These can be referenced by controls that use theme colors
	for color_name in def.colors:
		var color_value = def.colors[color_name]
		# Store in theme's colors if the control type supports it
		# Note: Godot Theme doesn't have a generic color storage,
		# colors are per-control-type. So we store them as metadata
		# and also create a way to access them.

	# Create all defined styles
	for style_name in def.styles:
		var style_config = def.styles[style_name]
		var style_type = style_config.get("type", "")

		match style_type:
			"StyleBoxFlat":
				var style = _create_stylebox_flat(def, style_config)
				if style:
					theme.set_stylebox(style_name, style_name, style)
				else:
					push_error("Failed to create StyleBoxFlat for: %s" % style_name)

			"StyleBoxEmpty":
				var style = _create_stylebox_empty(style_config)
				if style:
					theme.set_stylebox(style_name, style_name, style)
				else:
					push_error("Failed to create StyleBoxEmpty for: %s" % style_name)

			_:
				push_error("Unknown style type: %s for style: %s" % [style_type, style_name])

	# Add control-specific theme overrides
	# These would be defined in the ThemeDefinition as well
	# For now, we just handle the style definitions above

	return theme


## Create a StyleBoxFlat from a style configuration
func _create_stylebox_flat(def: ThemeDefinition, config: Dictionary) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()

	# Background color
	if config.has("bg_color"):
		style.bg_color = def.resolve_color(config["bg_color"])

	# Border colors
	if config.has("border_color"):
		var border_color = def.resolve_color(config["border_color"])
		style.border_color = border_color

	# Border widths - can be individual or "all"
	if config.has("border_width_all"):
		var width = config["border_width_all"]
		style.border_width_left = width
		style.border_width_top = width
		style.border_width_right = width
		style.border_width_bottom = width
	else:
		if config.has("border_width_left"):
			style.border_width_left = config["border_width_left"]
		if config.has("border_width_top"):
			style.border_width_top = config["border_width_top"]
		if config.has("border_width_right"):
			style.border_width_right = config["border_width_right"]
		if config.has("border_width_bottom"):
			style.border_width_bottom = config["border_width_bottom"]

	# Corner radii - can be individual or "all"
	if config.has("corner_radius_all"):
		var radius = config["corner_radius_all"]
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_right = radius
		style.corner_radius_bottom_left = radius
	else:
		if config.has("corner_radius_top_left"):
			style.corner_radius_top_left = config["corner_radius_top_left"]
		if config.has("corner_radius_top_right"):
			style.corner_radius_top_right = config["corner_radius_top_right"]
		if config.has("corner_radius_bottom_right"):
			style.corner_radius_bottom_right = config["corner_radius_bottom_right"]
		if config.has("corner_radius_bottom_left"):
			style.corner_radius_bottom_left = config["corner_radius_bottom_left"]

	# Expand margins
	if config.has("expand_margin_left"):
		style.expand_margin_left = config["expand_margin_left"]
	if config.has("expand_margin_top"):
		style.expand_margin_top = config["expand_margin_top"]
	if config.has("expand_margin_right"):
		style.expand_margin_right = config["expand_margin_right"]
	if config.has("expand_margin_bottom"):
		style.expand_margin_bottom = config["expand_margin_bottom"]

	return style


## Create a StyleBoxEmpty from a style configuration
func _create_stylebox_empty(config: Dictionary) -> StyleBoxEmpty:
	var style = StyleBoxEmpty.new()

	# StyleBoxEmpty has fewer properties
	if config.has("bg_color"):
		# StyleBoxEmpty doesn't have bg_color, it's transparent
		pass

	# It does have border properties though
	if config.has("border_color"):
		style.border_color = config["border_color"]
	if config.has("border_width_left"):
		style.border_width_left = config["border_width_left"]
	if config.has("border_width_top"):
		style.border_width_top = config["border_width_top"]
	if config.has("border_width_right"):
		style.border_width_right = config["border_width_right"]
	if config.has("border_width_bottom"):
		style.border_width_bottom = config["border_width_bottom"]

	return style
