extends RefCounted
class_name ResponsiveLayout

const WIDE_MIN_WIDTH := 1800
const MID_MIN_WIDTH := 1200
const SHORT_MAX_HEIGHT := 760

static func mode_for_width(width: int) -> String:
	if width >= WIDE_MIN_WIDTH:
		return "wide"
	if width >= MID_MIN_WIDTH:
		return "mid"
	return "compact"

static func is_short_height(height: int) -> bool:
	return height <= SHORT_MAX_HEIGHT

static func country_mat_size(mode: String, short_viewport: bool) -> Vector2:
	if mode == "wide":
		return Vector2(760, 330)
	if mode == "mid":
		return Vector2(760, 330)
	if short_viewport:
		return Vector2(720, 330)
	return Vector2(720, 360)

static func phase_chip_width(mode: String) -> int:
	if mode == "wide":
		return 118
	if mode == "mid":
		return 96
	return 72
