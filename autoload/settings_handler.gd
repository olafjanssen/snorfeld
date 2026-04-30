extends Node
# SettingsHandler - Manages the settings panel instance

const SettingsPanelScene = preload("res://scenes/settings/settings_panel.tscn")

var settings_panel: Window


func _ready() -> void:
	GlobalSignals.open_settings.connect(_on_open_settings)
	GlobalSignals.settings_closed.connect(_on_settings_closed)


func _on_open_settings() -> void:
	if settings_panel:
		settings_panel.queue_free()
	settings_panel = SettingsPanelScene.instantiate()
	get_tree().root.add_child(settings_panel)
	settings_panel.popup_centered()


func _on_settings_closed() -> void:
	if settings_panel:
		settings_panel.queue_free()
		settings_panel = null
