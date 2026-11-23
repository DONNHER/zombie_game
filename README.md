# Zombie Apocalypse: Ranger Outbreak (Godot 4.7 GDScript Edition)

2D top-down blocky zombie survival game built 100% with **Godot 4.7 `.tscn` UI scenes and GDScript (`.gd`)**, persistent on-device offline saves (`user://`), and a **self-hosted Nakama + PostgreSQL Docker backend** for online co-op multiplayer, leaderboards, friends, and global chat.

## Features Implemented
- **5 Story Stages + Tutorial + Endless Portal Mode**:
  - Stages: *Abandoned Village*, *Dark Forest*, *Destroyed City*, *Research Facility*, *The Deadlands*.
  - Escalating waves, boss fights (*Chief Rotjaw*, *Blightfang*, *Iron Bastion*, *Subject X-09*, *Malakor Prime*), Day/Night dynamic lighting, and 10-wave Endless Dimensional Portals.
- **1–3 Star Ratings & Star-Gated Level Unlocks (R1–R5)**:
  - Each stage calculates 1–3 stars based on elapsed clear time and damage taken.
  - Higher stages require clearing previous stages AND meeting cumulative Star milestones.
  - Progress and settings persist to local device storage (`user://save_data.json`, `user://settings.cfg`) across app restarts.
- **Realistic Multi-Room Bunkers & Wall-Phasing Combat**:
  - Brick perimeter masonry with 84px doorways, interior partitions, wooden plank flooring, furniture, and wave-locked Sector Barriers.
  - Ground walkers and bullets respect bunker walls; **Phantom Spirits** and **Blight Wings** phase straight through walls.
  - **Scout Maya Overwatch Rule**: Scout Maya defends from her elevated Watchtower (`Lv. 1–5`) and **cannot revive downed players**. Only real teammates in Online Co-op can revive downed squadmates at the Revive Station or via Squad Defib.
- **Manga Story Cutscenes**:
  - Multi-panel animated comic briefings before deployment with SFX captions, speech bubbles, tactical intel, and Skip Intro.
- **Offline Airplane Mode & Online Nakama Co-op (R6–R8)**:
  - Dedicated **Offline / Online** mode toggle on the Command Hub.
  - Graceful server-unreachable error banners with instant one-tap **Switch to Offline Mode** fallback when Wi-Fi or Nakama is offline.
- **Mobile Landscape Touch Controls & Accessibility (R9–R10)**:
  - Locked `sensor_landscape` orientation, left virtual thumbstick, Auto-Aim Hold-to-Fire / Reload / Cycle Target buttons.
  - Settings for Mute, Master Volume, Device Vibration, Language (`English`, `Español`, `Filipino`), Color-Blind Daltonization shader (`Normal`, `Deuteranopia`, `Protanopia`, `Tritanopia`), and Text Size (`Normal`, `Large`, `Extra Large`).

---

## Project Structure
- `project.godot` — Godot 4.7 configuration (`Mobile` renderer, `sensor_landscape`, input actions, 6 Autoloads)
- `export_presets.cfg` — Android APK export template
- `scripts/autoload/` — `game_data.gd`, `game_rules.gd`, `save_manager.gd`, `audio_manager.gd`, `accessibility_manager.gd`, `network_manager.gd`
- `scenes/main.tscn` & `scripts/main.gd` — Root orchestrator
- `scenes/game/game_arena.tscn` & `scripts/game/game_arena.gd` — 2D arena, combat engine, AI, bunkers, and renderer
- `scenes/ui/*.tscn` & `scripts/ui/*.gd` — Splash, Command Hub, Armory, Manga Cutscenes, HUD, Touch Controls, Bunker Shop, Pause, Result, Social, Leaderboard, Online Room, Auth, Settings
- `shaders/colorblind.gdshader` — Full-screen Daltonization post-process filter
- `docker-compose.yml`, `nakama/data/local.yml`, `nakama/data/modules/index.js` — Self-hosted Nakama 3.37 + PostgreSQL 16 server

---

## Running Locally

### 1. Start the Nakama Server (Optional for Online Co-op)
```bash
cp .env.example .env
docker compose up -d
```
- Nakama API / WebSocket runs on port `7350` (`http://127.0.0.1:7350`).
- Nakama Admin Console runs on port `7351` (`admin` / `password` by default in `local.yml`).
- When playing on two phones over the same Wi-Fi LAN, enter your host machine's LAN IP (e.g., `http://192.168.1.50:7350`) inside the Auth modal's Server URL input.
- *(Optional)* You can also install the official **Heroic Labs Nakama** plugin (`nakama-godot`) from the Godot AssetLib; `NetworkManager` works out of the box via built-in Godot `HTTPRequest` and `WebSocketPeer` with no external plugin dependencies required.

### 2. Open & Run in Godot 4.7
1. Open **Godot Engine 4.7** -> Click **Import** -> Select `project.godot`.
2. Press **Play (`F5`)** to run the game.
3. For Android APK export: open **Project -> Export -> Android**, configure your debug/release keystore in Editor Settings, and export the `.apk`.
