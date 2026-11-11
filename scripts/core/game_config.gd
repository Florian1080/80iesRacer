extends Node
## Globale Spieleinstellungen, die überall im Spiel verfügbar sind.
## Wird als Autoload "GameConfig" geladen.

const GAME_TITLE := "80iesRacer"
const LAPS_PER_RACE := 3
const AI_OPPONENTS := 3


func get_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
