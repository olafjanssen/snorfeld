class_name ThemeDefinition
extends Resource
## ThemeDefinition - Custom resource for defining themes with semantic color references

# gdlint:ignore-file:magic-number
##
## This resource allows defining themes using semantic color names that can be
## referenced by style definitions. A compiler tool converts this to a standard
## Godot Theme resource.
##
## Usage:
##   1. Create a ThemeDefinition resource (.tres file)
##   2. Define your colors and styles
##   3. Run the theme_compiler.gd tool to generate the actual Theme.tres

## Semantic color palette: name -> Color
@export var colors: Dictionary = {
	"bg_primary": Color(0.8627451, 0.8627451, 0.8666667, 1),
	"bg_secondary": Color(0.92156863, 0.92156863, 0.9254902, 1),
	"bg_lighter": Color(0.9529412, 0.9529412, 0.9529412, 1),
	"bg_lightest": Color(0.98039216, 0.98039216, 0.98039216, 1),
	"bg_dark": Color(0.7921569, 0.7921569, 0.7921569, 1),
	"bg_medium": Color(0.8745098, 0.8745098, 0.8784314, 1),
	"border_primary": Color(0.7882353, 0.7882353, 0.7921569, 1),
	"border_accent": Color(0.019607844, 0.53333336, 0.9411765, 1),
	"text_primary": Color(0.11764706, 0.11764706, 0.11764706, 1),
	"text_secondary": Color(0.14117648, 0.14509805, 0.16078432, 1),
	"text_tertiary": Color(0.19215687, 0.19215687, 0.19215687, 1),
	"text_dimmed": Color(0.34509805, 0.34509805, 0.3529412, 1),
	"text_placeholder": Color(0.49411765, 0.5019608, 0.5254902, 1),
	"text_accent": Color(0, 0.47058824, 0.83137256, 1)
}

## Style definitions: style_name -> {type: String, config: Dictionary}
## Config can reference color names from the colors dictionary
@export var styles: Dictionary = {
	"panel": {
		"type": "StyleBoxFlat",
		"bg_color": "bg_primary",
		"border_color": "border_primary",
		"border_width_all": 1,
		"corner_radius_all": 4
	},
	"panel_inset": {
		"type": "StyleBoxFlat",
		"bg_color": "bg_secondary",
		"border_color": "border_primary",
		"border_width_all": 1,
		"corner_radius_all": 4
	},
	"panel_light": {
		"type": "StyleBoxFlat",
		"bg_color": "bg_lighter",
		"border_color": "border_primary",
		"border_width_bottom": 1
	}
}

## External resources (fonts, textures) to include in the theme
## Each entry: {"type": String, "path": String}
@export var external_resources: Array = []

## Font definitions: font_name -> {"type": String, "base_font": int, "variation_opentype": Dictionary}
## For FontFile: {"type": "FontFile", "index": int}
## For FontVariation: {"type": "FontVariation", "base_font": int, "variation_opentype": {axis_tag: value}}
@export var fonts: Dictionary = {}

## Control-specific theme overrides
## Structure: {
##   "ControlType": {
##     "colors": {...},
##     "font_sizes": {...},
##     "fonts": {...},
##     "constants": {...},
##     "styles": {...}
##   }
## }
@export var control_overrides: Dictionary = {}

## Resolve a color reference to an actual Color
## If the reference is a color name, look it up in colors
## If it's already a Color, return it directly
func resolve_color(ref: Variant) -> Color:
	if ref is Color:
		return ref
	elif ref is String and colors.has(ref):
		return colors[ref]
	else:
		push_warning("Unknown color reference: %s" % ref)
		return Color(1, 0, 1, 1)  # Magenta as error color
