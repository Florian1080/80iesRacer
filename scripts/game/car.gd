class_name Car
extends CharacterBody2D
## Top-Down-Auto mit arcadiger Fahrphysik.
##
## Das Auto gibt automatisch Gas. Bremsen verlangsamt, im Stand fährt es rückwärts.
## Bremse plus Lenken bei Tempo löst einen Drift aus.
## Die Steuerung kommt immer aus [member input].

## Umrechnung von Pixeln pro Sekunde in km/h für die Anzeige.
const PX_PER_KMH := 5.0

@export_group("Antrieb")
@export var max_speed := 900.0
@export var acceleration := 560.0
@export var brake_power := 1150.0
@export var reverse_speed := 260.0

@export_group("Lenkung")
@export var turn_speed := 3.1
@export var steer_response := 7.0
@export var grip := 9.0
@export var drift_grip := 2.0

@export_group("Untergrund")
@export var grass_speed_factor := 0.45
@export var grass_drag := 1.8
@export var grass_grip_factor := 0.6

@export_group("Aussehen")
@export var body_color := Color("b5462f")
@export var stripe_color := Color("edd99e")

var input := CarInput.new()
## Strecke, auf der das Auto fährt. Ohne Strecke gilt überall Asphalt.
var track: Track
var on_grass := false
var is_drifting := false

var _steer := 0.0


func _physics_process(delta: float) -> void:
	var forward := transform.x
	var right := transform.y
	var v_forward := velocity.dot(forward)
	var v_side := velocity.dot(right)

	on_grass = track != null and not track.is_on_road(global_position)
	var top_speed := max_speed * (grass_speed_factor if on_grass else 1.0)

	_steer = move_toward(_steer, input.steer, steer_response * delta)
	is_drifting = input.brake and v_forward > 300.0 and absf(_steer) > 0.3

	v_forward = _apply_drive(v_forward, top_speed, delta)

	var speed_ratio := clampf(absf(v_forward) / max_speed, 0.0, 1.0)
	var low_speed_factor := clampf(absf(v_forward) / 220.0, 0.0, 1.0)
	var turn := turn_speed * (1.0 - 0.3 * speed_ratio)
	if is_drifting:
		turn *= 1.25
	rotation += _steer * turn * low_speed_factor * signf(v_forward) * delta

	var current_grip := drift_grip if is_drifting else grip
	if on_grass:
		current_grip *= grass_grip_factor
	v_side = lerpf(v_side, 0.0, clampf(current_grip * delta, 0.0, 1.0))

	velocity = forward * v_forward + right * v_side
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity *= 0.96


func get_speed_kmh() -> float:
	return velocity.length() / PX_PER_KMH


## Setzt das Auto an eine Position, z. B. an den Start.
func place_at(start: Transform2D) -> void:
	global_transform = start
	velocity = Vector2.ZERO
	_steer = 0.0
	reset_physics_interpolation()


func _apply_drive(v_forward: float, top_speed: float, delta: float) -> float:
	if is_drifting:
		return move_toward(v_forward, 0.0, brake_power * 0.22 * delta)
	if input.brake:
		if v_forward > 30.0:
			return move_toward(v_forward, 0.0, brake_power * delta)
		return move_toward(v_forward, -reverse_speed, acceleration * 0.6 * delta)
	if v_forward > top_speed:
		return move_toward(v_forward, top_speed, acceleration * grass_drag * delta)
	var falloff := 1.0 - 0.6 * clampf(v_forward / max_speed, 0.0, 1.0)
	return move_toward(v_forward, top_speed, acceleration * falloff * delta)


func _draw() -> void:
	# Schatten
	var shadow := PackedVector2Array()
	for p in _body_shape():
		shadow.append(p + Vector2(3, 5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))

	# Räder
	var tyre := Color("1c1c1a")
	for wheel in [Vector2(18, -16), Vector2(18, 16), Vector2(-19, -16), Vector2(-19, 16)]:
		draw_rect(Rect2(wheel - Vector2(7, 3), Vector2(14, 6)), tyre)

	# Karosserie, flacher Keil mit Klappscheinwerfern
	draw_colored_polygon(_body_shape(), body_color)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-16, -11), Vector2(4, -11), Vector2(4, 11), Vector2(-16, 11)]),
		body_color.darkened(0.12)
	)
	var glass := Color("2b3036")
	draw_colored_polygon(
		PackedVector2Array([Vector2(4, -11), Vector2(15, -9), Vector2(15, 9), Vector2(4, 11)]),
		glass
	)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-24, -9), Vector2(-16, -10), Vector2(-16, 10), Vector2(-24, 9)]
		),
		glass
	)

	# Zierstreifen
	draw_rect(Rect2(Vector2(-31, -2), Vector2(62, 4)), stripe_color)

	# Klappscheinwerfer (eingeklappt) und Rückleuchten
	var lid := body_color.lightened(0.15)
	draw_rect(Rect2(Vector2(24, -12), Vector2(6, 6)), lid)
	draw_rect(Rect2(Vector2(24, 6), Vector2(6, 6)), lid)
	var tail := Color("8f1d14")
	draw_rect(Rect2(Vector2(-32, -13), Vector2(3, 7)), tail)
	draw_rect(Rect2(Vector2(-32, 6), Vector2(3, 7)), tail)

	# Chromstoßstangen
	var chrome := Color("c9c6bd")
	draw_line(Vector2(33, -8), Vector2(33, 8), chrome, 2.0)
	draw_line(Vector2(-33, -11), Vector2(-33, 11), chrome, 2.0)


func _body_shape() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-30, -15),
			Vector2(20, -15),
			Vector2(32, -9),
			Vector2(32, 9),
			Vector2(20, 15),
			Vector2(-30, 15),
			Vector2(-32, 11),
			Vector2(-32, -11),
		]
	)
