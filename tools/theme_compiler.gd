@tool
class_name ThemeCompiler
extends EditorScript
# gdlint:ignore-file:file-length,too-many-params,long-function,deep-nesting,long-line,missing-type-hint
## ThemeCompiler - Editor tool to compile ThemeDefinition resources into Theme resources
##
## This tool reads a ThemeDefinition resource and generates a standard Godot Theme
## resource that can be used at runtime. The generated Theme uses the semantic colors
## defined in the ThemeDefinition.
##
## Usage:
##   1. Create a ThemeDefinition resource (e.g., themes/light.theme_definition.tres)
##   2. Run this tool from Script -> Run Tool Script
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
	var ext_resources: Array = _load_external_resources(def)
	var created_styles: Dictionary = _create_all_styles(def)
	var created_fonts: Dictionary = _create_all_fonts(def, ext_resources)
	_apply_all_control_overrides(theme, def, ext_resources, created_styles, created_fonts)
	return theme


## Load all external resources
func _load_external_resources(def: ThemeDefinition) -> Array:
	var ext_resources: Array = []
	for ext_res in def.external_resources:
		var res: Resource = load(ext_res["path"])
		if res:
			ext_resources.append(res)
		else:
			push_error("Failed to load external resource: %s" % ext_res["path"])
	return ext_resources


## Create all defined styles
func _create_all_styles(def: ThemeDefinition) -> Dictionary:
	var created_styles: Dictionary = {}
	for style_name in def.styles:
		var style: Variant = _create_style(def, style_name, def.styles[style_name])
		if style:
			style.resource_name = style_name
			created_styles[style_name] = style
	return created_styles


## Create a single style based on type
func _create_style(def: ThemeDefinition, style_name: String, style_config: Dictionary) -> Variant:
	var style_type: String = style_config.get("type", "")
	match style_type:
		"StyleBoxFlat":
			return _create_stylebox_flat(def, style_config)
		"StyleBoxEmpty":
			return _create_stylebox_empty(def, style_config)
		_:
			push_error("Unknown style type: %s for style: %s" % [style_type, style_name])
			return null


## Create all font resources from definitions
func _create_all_fonts(def: ThemeDefinition, ext_resources: Array) -> Dictionary:
	var created_fonts: Dictionary = {}
	for font_name in def.fonts:
		var font_def: Dictionary = def.fonts[font_name]
		var font: Font = _create_single_font(def, font_name, font_def, ext_resources)
		if font:
			created_fonts[font_name] = font
	return created_fonts


## Create a single font based on definition
func _create_single_font(def: ThemeDefinition, font_name: String, font_def: Dictionary, ext_resources: Array) -> Font:
	var font_type: String = font_def.get("type", "")
	if font_type == "FontFile":
		return _create_font_from_file(font_name, font_def, ext_resources)
	elif font_type == "FontVariation":
		return _create_font_from_variation(def, font_name, font_def, ext_resources)
	else:
		push_error("Unknown font type: %s for font: %s" % [font_type, font_name])
		return null


## Create font from FontFile reference
func _create_font_from_file(font_name: String, font_def: Dictionary, ext_resources: Array) -> Font:
	var font_idx: int = font_def.get("index", 0)
	if font_idx < 0 or font_idx >= ext_resources.size():
		push_error("Invalid font index for %s: %d" % [font_name, font_idx])
		return null
	var font_file: FontFile = ext_resources[font_idx]
	if font_file is FontFile:
		return font_file
	push_error("Resource at index %d is not a FontFile" % font_idx)
	return null


## Create font from FontVariation
func _create_font_from_variation(def: ThemeDefinition, font_name: String, font_def: Dictionary, ext_resources: Array) -> Font:
	var base_font_idx: int = font_def.get("base_font", 0)
	if base_font_idx < 0 or base_font_idx >= ext_resources.size():
		push_error("Invalid base_font index for %s: %d" % [font_name, base_font_idx])
		return null
	var base_font_file: FontFile = ext_resources[base_font_idx]
	if not base_font_file is FontFile:
		push_error("Base resource at index %d is not a FontFile" % base_font_idx)
		return null
	var font_path: String = def.external_resources[base_font_idx]["path"]
	var base_font: FontFile = load(font_path)
	if not base_font:
		push_error("Failed to load base font: %s" % font_path)
		return null
	var font: FontFile = FontFile.new()
	var variation: Dictionary = font_def.get("variation_opentype", {})
	font.set_opentype_feature_overrides(variation)
	return font


## Apply all control overrides
func _apply_all_control_overrides(theme: Theme, def: ThemeDefinition, ext_resources: Array, created_styles: Dictionary, created_fonts: Dictionary) -> void:
	for control_type in def.control_overrides:
		var overrides: Dictionary = def.control_overrides[control_type]
		_apply_control_overrides(theme, control_type, overrides, def, ext_resources, created_styles, created_fonts)


## Context object for control override application
class OverrideContext:
	var theme: Theme
	var control_type: String
	var def: ThemeDefinition
	var ext_resources: Array
	var created_styles: Dictionary
	var created_fonts: Dictionary


## Apply all overrides for a specific control type
func _apply_control_overrides(theme: Theme, control_type: String, overrides: Dictionary, def: ThemeDefinition, ext_resources: Array, created_styles: Dictionary, created_fonts: Dictionary) -> void:
	var ctx: OverrideContext = OverrideContext.new()
	ctx.theme = theme
	ctx.control_type = control_type
	ctx.def = def
	ctx.ext_resources = ext_resources
	ctx.created_styles = created_styles
	ctx.created_fonts = created_fonts

	_process_override(ctx, overrides, "base_type", _apply_base_type_internal)
	_process_override(ctx, overrides, "colors", _apply_colors_internal)
	_process_override(ctx, overrides, "font_sizes", _apply_font_sizes_internal)
	_process_override(ctx, overrides, "fonts", _apply_fonts_internal)
	_process_override(ctx, overrides, "constants", _apply_constants_internal)
	_process_override(ctx, overrides, "styles", _apply_styles_internal)


## Helper to apply an override if present
func _process_override(ctx: OverrideContext, overrides: Dictionary, key: String, handler: Callable) -> void:
	if overrides.has(key):
		handler.call(ctx, overrides[key])


## Internal handlers using OverrideContext
func _apply_base_type_internal(ctx: OverrideContext, value: Variant) -> void:
	_apply_base_type(ctx.theme, ctx.control_type, value)


func _apply_colors_internal(ctx: OverrideContext, colors: Dictionary) -> void:
	_apply_colors(ctx.theme, ctx.control_type, colors, ctx.def)


func _apply_font_sizes_internal(ctx: OverrideContext, font_sizes: Dictionary) -> void:
	_apply_font_sizes(ctx.theme, ctx.control_type, font_sizes)


func _apply_fonts_internal(ctx: OverrideContext, fonts: Dictionary) -> void:
	_apply_fonts(ctx.theme, ctx.control_type, fonts, ctx.created_fonts, ctx.ext_resources)


func _apply_constants_internal(ctx: OverrideContext, constants: Dictionary) -> void:
	_apply_constants(ctx.theme, ctx.control_type, constants)


func _apply_styles_internal(ctx: OverrideContext, styles: Dictionary) -> void:
	_apply_styles(ctx.theme, ctx.control_type, styles, ctx.created_styles)


## Helper functions for _apply_control_overrides

func _apply_base_type(theme: Theme, control_type: String, base_type: Variant) -> void:
	if base_type is String:
		theme.set_type_variation(control_type, base_type)


func _apply_colors(theme: Theme, control_type: String, colors: Dictionary, def: ThemeDefinition) -> void:
	for color_name in colors:
		var color_value: Variant = colors[color_name]
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


## Resolve a font reference to an actual Font
func _resolve_font_reference(font_ref: Variant, created_fonts: Dictionary, ext_resources: Array, control_type: String, font_name: String) -> Font:
	if font_ref is int:
		return _resolve_font_by_index(font_ref, created_fonts, ext_resources, control_type, font_name)
	elif font_ref is String and created_fonts.has(font_ref):
		var font: Font = created_fonts[font_ref]
		if font is Font:
			return font
		push_error("Font reference '%s' is not a Font" % font_ref)
		return null
	push_error("Invalid font reference for %s/%s: %s" % [control_type, font_name, font_ref])
	return null


func _resolve_font_by_index(font_ref: int, created_fonts: Dictionary, ext_resources: Array, control_type: String, font_name: String) -> Font:
	if created_fonts.size() > font_ref and created_fonts.has(str(font_ref)):
		var font: Font = created_fonts[str(font_ref)]
		if font is Font:
			return font
		push_error("Font reference %d is not a Font" % font_ref)
		return null
	if font_ref >= 0 and font_ref < ext_resources.size():
		var font_resource: Resource = ext_resources[font_ref]
		if font_resource is FontFile or font_resource is Font:
			return font_resource
		push_error("Font resource %d is not a Font or FontFile" % font_ref)
		return null
	push_error("Invalid font index for %s/%s: %s" % [control_type, font_name, font_ref])
	return null


func _apply_constants(theme: Theme, control_type: String, constants: Dictionary) -> void:
	for const_name in constants:
		var const_value: Variant = constants[const_name]
		theme.set_constant(const_name, control_type, const_value)


func _apply_styles(theme: Theme, control_type: String, styles: Dictionary, created_styles: Dictionary) -> void:
	for style_name in styles:
		var style_ref: String = styles[style_name]
		if created_styles.has(style_ref):
			var style: StyleBox = created_styles[style_ref]
			theme.set_stylebox(style_name, control_type, style)
		else:
			push_error("Style reference not found: %s for %s/%s" % [style_ref, control_type, style_name])


## Resolve a color reference to an actual Color
func _resolve_color(def: ThemeDefinition, ref: Variant) -> Color:
	if ref is Color:
		return ref
	if ref is String and def.colors.has(ref):
		return def.colors[ref]
	push_warning("Unknown color reference: %s" % ref)
	return Color(1, 0, 1, 1)  # Magenta as error color


## Create a StyleBoxFlat from a style configuration
func _create_stylebox_flat(def: ThemeDefinition, config: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	if config.has("bg_color"):
		style.bg_color = _resolve_color(def, config["bg_color"])

	_apply_border_widths(style, config)
	_apply_corner_radii(style, config)
	_apply_expand_margins(style, config)

	if config.has("border_color"):
		style.border_color = _resolve_color(def, config["border_color"])

	return style


func _apply_border_widths(style: StyleBoxFlat, config: Dictionary) -> void:
	if config.has("border_width_all"):
		var width: int = config["border_width_all"]
		style.border_width_left = width
		style.border_width_top = width
		style.border_width_right = width
		style.border_width_bottom = width
	return

	if config.has("border_width_left"):
		style.border_width_left = config["border_width_left"]
	if config.has("border_width_top"):
		style.border_width_top = config["border_width_top"]
	if config.has("border_width_right"):
		style.border_width_right = config["border_width_right"]
	if config.has("border_width_bottom"):
		style.border_width_bottom = config["border_width_bottom"]


func _apply_corner_radii(style: StyleBoxFlat, config: Dictionary) -> void:
	if config.has("corner_radius_all"):
		var radius: int = config["corner_radius_all"]
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_right = radius
		style.corner_radius_bottom_left = radius
		return

	if config.has("corner_radius_top_left"):
		style.corner_radius_top_left = config["corner_radius_top_left"]
	if config.has("corner_radius_top_right"):
		style.corner_radius_top_right = config["corner_radius_top_right"]
	if config.has("corner_radius_bottom_right"):
		style.corner_radius_bottom_right = config["corner_radius_bottom_right"]
	if config.has("corner_radius_bottom_left"):
		style.corner_radius_bottom_left = config["corner_radius_bottom_left"]


func _apply_expand_margins(style: StyleBoxFlat, config: Dictionary) -> void:
	if config.has("expand_margin_left"):
		style.expand_margin_left = config["expand_margin_left"]
	if config.has("expand_margin_top"):
		style.expand_margin_top = config["expand_margin_top"]
	if config.has("expand_margin_right"):
		style.expand_margin_right = config["expand_margin_right"]
	if config.has("expand_margin_bottom"):
		style.expand_margin_bottom = config["expand_margin_bottom"]


## Create a StyleBoxEmpty from a style configuration
func _create_stylebox_empty(def: ThemeDefinition, config: Dictionary) -> StyleBoxEmpty:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()

	# StyleBoxEmpty doesn't have bg_color
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
