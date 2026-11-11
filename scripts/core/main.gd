extends Control
## Startbildschirm.

const TEST_DRIVE_SCENE := "res://scenes/race/test_drive.tscn"

@onready var _title: Label = %Title
@onready var _version: Label = %Version
@onready var _start: Button = %StartButton


func _ready() -> void:
	_title.text = GameConfig.GAME_TITLE
	_version.text = "Version %s" % GameConfig.get_version()
	_start.pressed.connect(_on_start_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(TEST_DRIVE_SCENE)
