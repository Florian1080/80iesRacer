class_name CarInput
extends RefCounted
## Steuerbefehle für ein Auto in einem Physik-Frame.
## Spieler, Computer-Gegner und später der Online-Modus füllen dieselbe Struktur,
## das Auto selbst weiß nicht, wer es steuert.

## Lenkung von -1 (voll links) bis 1 (voll rechts).
var steer := 0.0
var brake := false
var use_item := false
