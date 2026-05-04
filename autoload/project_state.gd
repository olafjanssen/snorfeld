extends Node
## ProjectState - Tracks current project state
## Separates state management from the signal bus (EventBus)

# Current project state
var current_path: String = ""

func _ready() -> void:
	# Track state by listening to EventBus signals
	EventBus.folder_opened.connect(_on_folder_opened)

func _on_folder_opened(path: String) -> void:
	current_path = path

# Public accessor
func get_current_path() -> String:
	return current_path
