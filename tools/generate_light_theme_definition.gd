@tool
class_name LightThemeDefinitionGenerator
extends EditorScript

func _run():
	var def = ThemeDefinition.new()

	# Set semantic colors
	def.colors = {
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

	# Set styles
	def.styles = {
		"StyleBoxFlat_button_hover": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_all": 1,
			"corner_radius_all": 4
		},
		"StyleBoxFlat_button_normal": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_all": 1,
			"corner_radius_all": 4
		},
		"StyleBoxFlat_button_pressed": {
			"type": "StyleBoxFlat",
			"border_color": "border_primary",
			"border_width_all": 1,
			"corner_radius_all": 4
		},
		"StyleBoxEmpty_codeedit_focus": {
			"type": "StyleBoxEmpty"
		},
		"StyleBoxFlat_panel_codeedit": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lighter"
		},
		"StyleBoxFlat_tabcontainer_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_left": 1
		},
		"StyleBoxFlat_tab_hovered": {
			"type": "StyleBoxFlat",
			"border_color": "border_primary",
			"border_width_left": 1,
			"border_width_right": 1,
			"expand_margin_left": 4.0,
			"expand_margin_right": 4.0
		},
		"StyleBoxFlat_tab_selected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_left": 1,
			"border_width_right": 1,
			"expand_margin_left": 4.0,
			"expand_margin_right": 4.0,
			"expand_margin_bottom": 1.0
		},
		"StyleBoxFlat_tab_unselected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_left": 1,
			"border_width_right": 1,
			"expand_margin_left": 4.0,
			"expand_margin_right": 4.0
		},
		"StyleBoxFlat_tabbar_background": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_right": 1,
			"border_width_bottom": 1
		},
		"StyleBoxFlat_textedit_normal": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lightest"
		},
		"StyleBoxEmpty_tree_button_hover": {
			"type": "StyleBoxEmpty"
		},
		"StyleBoxEmpty_tree_button_pressed": {
			"type": "StyleBoxEmpty"
		},
		"StyleBoxFlat_tree_hovered": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_medium"
		},
		"StyleBoxFlat_tree_hovered_dimmed": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary"
		},
		"StyleBoxFlat_tree_hovered_selected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_dark",
			"border_color": "border_accent",
			"border_width_top": 1,
			"border_width_bottom": 1
		},
		"StyleBoxFlat_tree_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_right": 1
		},
		"StyleBoxFlat_tree_selected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_dark",
			"border_color": "border_accent",
			"border_width_top": 1,
			"border_width_bottom": 1
		}
	}

	# Set external resources
	def.external_resources = [
		{"type": "FontFile", "path": "res://fonts/Lora-VariableFont_wght.ttf"},
		{"type": "FontFile", "path": "res://fonts/Lora-Italic-VariableFont_wght.ttf"}
	]

	# Set control overrides
	def.control_overrides = {
		"Button": {
			"colors": {
				"font_color": "text_secondary",
				"font_hover_color": "text_secondary",
				"font_hover_pressed_color": "text_secondary",
				"font_pressed_color": "text_secondary"
			},
			"font_sizes": {
				"font_size": 12
			},
			"styles": {
				"hover": "StyleBoxFlat_button_hover",
				"normal": "StyleBoxFlat_button_normal",
				"pressed": "StyleBoxFlat_button_pressed"
			}
		},
		"CodeEdit": {
			"colors": {
				"background_color": "bg_lighter",
				"caret_color": "text_primary",
				"font_color": "text_primary",
				"selection_color": Color(0.6784314, 0.8392157, 1, 1)
			},
			"constants": {
				"wrap_offset": 0
			},
			"font_sizes": {
				"font_size": 16
			},
			"fonts": {
				"font": 0
			},
			"styles": {
				"focus": "StyleBoxEmpty_codeedit_focus"
			}
		},
		"Label": {
			"colors": {
				"font_color": "text_secondary"
			},
			"font_sizes": {
				"font_size": 14
			}
		},
		"Panel": {
			"styles": {
				"panel": "StyleBoxFlat_panel_codeedit"
			}
		},
		"RichTextLabel": {
			"colors": {
				"default_color": "text_tertiary"
			},
			"constants": {
				"line_separation": 0,
				"text_highlight_v_padding": 0
			},
			"font_sizes": {
				"h1_font_size": 44,
				"h2_font_size": 36,
				"h3_font_size": 28,
				"h4_font_size": 22,
				"h5_font_size": 22,
				"h6_font_size": 22
			},
			"fonts": {
				"italics_font": 1,
				"normal_font": 0
			}
		},
		"TabContainer": {
			"colors": {
				"font_hovered_color": "text_tertiary",
				"font_selected_color": "text_tertiary",
				"font_unselected_color": "text_tertiary"
			},
			"constants": {
				"side_margin": 4,
				"tab_separation": 6
			},
			"font_sizes": {
				"font_size": 14
			},
			"styles": {
				"panel": "StyleBoxFlat_tabcontainer_panel",
				"tab_hovered": "StyleBoxFlat_tab_hovered",
				"tab_selected": "StyleBoxFlat_tab_selected",
				"tab_unselected": "StyleBoxFlat_tab_unselected",
				"tabbar_background": "StyleBoxFlat_tabbar_background"
			}
		},
		"TextEdit": {
			"colors": {
				"font_color": "text_secondary",
				"font_placeholder_color": "text_placeholder"
			},
			"font_sizes": {
				"font_size": 12
			},
			"styles": {
				"normal": "StyleBoxFlat_textedit_normal"
			}
		},
		"Tree": {
			"colors": {
				"custom_button_font_highlight": "text_dimmed",
				"font_color": "text_dimmed",
				"font_hovered_color": "text_accent",
				"font_hovered_dimmed_color": "text_dimmed",
				"font_hovered_selected_color": "text_accent",
				"font_selected_color": "text_secondary"
			},
			"constants": {
				"draw_guides": 0,
				"icon_max_width": 14,
				"scrollbar_margin_bottom": 4,
				"scrollbar_margin_right": 4,
				"scrollbar_margin_top": 4
			},
			"font_sizes": {
				"font_size": 14
			},
			"styles": {
				"button_hover": "StyleBoxEmpty_tree_button_hover",
				"button_pressed": "StyleBoxEmpty_tree_button_pressed",
				"hovered": "StyleBoxFlat_tree_hovered",
				"hovered_dimmed": "StyleBoxFlat_tree_hovered_dimmed",
				"hovered_selected": "StyleBoxFlat_tree_hovered_selected",
				"panel": "StyleBoxFlat_tree_panel",
				"selected": "StyleBoxFlat_tree_selected"
			}
		}
	}

	var err = ResourceSaver.save(def, "res://themes/light.theme_definition.tres")
	if err == OK:
		print("Successfully generated light.theme_definition.tres")
	else:
		push_error("Failed to save theme definition")
