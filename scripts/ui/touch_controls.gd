extends Control
## Touch-Tasten für das Handy: links/rechts lenken, bremsen, Item benutzen.
##
## Die Tasten lösen dieselben Input-Actions aus wie die Tastatur. Mehrere Finger
## gleichzeitig funktionieren, und man kann zwischen Tasten wischen, ohne loszulassen.

const RADIUS := 72.0
const HIT_SCALE := 1.35
const BUTTONS := [
	{"action": "steer_left", "icon": "left", "corner": Vector2(0, 1), "offset": Vector2(120, -120)},
	{
		"action": "steer_right",
		"icon": "right",
		"corner": Vector2(0, 1),
		"offset": Vector2(300, -120)
	},
	{"action": "brake", "icon": "BREMSE", "corner": Vector2(1, 1), "offset": Vector2(-300, -120)},
	{"action": "use_item", "icon": "ITEM", "corner": Vector2(1, 1), "offset": Vector2(-120, -170)},
]

## Item-Taste ist sichtbar, aber ausgegraut, bis es Items gibt.
@export var item_enabled := false

var _touches := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_assign(touch.index, _hit(touch.position) if touch.pressed else "")
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_assign(drag.index, _hit(drag.position))


func _assign(index: int, action: String) -> void:
	var previous: String = _touches.get(index, "")
	if previous == action:
		return
	if previous != "":
		_touches.erase(index)
		if not _touches.values().has(previous):
			Input.action_release(previous)
	if action != "":
		_touches[index] = action
		Input.action_press(action)
	queue_redraw()


func _hit(pos: Vector2) -> String:
	for button in BUTTONS:
		if button.action == "use_item" and not item_enabled:
			continue
		if pos.distance_to(_center(button)) <= RADIUS * HIT_SCALE:
			return button.action
	return ""


func _center(button: Dictionary) -> Vector2:
	return size * (button.corner as Vector2) + (button.offset as Vector2)


func _draw() -> void:
	var font := get_theme_default_font()
	for button in BUTTONS:
		var center := _center(button)
		var pressed := _touches.values().has(button.action)
		var enabled: bool = button.action != "use_item" or item_enabled
		var alpha := 1.0 if enabled else 0.4
		var fill := Color(0.93, 0.89, 0.78, 0.35) if pressed else Color(0.08, 0.08, 0.07, 0.32)
		draw_circle(center, RADIUS, Color(fill, fill.a * alpha))
		draw_arc(center, RADIUS, 0.0, TAU, 48, Color(0.93, 0.89, 0.78, 0.6 * alpha), 3.0, true)
		var ink := Color(0.95, 0.92, 0.84, 0.9 * alpha)
		match button.icon:
			"left":
				_draw_arrow(center, -1.0, ink)
			"right":
				_draw_arrow(center, 1.0, ink)
			_:
				var text: String = button.icon
				var fs := 22
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(
					font,
					center + Vector2(-w * 0.5, fs * 0.35),
					text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					fs,
					ink
				)


func _draw_arrow(center: Vector2, direction: float, color: Color) -> void:
	var s := 26.0
	draw_colored_polygon(
		PackedVector2Array(
			[
				center + Vector2(direction * s, 0),
				center + Vector2(-direction * s * 0.7, -s),
				center + Vector2(-direction * s * 0.7, s),
			]
		),
		color
	)
