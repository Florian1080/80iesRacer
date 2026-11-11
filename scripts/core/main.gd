extends Control
## Startbildschirm. Platzhalter, bis das Rennen gebaut ist.

@onready var _title: Label = %Title
@onready var _version: Label = %Version


func _ready() -> void:
	_title.text = GameConfig.GAME_TITLE
	_version.text = "Version %s" % GameConfig.get_version()
