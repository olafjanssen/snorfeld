@tool
class_name PaneledRichTextLabel
extends PanelContainer

@onready var TextField: ClickableRichTextLabel = $MarginContainer/ClickableRichTextLabel

func set_text(full_text : String):
	pass 
	TextField.text = full_text
