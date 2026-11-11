extends Node2D
## Testfahrt: ein Auto allein auf der Strecke, um das Fahrgefühl zu prüfen.

@onready var _track: Track = $Track
@onready var _car: Car = $Car
@onready var _skid_marks: SkidMarks = $SkidMarks
@onready var _camera: FollowCamera = $Camera
@onready var _touch: Control = %TouchControls
@onready var _speed: Label = %Speed
@onready var _hint: Label = %Hint
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	_car.track = _track
	_car.place_at(_track.get_start_transform())
	_skid_marks.track_car(_car)
	_camera.target = _car
	_camera.snap_to_target()
	_touch.visible = DisplayServer.is_touchscreen_available()
	if _touch.visible:
		_hint.text = "Drift: beim Lenken kurz bremsen, dann Lenkung halten"
	else:
		_hint.text = "Pfeiltasten lenken · Leertaste bremst · Drift: beim Lenken kurz bremsen"
	_menu.pressed.connect(_back_to_menu)
	get_tree().create_timer(8.0).timeout.connect(_hint.hide)


func _physics_process(_delta: float) -> void:
	_car.input.steer = Input.get_axis("steer_left", "steer_right")
	_car.input.brake = Input.is_action_pressed("brake")
	_car.input.use_item = Input.is_action_just_pressed("use_item")


func _process(_delta: float) -> void:
	_speed.text = "%d km/h" % roundi(_car.get_speed_kmh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
