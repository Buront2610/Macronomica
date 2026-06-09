extends RichTextLabel
class_name ResolutionLog

const VISIBLE_LINES := 14

func setup(min_height: float = 0.0) -> void:
	bbcode_enabled = true
	if min_height > 0.0:
		custom_minimum_size = Vector2(0, min_height)
	else:
		size_flags_vertical = Control.SIZE_EXPAND_FILL

func refresh(log_entries: Array) -> void:
	var visible: Array = log_entries.slice(max(0, log_entries.size() - VISIBLE_LINES), log_entries.size())
	text = "\n".join(visible)
