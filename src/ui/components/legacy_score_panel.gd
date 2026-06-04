extends RichTextLabel
class_name LegacyScorePanel

const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")

func setup() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false

func refresh(scores: Array) -> void:
	var next_text := ""
	var rank := 1
	for score in scores:
		next_text += "%s %s  [b]%d[/b]\n" % [UiCatalogScript.rank_icon(rank), score["display_name"].substr(0, 2), score["score"]]
		rank += 1
	text = next_text
