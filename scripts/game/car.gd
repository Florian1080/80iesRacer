class_name Car
extends CharacterBody2D
## Top-Down-Auto mit arcadiger Fahrphysik.
##
## Das Auto gibt automatisch Gas. Bremsen verlangsamt, im Stand fährt es rückwärts.
## Drift: Beim Lenken kurz bremsen leitet ihn ein, solange man weiter lenkt,
## rutscht das Auto mit Gas quer durch die Kurve. Danach fängt es sich weich wieder.
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

@export_group("Drift")
@export var drift_grip := 2.4
@export var drift_turn_boost := 1.2
## Größter Winkel zwischen Fahrzeugnase und Fahrtrichtung im Drift (Grad).
@export var max_drift_angle := 35.0
## Anteil des Tempos, der pro Sekunde im Drift verloren geht.
@export var drift_speed_loss := 0.18
@export var drift_start_speed := 280.0
@export var drift_keep_speed := 170.0
@export var grip_recovery := 3.5

@export_group("Untergrund")
@export var grass_speed_factor := 0.45
@export var grass_drag := 1.8
@export var grass_grip_factor := 0.6
@export var gravel_speed_factor := 0.3
@export var gravel_drag := 3.2
@export var gravel_grip_factor := 0.45

@export_group("Aussehen")
@export var body_color := Color("b5462f")
@export var stripe_color := Color("edd99e")

var input := CarInput.new()
## Strecke, auf der das Auto fährt. Ohne Strecke gilt überall Asphalt.
var track: Track
var surface := Track.Surface.ROAD
## Neben der Strecke (Gras oder Kies)?
var on_grass := false
var is_drifting := false
## Seitliches Rutschen in px/s, z. B. für Bremsspuren.
var side_slip := 0.0

var _steer := 0.0
var _grip := 9.0
var _smoke: CPUParticles2D


func _ready() -> void:
	_grip = grip
	_smoke = _create_smoke()
	add_child(_smoke)


func _physics_process(delta: float) -> void:
	var forward := transform.x
	var right := transform.y
	var v_forward := velocity.dot(forward)
	var v_side := velocity.dot(right)
	var speed := velocity.length()

	surface = track.get_surface(global_position) if track else Track.Surface.ROAD
	on_grass = surface != Track.Surface.ROAD
	var top_speed := max_speed * _surface_value(1.0, grass_speed_factor, gravel_speed_factor)

	_steer = move_toward(_steer, input.steer, steer_response * delta)
	_update_drift_state(speed, v_forward)

	v_forward = _apply_drive(v_forward, top_speed, delta)

	var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)
	var low_speed_factor := clampf(absf(v_forward) / 220.0, 0.0, 1.0)
	var direction := signf(v_forward)
	if is_drifting:
		low_speed_factor = 1.0
		direction = 1.0
	var turn := turn_speed * (1.0 - 0.3 * speed_ratio)
	if is_drifting:
		turn *= drift_turn_boost
	rotation += _steer * turn * low_speed_factor * direction * delta
	if is_drifting and speed > 50.0:
		# Im Drift dreht sich die Fahrtrichtung nicht mit der Nase mit.
		# Die Nase darf höchstens max_drift_angle von der Fahrtrichtung abweichen.
		var moving := forward * v_forward + right * v_side
		var limit := deg_to_rad(max_drift_angle)
		var slip := clampf(angle_difference(moving.angle(), rotation), -limit, limit)
		rotation = moving.angle() + slip
		forward = transform.x
		right = transform.y
		v_forward = moving.dot(forward)
		v_side = moving.dot(right)

	var target_grip := drift_grip if is_drifting else grip
	if target_grip < _grip:
		_grip = target_grip
	else:
		_grip = move_toward(_grip, target_grip, grip_recovery * grip * delta)
	var current_grip := _grip * _surface_value(1.0, grass_grip_factor, gravel_grip_factor)
	var speed_before := Vector2(v_forward, v_side).length()
	v_side = lerpf(v_side, 0.0, clampf(current_grip * delta, 0.0, 1.0))
	if is_drifting and not input.brake:
		# Powerslide: Der Seitenschub wird größtenteils in Vortrieb umgelenkt statt vernichtet.
		var kept := speed_before * (1.0 - drift_speed_loss * delta)
		var scaled := Vector2(v_forward, v_side).normalized() * kept
		v_forward = scaled.x
		v_side = scaled.y
	side_slip = v_side

	velocity = forward * v_forward + right * v_side
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity *= 0.96
	_update_smoke()


func get_speed_kmh() -> float:
	return velocity.length() / PX_PER_KMH


## Setzt das Auto an eine Position, z. B. an den Start.
func place_at(start: Transform2D) -> void:
	global_transform = start
	velocity = Vector2.ZERO
	_steer = 0.0
	reset_physics_interpolation()


## Rutscht das Auto sichtbar (Drift, starkes Untersteuern oder Vollbremsung)?
func is_sliding() -> bool:
	if is_drifting or absf(side_slip) > 140.0:
		return true
	return input.brake and velocity.dot(transform.x) > 450.0


## Hinterräder in Weltkoordinaten, für Bremsspuren.
func get_rear_wheels() -> PackedVector2Array:
	return PackedVector2Array([to_global(Vector2(-19, -14)), to_global(Vector2(-19, 14))])


func _update_drift_state(speed: float, v_forward: float) -> void:
	if is_drifting:
		is_drifting = absf(_steer) > 0.2 and speed > drift_keep_speed and v_forward > 0.0
	else:
		is_drifting = input.brake and absf(_steer) > 0.4 and speed > drift_start_speed


func _apply_drive(v_forward: float, top_speed: float, delta: float) -> float:
	if is_drifting:
		if input.brake:
			return move_toward(v_forward, 0.0, brake_power * 0.25 * delta)
		return move_toward(v_forward, top_speed * 0.85, acceleration * 0.7 * delta)
	if input.brake:
		if v_forward > 30.0:
			return move_toward(v_forward, 0.0, brake_power * delta)
		return move_toward(v_forward, -reverse_speed, acceleration * 0.6 * delta)
	if v_forward > top_speed:
		var drag := _surface_value(1.0, grass_drag, gravel_drag)
		return move_toward(v_forward, top_speed, acceleration * drag * delta)
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


func _surface_value(road: float, grass: float, gravel: float) -> float:
	match surface:
		Track.Surface.GRASS:
			return grass
		Track.Surface.GRAVEL:
			return gravel
	return road


## Reifenqualm auf Asphalt, Staubwolke im Kiesbett.
func _update_smoke() -> void:
	if surface == Track.Surface.GRAVEL:
		_smoke.color = Color("cbb48a")
		_smoke.emitting = velocity.length() > 120.0
	elif surface == Track.Surface.ROAD:
		_smoke.color = Color("dcd6cc")
		_smoke.emitting = is_sliding()
	else:
		_smoke.emitting = false


func _create_smoke() -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.emitting = false
	smoke.amount = 40
	smoke.lifetime = 0.7
	smoke.local_coords = false
	smoke.position = Vector2(-24, 0)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(3, 14)
	smoke.direction = Vector2(-1, 0)
	smoke.spread = 50.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 70.0
	smoke.damping_min = 40.0
	smoke.damping_max = 60.0
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 11.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	smoke.show_behind_parent = true
	return smoke


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
