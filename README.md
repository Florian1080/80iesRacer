# 80iesRacer

Top-Down-Rennspiel für das Handy im realistischen Retro-Look der 80er Jahre.
Inspiriert von Rock n' Roll Racing: Rennen gegen Computer-Gegner, mit Item-Boxen und Spezial-Moves wie Mixtape-Turbo oder Ghettoblaster-Schallwelle.

> Status: Projekt eingerichtet, Meilenstein 1 (Fahrphysik) als Nächstes.
> Plan und Details: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) · [docs/ROADMAP.md](docs/ROADMAP.md)

## Spielen

- **Am Handy testen:** Nach jedem Update auf `main` wird automatisch eine Web-Version auf GitHub Pages veröffentlicht. Den Link findest du im Repository unter *Settings → Pages* bzw. bei den Actions-Läufen.
- **Am Mac:** Projekt im Godot-Editor öffnen und mit ▶ starten.

## Einrichtung am Mac

1. **Godot 4.7** herunterladen: <https://godotengine.org/download/macos/> (Standard-Version, nicht .NET)
2. Repository klonen, z. B. mit [GitHub Desktop](https://desktop.github.com/) oder im Terminal:
   ```bash
   git clone https://github.com/<dein-benutzername>/80iesRacer.git
   ```
3. In Godot **Importieren** wählen und die Datei `project.godot` öffnen.

## Projektstruktur

```
assets/      Grafiken, Sounds, Schriften
scenes/      Godot-Szenen (.tscn)
  main/      Startbildschirm
  race/      Rennablauf
  cars/      Autos
  track/     Strecken
  items/     Item-Boxen und Effekte
  ui/        HUD und Menüs
scripts/     GDScript-Code
  core/      Globales (Einstellungen, Start)
  game/      Spiellogik (Runden, Platzierung, Items), unabhängig von der Darstellung
  ui/        Oberflächen
docs/        Design-Dokument und Roadmap
```

## Technik

- Godot 4.7, GDScript, Renderer „Compatibility“
- Querformat, Basisauflösung 1280 × 720
- GitHub Actions: prüft den Code (gdlint, gdformat), baut die Web-Version und veröffentlicht sie
- Code-Stil: [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), lokal prüfbar mit `pip install "gdtoolkit==4.*"` und `gdformat scripts`
