@tool
class_name MarkdownLabel
extends RichTextLabel

## A simplified MarkdownLabel that supports keeping markdown syntax characters visible.
##
## Supports: headers, bold, italic, strikethrough, paragraphs

@export_multiline var markdown_text: String : set = _set_markdown_text

@export var keep_markdown_markers: bool = true

var _dirty: bool = false

func _ready() -> void:
	bbcode_enabled = true

func _set_markdown_text(new_text: String) -> void:
	markdown_text = new_text
	queue_update()

func queue_update() -> void:
	_dirty = true
	queue_redraw()

func _process(_delta: float) -> void:
	if _dirty:
		_update()
		_dirty = false

func _update() -> void:
	super.clear()
	super.parse_bbcode(_convert_markdown(markdown_text))


func _convert_markdown(source_text: String) -> String:
	if not bbcode_enabled:
		return source_text
	var result: String = ""
	var lines := source_text.split("\n")
	for line in lines:
		line = line.trim_suffix("\r")
		line = _process_inline_formatting(line)
		line = _process_header(line)
		if result.length() > 0:
			result += "\n"
		result += line
	return result

func _process_header(line: String) -> String:
	var result := line
	var regex := RegEx.create_from_string("^(#+)\\s*(.+)$")
	if not regex:
		return result
	var m := regex.search(line)
	if not m:
		return result

	if keep_markdown_markers:
		result = "[b][font_size=%d]%s %s[/font_size][/b]" % [_get_header_size(m.get_string(1).length()), m.get_string(1), m.get_string(2)]
	else:
		result = "[b][font_size=%d]%s[/font_size][/b]" % [_get_header_size(m.get_string(1).length()), m.get_string(2)]

	return result

func _process_inline_formatting(line: String) -> String:
	var result := line
	result = _process_paired(result, "(\\*\\*|__)(.+?)\\1", "[b]", "[/b]")
	result = _process_paired(result, "(\\*|_)(.+?)\\1", "[i]", "[/i]")
	result = _process_paired(result, "(~~)(.+?)\\1", "[s]", "[/s]")
	return result

func _process_paired(text: String, pattern: String, open_tag: String, close_tag: String) -> String:
	var regex := RegEx.create_from_string(pattern)
	if not regex:
		return text
	var result := text
	var matches := regex.search_all(result)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var start := m.get_start()
		var end := m.get_end()
		if keep_markdown_markers:
			result = result.substr(0, start) + open_tag + m.get_string(0) + close_tag + result.substr(end)
		else:
			result = result.substr(0, start) + open_tag + m.get_string(2) + close_tag + result.substr(end)
	return result

func _get_header_size(level: int) -> int:
	var theme_names := ["h1_font_size", "h2_font_size", "h3_font_size", "h4_font_size", "h5_font_size", "h6_font_size"]
	print(level)
	if level >= 1 and level <= 6:
		var theme_size := get_theme_font_size(theme_names[level - 1])
		print(theme_size)
		if theme_size != null:
			return theme_size
	return get_theme_default_font_size()
