extends Control

@onready var diff_label: ClickableRichTextLabel = $VBoxContainer/HSplitContainer/RichTextLabel

func _ready():
	await get_tree().process_frame
	$VBoxContainer.offset_top = $MenuBar.size.y
	$VBoxContainer/HSplitContainer.split_offsets = PackedInt32Array([200, 800, 1600])

	# Connect git diff signal
	GlobalSignals.show_git_diff.connect(_on_show_git_diff)

func _on_show_git_diff(file_path: String, diff: String):
	# Set the diff text in the ClickableRichTextLabel
	# Format with file path as header
	diff_label.text = "[b]Git Diff: %s[/b]\n\n%s" % [file_path.get_file(), diff]
