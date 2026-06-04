extends SceneTree

const MainScript := preload("res://src/ui/main.gd")
const BANNED_RUNTIME_CLASSES := [
	"PanelContainer",
	"HBoxContainer",
	"VBoxContainer",
	"ScrollContainer",
	"TabContainer",
	"Button"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await process_frame
	await process_frame

	var banned := []
	_collect_banned(ui, banned)
	_assert(banned.is_empty(), "main board runtime avoids banned UI nodes: %s" % ", ".join(banned))
	_assert(ui.country_seats.size() == 4, "runtime board shows four country seats without scroll")
	_assert(ui.worker_nodes.size() == 5, "runtime board shows worker tokens as board pieces")
	_assert(ui.phase_pips.size() == ui.GameStateScript.PHASES.size(), "runtime board shows phase pips as board markers")
	_assert(ui.hand_nodes.size() == ui.game.countries[ui.selected_country_index].hand.size(), "runtime board deals selected hand as board cards")
	_assert(ui.policy_slot != null, "runtime board has a physical policy slot")

	var viewport := ui.get_viewport_rect()
	for seat in ui.country_seats:
		_assert(_inside_viewport(seat, viewport), "country seat remains inside the board viewport: %s" % seat.name)
	for card in ui.hand_nodes:
		_assert(_inside_viewport(card, viewport), "hand card remains inside the board viewport: %s" % card.name)
	for worker in ui.worker_nodes.keys():
		_assert(_inside_viewport(ui.worker_nodes[worker], viewport), "worker token remains inside the board viewport: %s" % worker)
	for pip in ui.phase_pips:
		_assert(_inside_viewport(pip, viewport), "phase pip remains inside the board viewport: %s" % pip.name)
	for token_name in ["RestartToken", "RecommendToken", "AdvanceToken"]:
		var token: Control = ui.board_layer.get_node_or_null(token_name)
		_assert(token != null, "action token exists on the board: %s" % token_name)
		_assert(_inside_viewport(token, viewport), "action token remains inside the board viewport: %s" % token_name)
	_assert(_inside_viewport(ui.policy_slot, viewport), "policy slot remains inside the board viewport")

	print("Smoke board runtime contract passed.")
	quit(0)

func _collect_banned(node: Node, banned: Array) -> void:
	for runtime_class in BANNED_RUNTIME_CLASSES:
		if node.is_class(runtime_class):
			banned.append("%s<%s>" % [node.name, runtime_class])
	for child in node.get_children():
		_collect_banned(child, banned)

func _inside_viewport(control: Control, viewport: Rect2) -> bool:
	var rect := Rect2(control.global_position, control.size)
	return viewport.encloses(rect)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
