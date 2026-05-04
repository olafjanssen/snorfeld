extends Window

@onready var character_tree: Tree = $VBoxContainer/HSplitContainer/TabContainer/CharacterTree
@onready var character_sheet: RichTextLabel = $VBoxContainer/HSplitContainer/CharacterSheet
@onready var status_message: RichTextLabel = $VBoxContainer/PanelContainer/HBoxContainer/StatusMessage

var characters: Array = []

func _ready():
	character_tree.item_selected.connect(_on_character_selected)
	EventBus.folder_opened.connect(_on_folder_opened)

	# Set initial position next to main editor
	position = Vector2(820, 0)

	# Detect screen DPI and set appropriate scale
	var dpi := DisplayServer.screen_get_dpi(0)
	var ui_scale := 2.0 if dpi > 144 else 1.0
	set_content_scale_factor(ui_scale)

	# Load characters immediately
	await get_tree().process_frame
	_on_folder_opened(ProjectState.get_current_path())

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		queue_free()

func _on_folder_opened(_path: String):
	_load_characters()

func _load_characters():
	characters = CharacterService.get_all_project_characters()
	_build_character_tree()
	if characters.size() > 0:
		status_message.text = "%d characters loaded" % characters.size()
	else:
		status_message.text = "No characters found"

func _build_character_tree():
	character_tree.clear()
	var root = character_tree.create_item()
	root.set_text(0, "Characters")
	root.set_metadata(0, {"type": "root"})

	# Sort characters by appearance count (descending), then by name
	characters.sort_custom(func(a, b):
		var a_appearances = a.get("appearances", []).size()
		var b_appearances = b.get("appearances", []).size()
		if a_appearances != b_appearances:
			return a_appearances > b_appearances
		return a.get("name", "").naturalnocasecmp_to(b.get("name", "")) < 0
	)

	for char_data in characters:
		var item = character_tree.create_item(root)
		var full_name = char_data.get("name", "Unknown")
		item.set_text(0, full_name)
		item.set_metadata(0, {"type": "character", "data": char_data})

func _on_character_selected():
	var item = character_tree.get_selected()
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if metadata == null:
		return
	if metadata.get("type", "") != "character":
		return

	var char_data = metadata["data"]
	_display_character_sheet(char_data)

func _display_character_sheet(char_data: Dictionary):
	var full_name = char_data.get("name", "Unknown")
	var output = ""

	output += "[b][font_size=18]%s[/font_size][/b]" % [full_name]

	# Aliases
	var aliases = char_data.get("aliases", [])
	if aliases.size() > 0:
		output += " (%s)" % [", ".join(aliases)]

	output += "\n\n"

	# Plot Roles
	var plot_roles = char_data.get("plot_roles", [])
	if plot_roles.size() > 0:
		output += "[b]Role:[/b] %s\n\n" % [", ".join(plot_roles)]

	# Archetypes
	var archetypes = char_data.get("archetypes", [])
	if archetypes.size() > 0:
		output += "[b]Archetypes:[/b] %s\n\n" % [", ".join(archetypes)]

	# Traits
	var traits = char_data.get("traits", [])
	if traits.size() > 0:
		output += "[b]Traits:[/b] %s\n\n" % [", ".join(traits)]

	# Relationships
	var relationships = char_data.get("relationships", {})
	if relationships.size() > 0:
		output += "[b]Relationships:[/b]\n"
		for other_char in relationships:
			output += "[ul][i]%s[/i]: %s[/ul]\n" % [other_char, relationships[other_char]]
		output += "\n"

	# Notes
	var notes = char_data.get("notes", {})
	if notes.size() > 0:
		output += "[b]Chapter Notes:[/b]\n"
		if notes is Dictionary:
			for chapter in notes:
				output += "[ul]%s [i](%s)[/i][/ul]\n" % [notes[chapter], chapter]
		elif notes is String:
			output += "  %s\n" % [notes]
		output += "\n"

	character_sheet.text = output
