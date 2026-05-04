@tool
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
				print("  Loaded ThemeDefinition, control_overrides type:", typeof(def.control_overrides))
				print("  control_overrides size:", def.control_overrides.size())
				if def.control_overrides.size() > 0:
					print("  Keys:", def.control_overrides.keys())
				else:
					print("  WARNING: control_overrides is EMPTY")

				var theme = _compile_theme(def)
				if theme != null:
					var err = ResourceSaver.save(theme, output_path, ResourceSaver.FLAG_BUNDLE_RESOURCES)
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

	# First, create all defined styles
	var created_styles: Dictionary = {}

	for style_name in def.styles:
		var style_config = def.styles[style_name]
		var style_type = style_config.get("type", "")

		match style_type:
			"StyleBoxFlat":
				var style = _create_stylebox_flat(def, style_config)
				if style:
					style.resource_name = style_name
					created_styles[style_name] = style
				else:
					push_error("Failed to create StyleBoxFlat for: %s" % style_name)

			"StyleBoxEmpty":
				var style = _create_stylebox_empty(def, style_config)
				if style:
					style.resource_name = style_name
					created_styles[style_name] = style
				else:
					push_error("Failed to create StyleBoxEmpty for: %s" % style_name)

			_:
				push_error("Unknown style type: %s for style: %s" % [style_type, style_name])

	# Load external resources (fonts)
	var ext_resources: Array = []
	for ext_res in def.external_resources:
		var res = load(ext_res["path"])
		if res:
			ext_resources.append(res)
		else:
			push_error("Failed to load external resource: %s" % ext_res["path"])

	# Create font resources from definitions
	var created_fonts: Dictionary = {}
	for font_name in def.fonts:
		var font_def = def.fonts[font_name]
		var font_type = font_def.get("type", "")

		if font_type == "FontFile":
			var font_idx = font_def.get("index", 0)
			if font_idx >= 0 and font_idx < ext_resources.size():
				var font_file = ext_resources[font_idx]
				if font_file is FontFile:
					# Create a Font resource from the FontFile
					var font = FontFile.new()
					# Actually, we can just use the FontFile directly
					created_fonts[font_name] = font_file
				else:
					push_error("Resource at index %d is not a FontFile" % font_idx)
			else:
				push_error("Invalid font index for %s: %d" % [font_name, font_idx])

		elif font_type == "FontVariation":
			var base_font_idx = font_def.get("base_font", 0)
			var variation = font_def.get("variation_opentype", {})
			if base_font_idx >= 0 and base_font_idx < ext_resources.size():
				var base_font_file = ext_resources[base_font_idx]
				if base_font_file is FontFile:
					# Use the base FontFile directly and set variation
					# FontFile inherits from Font, which has variation_opentype
					var font = base_font_file
					if variation.size() > 0:
						for axis_tag in variation:
							font.variation_opentype[axis_tag] = variation[axis_tag]
					created_fonts[font_name] = font
				else:
					push_error("Base resource at index %d is not a FontFile" % base_font_idx)
			else:
				push_error("Invalid base_font index for %s: %d" % [font_name, base_font_idx])
		else:
			push_error("Unknown font type: %s for font: %s" % [font_type, font_name])

	# Apply control-specific theme overrides
	for control_type in def.control_overrides:
		var overrides = def.control_overrides[control_type]
		_apply_control_overrides(theme, control_type, overrides, def, ext_resources, created_styles, created_fonts)

	return theme


## Apply all overrides for a specific control type
func _apply_control_overrides(theme: Theme, control_type: String, overrides: Dictionary, def: ThemeDefinition, ext_resources: Array, created_styles: Dictionary, created_fonts: Dictionary) -> void:
	# Apply colors
	if overrides.has("colors"):
		for color_name in overrides["colors"]:
			var color_value = overrides["colors"][color_name]
			# Resolve color reference if it's a string
			if color_value is String:
				color_value = _resolve_color(def, color_value)
			elif color_value is Color:
				pass  # Already a Color
			else:
				push_error("Invalid color value for %s/%s" % [control_type, color_name])
				continue
			theme.set_color(color_name, control_type, color_value)

	# Apply font sizes
	if overrides.has("font_sizes"):
		for size_name in overrides["font_sizes"]:
			var size_value = overrides["font_sizes"][size_name]
			theme.set_font_size(size_name, control_type, size_value)

	# Apply fonts
	if overrides.has("fonts"):
		for font_name in overrides["fonts"]:
			var font_ref = overrides["fonts"][font_name]

			# Can be an integer index into created_fonts or external_resources
			if font_ref is int:
				# Try created_fonts first
				if created_fonts.size() > font_ref and created_fonts.has(str(font_ref)):
					var font = created_fonts[str(font_ref)]
					if font is Font:
						theme.set_font(font_name, control_type, font)
					else:
						push_error("Font reference %d is not a Font" % font_ref)
				elif font_ref >= 0 and font_ref < ext_resources.size():
					var font_resource = ext_resources[font_ref]
					if font_resource is FontFile or font_resource is Font:
						theme.set_font(font_name, control_type, font_resource)
					else:
						push_error("Font resource %d is not a Font or FontFile" % font_ref)
				else:
					push_error("Invalid font index for %s/%s: %s" % [control_type, font_name, font_ref])
			# Can be a string name referencing created_fonts
			elif font_ref is String and created_fonts.has(font_ref):
				var font = created_fonts[font_ref]
				if font is Font:
					theme.set_font(font_name, control_type, font)
				else:
					push_error("Font reference '%s' is not a Font" % font_ref)
			else:
				push_error("Invalid font reference for %s/%s: %s" % [control_type, font_name, font_ref])

	# Apply constants
	if overrides.has("constants"):
		for const_name in overrides["constants"]:
			var const_value = overrides["constants"][const_name]
			theme.set_constant(const_name, control_type, const_value)

	# Apply styles (StyleBox references)
	if overrides.has("styles"):
		for style_name in overrides["styles"]:
			var style_ref = overrides["styles"][style_name]
			# Look up the style from our created_styles dictionary
			if created_styles.has(style_ref):
				var style = created_styles[style_ref]
				theme.set_stylebox(style_name, control_type, style)
			else:
				push_error("Style reference not found: %s for %s/%s" % [style_ref, control_type, style_name])


## Resolve a color reference (string name or Color) to an actual Color
func _resolve_color(def: ThemeDefinition, ref: Variant) -> Color:
	if ref is Color:
		return ref
	elif ref is String and def.colors.has(ref):
		return def.colors[ref]
	else:
		push_warning("Unknown color reference: %s" % ref)
		return Color(1, 0, 1, 1)  # Magenta as error color


## Create a StyleBoxFlat from a style configuration
func _create_stylebox_flat(def: ThemeDefinition, config: Dictionary) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()

	# Background color
	if config.has("bg_color"):
		style.bg_color = _resolve_color(def, config["bg_color"])

	# Border colors
	if config.has("border_color"):
		var border_color = _resolve_color(def, config["border_color"])
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
func _create_stylebox_empty(def: ThemeDefinition, config: Dictionary) -> StyleBoxEmpty:
	var style = StyleBoxEmpty.new()

	# StyleBoxEmpty has fewer properties
	if config.has("bg_color"):
		# StyleBoxEmpty doesn't have bg_color, it's transparent
		pass

	# It does have border properties though
	if config.has("border_color"):
		style.border_color = _resolve_color(def, config["border_color"])
	if config.has("border_width_left"):
		style.border_width_left = config["border_width_left"]
	if config.has("border_width_top"):
		style.border_width_top = config["border_width_top"]
	if config.has("border_width_right"):
		style.border_width_right = config["border_width_right"]
	if config.has("border_width_bottom"):
		style.border_width_bottom = config["border_width_bottom"]

	return style
