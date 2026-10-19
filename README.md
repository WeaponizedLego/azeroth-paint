# azeroth-paint

A World of Warcraft: Forever addon for quick doodles.

- **Screen glass** – a whiteboard over the game for prices, craft counts and reminders. Hold a key and draw or type notes, then shake the mouse to wipe it like an Etch A Sketch. Private to you, saved per character.
- **Map doodles** – draw on the world map and your party/raid sees it on the same spot when they view the same map. Closing your map wipes the map doodles you see.

## Install

Copy (or symlink) the `AzerothPaint` folder into the Forever client's `Interface/AddOns` folder:

```bash
ln -s "$PWD/AzerothPaint" "/Applications/World of Warcraft/_forever_/Interface/AddOns/AzerothPaint"
```

The client folder name may differ (`_forever_`, `_camelot_`, …) – use whichever one the Forever install created. If the addon shows as out of date, update `## Interface` in `AzerothPaint.toc` to the number from `/dump select(4, GetBuildInfo())`.

## Use

First bind a key under Key Bindings → AddOns → **Hold to draw on screen**. The screen only takes the mouse while that key is held.

| Action | How |
| --- | --- |
| Draw on screen | Hold the key and left-drag |
| Write a note | Hold the key and right-click, release the key, type, press Enter |
| Edit a note | Hold the key, right-click the note, release, type. Empty it to delete |
| Erase everything | Hold the key and shake the mouse side to side (no button pressed) |
| Erase from chat | `/paint clear` |
| Draw on the map | Click **Draw** in the bottom-left of the world map, then left-drag |
| Hide others' map drawings | Untick **Show group drawings** next to the Draw button |

## Limits

- Map doodles are sent with addon messages. They only reach group members who also run the addon, and Midnight/Forever restrictions block addon messages in some instanced and combat situations.
- Long strokes are throttled by the server (10 messages burst, then 1/sec), so big drawings can take a few seconds to arrive.
- Each sender is capped at 1500 points per map opening, so one person can't flood your map.
- Drawing on the 3D ground itself is not possible with the addon API.
