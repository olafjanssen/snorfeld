@tool
class_name LightThemeDefinitionGenerator
extends EditorScript

# gdlint:ignore-file:file-length,magic-number

# gdlint:ignore-function:long-function
func _run():
	var def: ThemeDefinition = ThemeDefinition.new()

	# Set semantic colors using hex codes
	def.colors = {
		"bg_primary": Color.html("#ddddddff"),
		"bg_secondary": Color.html("#eaeaeaff"),
		"bg_lighter": Color.html("#f3f3f3ff"),
		"bg_lightest": Color.html("#f9f9f9ff"),
		"bg_dark": Color.html("#c9c9c9ff"),
		"bg_medium": Color.html("#e0e0e0ff"),
		"border_primary": Color.html("#c9c9caff"),
		"border_accent": Color.html("#0588eeff"),
		"text_primary": Color.html("#1e1e1eff"),
		"text_secondary": Color.html("#242629ff"),
		"text_tertiary": Color.html("#313131ff"),
		"text_dimmed": Color.html("#58585bff"),
		"text_placeholder": Color.html("#7e8086ff"),
		"text_accent": Color.html("#0078d4ff"),
		# Syntax highlighting colors
		"syntax_normal": Color.html("#1e1e1eff"),
		"syntax_header": Color.html("#2185b9ff"),
		"syntax_bold": Color.html("#000000ff"),
		"syntax_italic": Color.html("#1e1e1ec8"),
		"syntax_dialog": Color.html("#1e1e1ec8"),
		# Diff colors
		"diff_delete_bg": Color.html("#ff0000B0"),
		"diff_insert_bg": Color.html("#00ff00B0"),
		"diff_change_bg": Color.html("#ffa500B0")
	}

	# Set styles
	def.styles = {
		# Original theme styles
		"StyleBoxFlat_button_hover": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_all": ThemeConstants.BORDER_WIDTH_THIN,
			"corner_radius_all": ThemeConstants.CORNER_RADIUS_SMALL
		},
		"StyleBoxFlat_button_normal": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_all": ThemeConstants.BORDER_WIDTH_THIN,
			"corner_radius_all": ThemeConstants.CORNER_RADIUS_SMALL
		},
		"StyleBoxFlat_button_pressed": {
			"type": "StyleBoxFlat",
			"border_color": "border_primary",
			"border_width_all": ThemeConstants.BORDER_WIDTH_THIN,
			"corner_radius_all": ThemeConstants.CORNER_RADIUS_SMALL
		},
		"StyleBoxEmpty_codeedit_focus": {
			"type": "StyleBoxEmpty"
		},
		"StyleBoxFlat_panel_codeedit": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lighter"
		},
		"StyleBoxFlat_panel_popupwindow": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lighter",
			"border_color": "border_primary",
			"border_width_all": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_tabcontainer_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_left": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_tab_hovered": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_dark",
			"border_color": "border_primary",
			"border_width_left": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_right": ThemeConstants.BORDER_WIDTH_THIN,
			"expand_margin_left": ThemeConstants.MARGIN_SMALL,
			"expand_margin_right": ThemeConstants.MARGIN_SMALL
		},
		"StyleBoxFlat_tab_selected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_left": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_right": ThemeConstants.BORDER_WIDTH_THIN,
			"expand_margin_left": ThemeConstants.MARGIN_SMALL,
			"expand_margin_right": ThemeConstants.MARGIN_SMALL,
			"expand_margin_bottom": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_tab_unselected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_left": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_right": ThemeConstants.BORDER_WIDTH_THIN,
			"expand_margin_left": ThemeConstants.MARGIN_SMALL,
			"expand_margin_right": ThemeConstants.MARGIN_SMALL
		},
		"StyleBoxFlat_tabbar_background": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_right": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_bottom": ThemeConstants.BORDER_WIDTH_THIN
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
			"border_width_top": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_bottom": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_tree_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_right": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_tree_selected": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_dark",
			"border_color": "border_accent",
			"border_width_top": ThemeConstants.BORDER_WIDTH_THIN,
			"border_width_bottom": ThemeConstants.BORDER_WIDTH_THIN
		},
		# Scene-specific styles
		"StyleBoxFlat_settings_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary"
		},
		"StyleBoxFlat_storybible_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_top": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_git_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lightest",
			"border_color": "border_primary",
			"border_width_top": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_paneled_label": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_lighter",
			"border_color": "border_primary",
			"border_width_all": ThemeConstants.BORDER_WIDTH_THIN,
			"corner_radius_all": ThemeConstants.CORNER_RADIUS_MEDIUM
		},
		"StyleBoxFlat_statusbar": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_top": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_windowbar": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_primary",
			"border_color": "border_primary",
			"border_width_bottom": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxFlat_texteditor_panel": {
			"type": "StyleBoxFlat",
			"bg_color": "bg_secondary",
			"border_color": "border_primary",
			"border_width_bottom": ThemeConstants.BORDER_WIDTH_THIN
		},
		"StyleBoxEmpty_paragraph_separator": {
			"type": "StyleBoxEmpty"
		}
	}

	# Set external resources (Lora and Inter font families)
	def.external_resources = [
		{"type": "FontFile", "path": "res://fonts/Lora-VariableFont_wght.ttf"},
		{"type": "FontFile", "path": "res://fonts/Lora-Italic-VariableFont_wght.ttf"},
		{"type": "FontFile", "path": "res://fonts/Inter-VariableFont_opsz,wght.ttf"},
		{"type": "FontFile", "path": "res://fonts/Inter-Italic-VariableFont_opsz,wght.ttf"}
	]

	# Define fonts (including variations)
	# Inter Bold variation: weight=600, opsz=14
	# Axis tags: 'wght' = 2003265652, 'opsz' = 1869640570
	def.fonts = {
		"Inter_Regular": {
			"type": "FontFile",
			"index": 2
		},
		"Inter_Italic": {
			"type": "FontFile",
			"index": 3
		},
		"Inter_Bold": {
			"type": "FontVariation",
			"base_font": 2,
			"variation_opentype": {
				1869640570: 14,  # opsz
				2003265652: 600   # wght
			}
		},
		"Lora_Regular": {
			"type": "FontFile",
			"index": 0
		},
		"Lora_Italic": {
			"type": "FontFile",
			"index": 1
		}
	}

	# Set control overrides
	def.control_overrides = {
		# === Base control types ===
		"Button": {
			"colors": {
				"font_color": "text_secondary",
				"font_hover_color": "text_secondary",
				"font_hover_pressed_color": "text_secondary",
				"font_pressed_color": "text_secondary"
			},
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_SMALL
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
				"selection_color": Color.html("#aed6ffff")
			},
			"constants": {
				"wrap_offset": 0
			},
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_LARGE
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
				"font_size": ThemeConstants.FONT_SIZE_MEDIUM
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
				"h1_font_size": ThemeConstants.FONT_SIZE_H1,
				"h2_font_size": ThemeConstants.FONT_SIZE_H2,
				"h3_font_size": ThemeConstants.FONT_SIZE_H3,
				"h4_font_size": ThemeConstants.FONT_SIZE_H4,
				"h5_font_size": ThemeConstants.FONT_SIZE_H4,
				"h6_font_size": ThemeConstants.FONT_SIZE_H4
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
				"side_margin": ThemeConstants.MARGIN_SMALL,
				"tab_separation": ThemeConstants.TAB_SEPARATION
			},
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_MEDIUM
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
				"font_size": ThemeConstants.FONT_SIZE_SMALL
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
				"icon_max_width": ThemeConstants.ICON_MAX_WIDTH,
				"scrollbar_margin_bottom": ThemeConstants.SCROLLBAR_MARGIN,
				"scrollbar_margin_right": ThemeConstants.SCROLLBAR_MARGIN,
				"scrollbar_margin_top": ThemeConstants.SCROLLBAR_MARGIN
			},
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_MEDIUM
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
		},
		# === Custom control types for scene-specific styling ===
		"SettingsPanel": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_settings_panel"
			}
		},
		"StoryBiblePanel": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_storybible_panel"
			}
		},
		"GitCommitPanel": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_git_panel"
			}
		},
		"PaneledLabel": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_paneled_label"
			}
		},
		"StatusBar": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_statusbar"
			}
		},
		"WindowBar": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_windowbar"
			}
		},
		"TextEditorPanel": {
			"base_type": "Panel",
			"styles": {
				"panel": "StyleBoxFlat_texteditor_panel"
			}
		},
		"HSeparator": {
			"styles": {
				"separator": "StyleBoxEmpty_paragraph_separator"
			}
		},
		# === Scene-specific control types with Font overrides ===
		"StoryBibleCharacterSheet": {
			"base_type": "RichTextLabel",
			"colors": {
				"default_color": "text_primary"
			},
			"fonts": {
				"normal_font": "Inter_Regular",
				"bold_font": "Inter_Bold",
				"bold_italics_font": "Inter_Italic",
				"italics_font": "Inter_Italic",
				"mono_font": "Inter_Regular"
			},
			"font_sizes": {
				"normal_font_size": ThemeConstants.FONT_SIZE_MEDIUM,
				"bold_font_size": ThemeConstants.FONT_SIZE_MEDIUM,
				"bold_italics_font_size": ThemeConstants.FONT_SIZE_MEDIUM,
				"italics_font_size": ThemeConstants.FONT_SIZE_MEDIUM,
				"mono_font_size": ThemeConstants.FONT_SIZE_MEDIUM
			}
		},
		"StoryBibleStatusMessage": {
			"base_type": "RichTextLabel",
			"fonts": {
				"normal_font": "Inter_Regular"
			},
			"font_sizes": {
				"normal_font_size": ThemeConstants.FONT_SIZE_SMALL
			}
		},
		"EditorStatusMessage": {
			"base_type": "RichTextLabel",
			"fonts": {
				"normal_font": "Inter_Regular"
			},
			"font_sizes": {
				"normal_font_size": ThemeConstants.FONT_SIZE_SMALL
			}
		},
		"TextEditorTitleMessage": {
			"base_type": "Label",
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_MEDIUM
			}
		},
		"SyntaxHighlighter": {
			"colors": {
				"syntax_normal": "syntax_normal",
				"syntax_header": "syntax_header",
				"syntax_bold": "syntax_bold",
				"syntax_italic": "syntax_italic",
				"syntax_dialog": "syntax_dialog"
			}
		},
		"DiffCalculator": {
			"colors": {
				"diff_delete_bg": "diff_delete_bg",
				"diff_insert_bg": "diff_insert_bg",
				"diff_change_bg": "diff_change_bg"
			}
		},
		"PopupMenu": {
			"colors": {
				"font_color": "text_secondary",
				"font_hover_color": "text_primary",
				"font_disabled_color": "text_dimmed",
				"font_accelerator_color": "text_tertiary"
			},
			"font_sizes": {
				"font_size": ThemeConstants.FONT_SIZE_MEDIUM
			},
			"constants": {
				"h_separation": ThemeConstants.MARGIN_MEDIUM,
				"v_separation": ThemeConstants.MARGIN_SMALL,
				"item_start_padding": ThemeConstants.PADDING_LARGE,
				"item_end_padding": ThemeConstants.PADDING_LARGE
			},
			"styles": {
				"panel": "StyleBoxFlat_panel_popupwindow",
				"hover": "StyleBoxFlat_button_hover",
				"separator": "StyleBoxEmpty_paragraph_separator"
			}
		}
	}

	DirAccess.remove_absolute("res://themes/light.theme_definition.tres")
	var err: int = ResourceSaver.save(def, "res://themes/light.theme_definition.tres")
	if err != OK:
		push_error("Failed to save theme definition: light.theme_definition.tres")

	print("Completed!")
