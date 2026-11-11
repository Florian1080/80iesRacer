class_name FollowCamera
extends Camera2D
## Kamera, die einem Auto folgt und in Fahrtrichtung vorausschaut.
## Bei hohem Tempo zoomt sie leicht heraus, damit man mehr Strecke sieht.
## Bewegt sich im Physik-Takt, die Physik-Interpolation sorgt für flüssige Bilder.

@export var look_ahead := 0.32
@export var follow_speed := 5.0
@export var zoom_slow := 1.0
@export var zoom_fast := 0.78

var target: CharacterBody2D


func _ready() -> void:
	make_current()


func snap_to_target() -> void:
	if target:
		global_position = target.global_position
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var goal: Vector2 = target.global_position + target.velocity * look_ahead
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))

	var top_speed: float = target.get("max_speed") if "max_speed" in target else 900.0
	var speed_ratio := clampf(target.velocity.length() / top_speed, 0.0, 1.0)
	var z := lerpf(zoom_slow, zoom_fast, speed_ratio)
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-2.0 * delta))
