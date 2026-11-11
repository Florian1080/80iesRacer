extends Node
## Globale Spieleinstellungen, die überall im Spiel verfügbar sind.
## Wird als Autoload "GameConfig" geladen und legt beim Start die Steuerung an.

const GAME_TITLE := "80iesRacer"
const LAPS_PER_RACE := 3
const AI_OPPONENTS := 3

## Input-Actions und ihre Tastatur-Belegung. Touch-Tasten lösen dieselben Actions aus.
const INPUT_ACTIONS := {
	"steer_left": [KEY_LEFT, KEY_A],
	"steer_right": [KEY_RIGHT, KEY_D],
	"brake": [KEY_SPACE, KEY_DOWN, KEY_S],
	"use_item": [KEY_E, KEY_SHIFT],
}


func _ready() -> void:
	_register_input_actions()


func get_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _register_input_actions() -> void:
	for action: String in INPUT_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in INPUT_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
