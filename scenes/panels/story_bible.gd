extends Window

# Constants
const HIGH_DPI_THRESHOLD: int = 144
const SIDE_PANEL_X_POSITION: int = 820

@onready var tab_container: TabContainer = $VBoxContainer/HSplitContainer/TabContainer
@onready var character_tree: Tree = $VBoxContainer/HSplitContainer/TabContainer/CharacterTree
@onready var object_tree: Tree = $VBoxContainer/HSplitContainer/TabContainer/ObjectTree
@onready var content_sheet: RichTextLabel = $VBoxContainer/HSplitContainer/ContentSheet
@onready var status_message: RichTextLabel = $VBoxContainer/PanelContainer/HBoxContainer/StatusMessage

var characters: Array = []
var objects: Array = []

func _ready():
	character_tree.item_selected.connect(_on_character_selected)
	object_tree.item_selected.connect(_on_object_selected)
	tab_container.tab_changed.connect(_on_tab_changed)
	EventBus.folder_opened.connect(_on_folder_opened)

	# Set initial position next to main editor
	position = Vector2(SIDE_PANEL_X_POSITION, 0)

	# Detect screen DPI and set appropriate scale
	var dpi: int = DisplayServer.screen_get_dpi(0)
	var ui_scale: float = 2.0 if dpi > HIGH_DPI_THRESHOLD else 1.0
	set_content_scale_factor(ui_scale)

	# Load characters and objects immediately
	await get_tree().process_frame
	_on_folder_opened(BookService.loaded_project_path)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		queue_free()

func _load_characters():
	characters = AnalysisManager.CharacterService.get_all_project_characters()
	_build_character_tree()

func _load_objects():
	objects = AnalysisManager.ObjectService.get_all_project_objects()
	_build_object_tree()

func _update_status_message():
	var char_count: int = characters.size()
	var obj_count: int = objects.size()
	if char_count > 0 and obj_count > 0:
		status_message.text = "%d characters, %d objects loaded" % [char_count, obj_count]
	elif char_count > 0:
		status_message.text = "%d characters loaded" % char_count
	elif obj_count > 0:
		status_message.text = "%d objects loaded" % obj_count
	else:
		status_message.text = "No characters or objects found"

func _build_character_tree():
	character_tree.clear()
	var root: TreeItem = character_tree.create_item()
	root.set_text(0, "Characters")
	root.set_metadata(0, {"type": "root"})

	# Sort characters by appearance count (descending), then by name
	characters.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_appearances: int = a.get("appearances", []).size()
		var b_appearances: int = b.get("appearances", []).size()
		if a_appearances != b_appearances:
			return a_appearances > b_appearances
		return a.get("name", "").naturalnocasecmp_to(b.get("name", "")) < 0
	)

	for char_data: Dictionary in characters:
		var item: TreeItem = character_tree.create_item(root)
		var full_name: String = char_data.get("name", "Unknown")
		item.set_text(0, full_name)
		item.set_metadata(0, {"type": "character", "data": char_data})

func _build_object_tree():
	object_tree.clear()
	var root: TreeItem = object_tree.create_item()
	root.set_text(0, "Objects")
	root.set_metadata(0, {"type": "root"})

	# Sort objects by appearance count (descending), then by name
	objects.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_appearances: int = a.get("appearances", []).size()
		var b_appearances: int = b.get("appearances", []).size()
		if a_appearances != b_appearances:
			return a_appearances > b_appearances
		return a.get("name", "").naturalnocasecmp_to(b.get("name", "")) < 0
	)

	for obj_data: Dictionary in objects:
		var item: TreeItem = object_tree.create_item(root)
		var full_name: String = obj_data.get("name", "Unknown")
		item.set_text(0, full_name)
		item.set_metadata(0, {"type": "object", "data": obj_data})

func _on_character_selected():
	var item: TreeItem = character_tree.get_selected()
	if item == null:
		return
	var metadata: Dictionary = item.get_metadata(0)
	if metadata == null:
		return
	if metadata.get("type", "") != "character":
		return

	var char_data: Dictionary = metadata["data"]
	_display_character_sheet(char_data)

func _on_object_selected():
	var item: TreeItem = object_tree.get_selected()
	if item == null:
		return
	var metadata: Dictionary = item.get_metadata(0)
	if metadata == null:
		return
	if metadata.get("type", "") != "object":
		return

	var obj_data: Dictionary = metadata["data"]
	_display_object_sheet(obj_data)

func _on_tab_changed(tab_index: int):
	# Update the sheet display based on which tab is active
	if tab_index == 0:
		# Characters tab - refresh character display
		var selected: TreeItem = character_tree.get_selected()
		if selected:
			var metadata: Dictionary = selected.get_metadata(0)
			if metadata and metadata.get("type") == "character":
				_display_character_sheet(metadata["data"])
		else:
			content_sheet.text = ""
		content_sheet.text = ""
	elif tab_index == 1:
		# Objects tab - refresh object display
		var selected: TreeItem = object_tree.get_selected()
		if selected:
			var metadata: Dictionary = selected.get_metadata(0)
			if metadata and metadata.get("type") == "object":
				_display_object_sheet(metadata["data"])
		else:
			content_sheet.text = ""
		content_sheet.text = ""

func _display_character_sheet(char_data: Dictionary):
	var full_name: String = char_data.get("name", "Unknown")
	var output: String = ""

	output += "[b][font_size=18]%s[/font_size][/b]" % [full_name]

	# Aliases
	var aliases: Array = char_data.get("aliases", [])
	if aliases.size() > 0:
		output += " (%s)" % [", ".join(aliases)]

	output += "\n\n"

	# Plot Roles
	var plot_roles: Array = char_data.get("plot_roles", [])
	if plot_roles.size() > 0:
		output += "[b]Role:[/b] %s\n\n" % [", ".join(plot_roles)]

	# Archetypes
	var archetypes: Array = char_data.get("archetypes", [])
	if archetypes.size() > 0:
		output += "[b]Archetypes:[/b] %s\n\n" % [", ".join(archetypes)]

	# Traits
	var traits: Array = char_data.get("traits", [])
	if traits.size() > 0:
		output += "[b]Traits:[/b] %s\n\n" % [", ".join(traits)]

	# Relationships
	var relationships: Dictionary = char_data.get("relationships", {})
	if relationships.size() > 0:
		output += "[b]Relationships:[/b]\n"
		for other_char: String in relationships:
			output += "[ul][i]%s[/i]: %s[/ul]\n" % [other_char, relationships[other_char]]
		output += "\n"

	# Notes
	var notes = char_data.get("notes", {})
	if notes.size() > 0:
		output += "[b]Chapter Notes:[/b]\n"
		if notes is Dictionary:
			for chapter: String in notes:
				output += "[ul]%s [i](%s)[/i][/ul]\n" % [notes[chapter], chapter]
		elif notes is String:
			output += "  %s\n" % [notes]
		output += "\n"

	content_sheet.text = output


func _display_object_sheet(obj_data: Dictionary):
	var full_name: String = obj_data.get("name", "Unknown")
	var output: String = ""

	output += "[b][font_size=18]%s[/font_size][/b]" % [full_name]

	# Aliases
	var aliases: Array = obj_data.get("aliases", [])
	if aliases.size() > 0:
		output += " (%s)" % [", ".join(aliases)]

	output += "\n\n"

	# Object Types
	var object_types: Array = obj_data.get("object_type", [])
	if object_types.size() > 0:
		output += "[b]Type:[/b] %s\n\n" % [", ".join(object_types)]

	# Description
	var description: String = obj_data.get("description", "")
	if description != "":
		output += "[b]Description:[/b] %s\n\n" % [description]

	# Thematic Relevance
	var thematic_relevance: Array = obj_data.get("thematic_relevance", [])
	if thematic_relevance.size() > 0:
		output += "[b]Themes:[/b] %s\n\n" % [", ".join(thematic_relevance)]

	# Symbolic Meaning
	var symbolic_meaning: Array = obj_data.get("symbolic_meaning", [])
	if symbolic_meaning.size() > 0:
		output += "[b]Symbolic Meaning:[/b] %s\n\n" % [", ".join(symbolic_meaning)]

	# Character Relations
	var character_relations: Dictionary = obj_data.get("character_relations", {})
	if character_relations.size() > 0:
		output += "[b]Character Relations:[/b]\n"
		for char_name: String in character_relations:
			output += "[ul][i]%s[/i]: %s[/ul]\n" % [char_name, character_relations[char_name]]
		output += "\n"

	# Appearances
	var appearances: Array = obj_data.get("appearances", [])
	if appearances.size() > 0:
		output += "[b]Appears in:[/b] %s\n\n" % [", ".join(appearances)]

	# Notes
	var notes = obj_data.get("notes", {})
	if notes.size() > 0:
		output += "[b]Chapter Notes:[/b]\n"
		if notes is Dictionary:
			for chapter: String in notes:
				output += "[ul]%s [i](%s)[/i][/ul]\n" % [notes[chapter], chapter]
		elif notes is String:
			output += "  %s\n" % [notes]
		output += "\n"

	content_sheet.text = output


func _on_folder_opened(_path: String):
	_load_characters()
	_load_objects()
	_update_status_message()
