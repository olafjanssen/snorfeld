class_name ThemeColors
extends RefCounted
## ThemeColors - Semantic color constants for the application

# gdlint:ignore-file:magic-number
##
## This utility class defines semantic color names that are used throughout the UI.
## Each color has a descriptive name and a default value for the light theme.
## Dark theme variants should be defined separately.
##
## Usage:
##   var panel_style = StyleBoxFlat.new()
##   panel_style.bg_color = ThemeColors.bg_primary
##   panel_style.border_color = ThemeColors.border_primary

## ============================================================================
## Background Colors
## ============================================================================

## Main panel backgrounds (most common)
static var bg_primary: Color = Color(0.8627451, 0.8627451, 0.8666667, 1)

## Elevated surfaces (tabs, secondary panels)
static var bg_secondary: Color = Color(0.92156863, 0.92156863, 0.9254902, 1)

## Input/editor backgrounds (CodeEdit, TextEdit)
static var bg_lighter: Color = Color(0.9529412, 0.9529412, 0.9529412, 1)

## Highest elevation (TextEdit background)
static var bg_lightest: Color = Color(0.98039216, 0.98039216, 0.98039216, 1)

## Selected/active states (Tree selected)
static var bg_dark: Color = Color(0.7921569, 0.7921569, 0.7921569, 1)

## Hover states (Tree hovered)
static var bg_medium: Color = Color(0.8745098, 0.8745098, 0.8784314, 1)

## ============================================================================
## Border Colors
## ============================================================================

## Standard borders for panels, buttons, inputs
static var border_primary: Color = Color(0.7882353, 0.7882353, 0.7921569, 1)

## Accent/selection borders (Tree selected state)
static var border_accent: Color = Color(0.019607844, 0.53333336, 0.9411765, 1)

## ============================================================================
## Text Colors
## ============================================================================

## Main text (CodeEdit, RichTextLabel)
static var text_primary: Color = Color(0.11764706, 0.11764706, 0.11764706, 1)

## Buttons, inputs
static var text_secondary: Color = Color(0.14117648, 0.14509805, 0.16078432, 1)

## Labels, tabs, tree text
static var text_tertiary: Color = Color(0.19215687, 0.19215687, 0.19215687, 1)

## Disabled text, hints
static var text_dimmed: Color = Color(0.34509805, 0.34509805, 0.3529412, 1)

## Placeholder text
static var text_placeholder: Color = Color(0.49411765, 0.5019608, 0.5254902, 1)

## Links, selection accents
static var text_accent: Color = Color(0, 0.47058824, 0.83137256, 1)

## ============================================================================
## Utility Methods
## ============================================================================

## Get all color names as an array (for iteration/inspection)
static func get_all_color_names() -> Array:
	return [
		"bg_primary", "bg_secondary", "bg_lighter", "bg_lightest", "bg_dark", "bg_medium",
		"border_primary", "border_accent",
		"text_primary", "text_secondary", "text_tertiary", "text_dimmed", "text_placeholder", "text_accent"
	]

## Get a color by name (useful for dynamic lookups)
static func get_color(name: String) -> Color:
	match name:
		"bg_primary": return bg_primary
		"bg_secondary": return bg_secondary
		"bg_lighter": return bg_lighter
		"bg_lightest": return bg_lightest
		"bg_dark": return bg_dark
		"bg_medium": return bg_medium
		"border_primary": return border_primary
		"border_accent": return border_accent
		"text_primary": return text_primary
		"text_secondary": return text_secondary
		"text_tertiary": return text_tertiary
		"text_dimmed": return text_dimmed
		"text_placeholder": return text_placeholder
		"text_accent": return text_accent
		_: return Color(1, 0, 1, 1)  # Magenta as error color
