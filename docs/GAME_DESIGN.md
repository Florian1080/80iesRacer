# 80iesRacer – Spiel-Design

Arbeitstitel. Dieses Dokument hält fest, was wir gemeinsam geplant haben.
Änderungen am Plan werden hier nachgetragen.

## Idee

Ein Top-Down-Rennspiel für das Handy, inspiriert von Rock n' Roll Racing (SNES).
Das Spiel spielt in den 1980er Jahren: Autos, Strecken und Gegenstände stammen aus dieser Zeit.

## Plattform

- Ziel: native App für iOS und Android, später ggf. Veröffentlichung in den Stores
- Engine: Godot 4.7 (GDScript), Renderer „Compatibility“ für breite Geräteunterstützung
- Zum schnellen Testen: automatische Web-Version über GitHub Pages
- Ausrichtung: **Querformat**

## Look

- **Realistischer Retro-Look**, kein Neon, kein Synthwave
- Tageslicht, echter Asphalt, natürliche, leicht verblasste Farben
  (Ocker, Senfgelb, Rostrot, Dunkelgrün, Beige)
- Leichte Filmkörnung als Retro-Effekt
- Anzeigen (HUD) im Stil alter Tachos und Digitaluhren
- Ansicht: echtes Top-Down von oben, Kamera folgt dem Spielerauto

## Rennen

- 3 Runden gegen 3 Computer-Gegner
- Countdown zum Start, Positionsanzeige, Rundenzähler, Ergebnis am Ende

## Erste Strecke: 80er-Rennstrecke

- Tageslicht
- Reifenstapel, Strohballen, rot-weiße Randsteine
- Zuschauertribünen
- Erfundene Werbebanden (keine echten Marken)

## Autos

Eigene Designs in typischen 80er-Formen, keine echten Marken oder Modelle:

| Auto | Form |
|---|---|
| Sportwagen | flach, keilförmig, Klappscheinwerfer |
| Limousine | kantig, Chromstoßstangen |
| Kombi | lang, kastig, Zierstreifen |
| Pickup | hoch, offene Ladefläche |

## Steuerung

- Automatisches Gas
- Tasten links/rechts zum Lenken (linke Bildschirmseite)
- Bremse und Item-Taste (rechte Bildschirmseite)

## Items (Spezial-Moves)

Zufalls-Boxen auf der Strecke, wie bei Mario Kart.
Verteilung nach Platzierung: Hintere Plätze bekommen eher starke Items, vordere eher defensive.

| Item | Wirkung |
|---|---|
| Mixtape | Turbo-Boost |
| Ghettoblaster | Schallwelle, schubst Autos in der Nähe weg |
| Haarspray | Nebelwolke hinter dem Auto, verlangsamt den Hintermann |
| Diskette | Störsignal, lässt den Vordermann kurz schleudern |

## Bewusst später

- Weitere Strecken (z. B. Kleinstadt-Landstraße)
- Autoauswahl
- Sound und Musik
- Karriere / Fortschritt
- Online-Mehrspieler (Godot High-Level Multiplayer + eigener Server)

## Technische Leitlinien

- Spiellogik (Rennstand, Runden, Items) getrennt von Darstellung und Eingabe,
  damit der Online-Modus später möglich ist
- Eingaben laufen über Godot-Input-Actions, nicht direkt über Touch-Events
