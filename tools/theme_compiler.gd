@tool
class_name ThemeCompiler
extends EditorScript
## ThemeCompiler - Editor tool to compile ThemeDefinition resources into Theme resources

# gdlint:ignore-file:file-length,too-many-params,long-function,deep-nesting,high-complexity,long-line,missing-type-hint
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
	_compile_all_themes()


## Compile all ThemeDefinition resources found in DEFINITIONS_PATH
func _compile_all_themes() -> bool:
	var success: bool = true
	var dir: DirAccess = DirAccess.open(DEFINITIONS_PATH)

	if dir == null:
		push_error("Could not open themes directory: %s" % DEFINITIONS_PATH)
		return false

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(DEFINITION_EXT):
			var def_path: String = DEFINITIONS_PATH + file_name
			var output_name: String = file_name.replace(DEFINITION_EXT, THEME_EXT)
			var output_path: String = OUTPUT_PATH + output_name

			var def: ThemeDefinition = load(def_path)
			if def == null:
				push_error("Could not load ThemeDefinition: %s" % def_path)
				success = false
			else:
				if def.control_overrides.size() == 0:
					push_warning("control_overrides is EMPTY for %s" % file_name)

				var theme: Theme = _compile_theme(def)
				if theme != null:
					DirAccess.remove_absolute(output_path)
					var err: int = ResourceSaver.save(theme, output_path, ResourceSaver.FLAG_BUNDLE_RESOURCES)
					if err != OK:
						push_error("Failed to save compiled theme: %s" % output_path)
						success = false
				else:
					push_error("Failed to compile theme from: %s" % def_path)
					success = false

		file_name = dir.get_next()

	dir.list_dir_end()
	return success


## Compile a single ThemeDefinition into a Theme resource
func _compile_theme(def: ThemeDefinition) -> Theme:
	var theme: Theme = Theme.new()

	# First, create all defined styles
	var created_styles: Dictionary = {}

	for style_name in def.styles:
		var style_config: Dictionary = def.styles[style_name]
		var style_type: String = style_config.get("type", "")

		match style_type:
			"StyleBoxFlat":
				var style: StyleBoxFlat = _create_stylebox_flat(def, style_config)
				if style:
					style.resource_name = style_name
					created_styles[style_name] = style
				else:
					push_error("Failed to create StyleBoxFlat for: %s" % style_name)

			"StyleBoxEmpty":
				var style: StyleBoxEmpty = _create_stylebox_empty(def, style_config)
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
		var res: Resource = load(ext_res["path"])
		if res:
			ext_resources.append(res)
		else:
			push_error("Failed to load external resource: %s" % ext_res["path"])

	# Create font resources from definitions
	var created_fonts: Dictionary = {}
	for font_name in def.fonts:
		var font_def: Dictionary = def.fonts[font_name]
		var font_type: String = font_def.get("type", "")

		if font_type == "FontFile":
			var font_idx: int = font_def.get("index", 0)
			if font_idx >= 0 and font_idx < ext_resources.size():
				var font_file: FontFile = ext_resources[font_idx]
				if font_file is FontFile:
					# Create a Font resource from the FontFile
					created_fonts[font_name] = font_file
				else:
					push_error("Resource at index %d is not a FontFile" % font_idx)
			else:
				push_error("Invalid font index for %s: %d" % [font_name, font_idx])

		elif font_type == "FontVariation":
			var base_font_idx: int = font_def.get("base_font", 0)
			var variation: Dictionary = font_def.get("variation_opentype", {})
			if base_font_idx >= 0 and base_font_idx < ext_resources.size():
				var base_font_file: FontFile = ext_resources[base_font_idx]
				if base_font_file is FontFile:
					# Use DynamicFont for variable font support
					var font_path: String = def.external_resources[base_font_idx]["path"]
					var base_font: FontFile = load(font_path)
					if base_font:
						var font: FontFile = FontFile.new()
						font.set_opentype_feature_overrides(variation)
						created_fonts[font_name] = font
				else:
					push_error("Base resource at index %d is not a FontFile" % base_font_idx)
			else:
				push_error("Invalid base_font index for %s: %d" % [font_name, base_font_idx])
		else:
			push_error("Unknown font type: %s for font: %s" % [font_type, font_name])

	# Apply control-specific theme overrides
	for control_type in def.control_overrides:
		var overrides: Dictionary = def.control_overrides[control_type]
		_apply_control_overrides(theme, control_type, overrides, def, ext_resources, created_styles, created_fonts)

	return theme


## Apply all overrides for a specific control type
func _apply_control_overrides(theme: Theme, control_type: String, overrides: Dictionary, def: ThemeDefinition, ext_resources: Array, created_styles: Dictionary, created_fonts: Dictionary) -> void:
	# Apply base type for custom control types
	if overrides.has("base_type"):
		_apply_base_type(theme, control_type, overrides["base_type"])

	# Apply colors
	if overrides.has("colors"):
		_apply_colors(theme, control_type, overrides["colors"], def)

	# Apply font sizes
	if overrides.has("font_sizes"):
		_apply_font_sizes(theme, control_type, overrides["font_sizes"])

	# Apply fonts
	if overrides.has("fonts"):
		_apply_fonts(theme, control_type, overrides["fonts"], created_fonts, ext_resources)

	# Apply constants
	if overrides.has("constants"):
		_apply_constants(theme, control_type, overrides["constants"])

	# Apply styles (StyleBox references)
	if overrides.has("styles"):
		_apply_styles(theme, control_type, overrides["styles"], created_styles)


## Helper functions for _apply_control_overrides

func _apply_base_type(theme: Theme, control_type: String, base_type: Variant) -> void:
	if base_type is String:
		theme.set_type_variation(control_type, base_type)


func _apply_colors(theme: Theme, control_type: String, colors: Dictionary, def: ThemeDefinition) -> void:
	for color_name in colors:
		var color_value: Variant = colors[color_name]
		# Resolve color reference if it's a string
		if color_value is String:
			color_value = _resolve_color(def, color_value)
		elif color_value is Color:
			pass  # Already a Color
		else:
			push_error("Invalid color value for %s/%s" % [control_type, color_name])
			continue
		theme.set_color(color_name, control_type, color_value)


func _apply_font_sizes(theme: Theme, control_type: String, font_sizes: Dictionary) -> void:
	for size_name in font_sizes:
		var size_value: Variant = font_sizes[size_name]
		theme.set_font_size(size_name, control_type, size_value)


func _apply_fonts(theme: Theme, control_type: String, fonts: Dictionary, created_fonts: Dictionary, ext_resources: Array) -> void:
	for font_name in fonts:
		var font_ref: Variant = fonts[font_name]
		var font = _resolve_font_reference(font_ref, created_fonts, ext_resources, control_type, font_name)
		if font != null:
			theme.set_font(font_name, control_type, font)


func _resolve_font_reference(font_ref: Variant, created_fonts: Dictionary, ext_resources: Array, control_type: String, font_name: String):
	# Can be an integer index into created_fonts or external_resources
	if font_ref is int:
		# Try created_fonts first
		if created_fonts.size() > font_ref and created_fonts.has(str(font_ref)):
			var font: Font = created_fonts[str(font_ref)]
			if font is Font:
				return font
			else:
				push_error("Font reference %d is not a Font" % font_ref)
				return null
		elif font_ref >= 0 and font_ref < ext_resources.size():
			var font_resource: Resource = ext_resources[font_ref]
			if font_resource is FontFile or font_resource is Font:
				return font_resource
			else:
				push_error("Font resource %d is not a Font or FontFile" % font_ref)
				return null
		else:
			push_error("Invalid font index for %s/%s: %s" % [control_type, font_name, font_ref])
			return null
	# Can be a string name referencing created_fonts
	elif font_ref is String and created_fonts.has(font_ref):
		var font: Font = created_fonts[font_ref]
		if font is Font:
			return font
		else:
			push_error("Font reference '%s' is not a Font" % font_ref)
			return null
	else:
		push_error("Invalid font reference for %s/%s: %s" % [control_type, font_name, font_ref])
		return null


func _apply_constants(theme: Theme, control_type: String, constants: Dictionary) -> void:
	for const_name in constants:
		var const_value: Variant = constants[const_name]
		theme.set_constant(const_name, control_type, const_value)


func _apply_styles(theme: Theme, control_type: String, styles: Dictionary, created_styles: Dictionary) -> void:
	for style_name in styles:
		var style_ref: String = styles[style_name]
		# Look up the style from our created_styles dictionary
		if created_styles.has(style_ref):
			var style: StyleBox = created_styles[style_ref]
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
	var style: StyleBoxFlat = StyleBoxFlat.new()

	# Background color
	if config.has("bg_color"):
		style.bg_color = _resolve_color(def, config["bg_color"])

	# Border colors
	if config.has("border_color"):
		var border_color: Color = _resolve_color(def, config["border_color"])
		style.border_color = border_color

	# Border widths - can be individual or "all"
	if config.has("border_width_all"):
		var width: int = config["border_width_all"]
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
		var radius: int = config["corner_radius_all"]
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
	var style: StyleBoxEmpty = StyleBoxEmpty.new()

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
