# UI Asset Attributions

Rebound of Ruins · central record of externally sourced interface assets · verified 15 November 2026

Each icon's author and licence were read on its own page on game-icons.net. The site's About page confirms the CC BY 3.0 terms and the credit format.

## Icons — game-icons.net

| Icon | Used for | Creator | Original page | Project file |
|---|---|---|---|---|
| Broadsword | Sword (HUD weapon chip, touch weapon button, Attack button) | Lorc | https://game-icons.net/1x1/lorc/broadsword.html | `ui/icons/broadsword.svg` |
| Pocket bow | Bow (HUD weapon chip, touch weapon button, Shoot button) | Lorc | https://game-icons.net/1x1/lorc/pocket-bow.html | `ui/icons/pocket-bow.svg` |
| Flaming arrow | Fire Arrows (HUD weapon chip, touch weapon button, Shoot button) | Lorc | https://game-icons.net/1x1/lorc/flaming-arrow.html | `ui/icons/flaming-arrow.svg` |
| Crystal growth | Token counter (replaces `gem.png`, whose source could not be verified) | Lorc | https://game-icons.net/1x1/lorc/crystal-growth.html | `ui/icons/crystal-growth.svg` |

| Field | Details |
|---|---|
| Exact licence | Creative Commons Attribution 3.0 Unported (CC BY 3.0) |
| Licence URL | https://creativecommons.org/licenses/by/3.0/ |
| Attribution required | **Yes.** Suggested by the site: "Icons made by Lorc. Available on https://game-icons.net" |
| Modification permitted | Yes |
| Commercial use permitted | Yes |
| Download | White-on-transparent SVG from the site's standard path `https://game-icons.net/icons/ffffff/transparent/1x1/lorc/<name>.svg` |
| Modifications made | Files are unmodified. Imported at 0.25 scale (128 px). Tinted in Godot with `modulate` (gold for weapons, cyan for the token crystal). |

## Not externally sourced

All panels, buttons, chips, the joystick, progress bars and the enemy health-bar rounding are drawn with Godot theme styles (`ui_theme.tres`) and a small shader (`vfx/health_bar.gdshader`). No UI artwork was generated.

The `gem.png` file is still in the project folder but is no longer used by the game.
