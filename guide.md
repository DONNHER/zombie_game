# Environment Variables & Deployment Guide (`guide.md`)

This guide documents every environment variable used by **Zombie Apocalypse: Ranger Outbreak (Godot 4.7 + Nakama Docker)** so both developers and coding agents know where values are configured, how they are consumed, and how to customize them safely.

---

## 1. Quick Reference Table

Copy `.env.example` to `.env` before starting Docker or inputting custom credentials:

```bash
cp .env.example .env
```

| Variable | Default Value | Used By | Purpose |
| :--- | :--- | :--- | :--- |
| `POSTGRES_DB` | `nakama` | `docker-compose.yml` (`postgres`, `nakama`) | PostgreSQL database name storing Nakama accounts, storage saves, friends, and leaderboards. |
| `POSTGRES_USER` | `postgres` | `docker-compose.yml` (`postgres`, `nakama`) | PostgreSQL username for database migration and connection. |
| `POSTGRES_PASSWORD` | `localdb` | `docker-compose.yml` (`postgres`, `nakama`) | PostgreSQL password. Change this before deploying to a public server. |
| `NAKAMA_SERVER_KEY` | `defaultkey` | `docker-compose.yml` (`nakama`) & `scripts/autoload/network_manager.gd` | Shared socket/API server key sent in `Basic <base64(key:)>` headers during authentication. **Must match between the Nakama server and Godot client.** |
| `NAKAMA_SERVER_URL` | `http://127.0.0.1:7350` | `scripts/autoload/network_manager.gd` | Optional OS environment override for the Nakama HTTP/WebSocket endpoint. If unset, Godot falls back to the editable **Nakama Server URL** saved in `user://settings.cfg` (editable in the in-game Auth Modal). |
| `NAKAMA_CONSOLE_USER` | `admin` | `docker-compose.yml` (`nakama`) | Username for the Nakama Admin Web Console (`http://127.0.0.1:7351`). |
| `NAKAMA_CONSOLE_PASSWORD` | `password` | `docker-compose.yml` (`nakama`) | Password for the Nakama Admin Web Console. Change before public deployment. |

---

## 2. How Each File Uses These Variables

### Backend (`docker-compose.yml` & `nakama/data/local.yml`)
- `docker-compose.yml` reads `.env` automatically and injects:
  - PostgreSQL credentials into the `postgres:16-alpine` container and `--database.address`.
  - `--socket.server_key ${NAKAMA_SERVER_KEY:-defaultkey}`
  - `--console.username ${NAKAMA_CONSOLE_USER:-admin}`
  - `--console.password ${NAKAMA_CONSOLE_PASSWORD:-password}`
- These flags override the fallback defaults inside `nakama/data/local.yml`, while preserving the JS runtime entrypoint `nakama/data/modules/index.js`.

### Godot 4.7 Client (`scripts/autoload/network_manager.gd`)
- `NetworkManager._ready()` checks `OS.get_environment("NAKAMA_SERVER_KEY")` (defaulting to `"defaultkey"`) and `OS.get_environment("NAKAMA_SERVER_URL")`.
- On **Android / iOS phones** where OS shell environment variables are not set, players can change the server endpoint directly inside the **Auth Modal -> Nakama Server URL** field, which saves persistently via `SaveManager.write_settings({"server_url": ...})`.
- **Important for Phone / Two-Device Testing**: `127.0.0.1` points to the phone itself. For two phones on the same Wi-Fi network, set the **Nakama Server URL** (or `NAKAMA_SERVER_URL`) to your host PC's LAN IP, for example:
  ```text
  http://192.168.1.50:7350
  ```
- **If You Change `NAKAMA_SERVER_KEY`**:
  - Update `.env` on the server (`NAKAMA_SERVER_KEY=<your-new-key>`) and restart `docker compose up -d`.
  - Either export `NAKAMA_SERVER_KEY=<your-new-key>` before launching Godot on desktop, **or** update `DEFAULT_SERVER_KEY` in `scripts/autoload/network_manager.gd` before exporting the Android `.apk` so mobile builds use the matching key.

---

## 3. Running Offline vs. Online Mode
- **Offline Mode (Airplane Safe)**: Requires **zero** environment variables and no Docker server. All progression, 1–3 stage stars, unlocks, and settings persist in `user://save_data.json` and `user://settings.cfg`.
- **Online Co-op Mode**: Requires the Nakama Docker stack running:
  ```bash
  docker compose up -d
  ```
  - API & WebSocket port: `7350`
  - Nakama Console port: `7351`
  - gRPC port: `7349`
  - If Wi-Fi is off or Nakama is stopped, the client displays a clear unreachable-server banner with a one-tap **Play Offline** fallback.

---

## 4. Instructions for Future Coding Agents
1. **Never commit secrets** into `.env.example`, `project.godot`, `export_presets.cfg`, or GDScript files. Keep secrets in `.env` (already ignored via `.gitignore`).
2. Keep `NAKAMA_SERVER_KEY` defaults synchronized between `.env.example`, `nakama/data/local.yml`, and `DEFAULT_SERVER_KEY` in `scripts/autoload/network_manager.gd`.
3. Preserve all Nakama RPC names in `nakama/data/modules/index.js`:
   - `create_coop_room`
   - `list_public_rooms`
   - `find_room_by_code`
   - `commit_match_result`
   and match handler `"coop_relay"`.
4. Do not re-add Node/TypeScript/Vite frontend files—this project is strictly **Godot 4.7 GDScript + `.tscn` UI scenes** (`preview_server.mjs` and `package.json` exist solely for AI Studio's Port 3000 container healthcheck).

---

## 5. Two-Phone Wi-Fi LAN Multiplayer Guide (Laptop Nakama + Android APK)

1. **Start Nakama on your Laptop**:
   ```bash
   cp .env.example .env
   docker compose up -d
   ```
   Find your laptop's local Wi-Fi IPv4 address (e.g., `192.168.1.50` via `ipconfig` on Windows or `ifconfig` / `ip a` on macOS/Linux) and allow TCP port **`7350`** through your laptop's firewall.
2. **Allow HTTP on Android 9+ (`usesCleartextTraffic`)**:
   - In **Godot 4.7 -> Project -> Export -> Android**, enable **Gradle Build -> Use Gradle Build** (install Android Build Template via **Project -> Install Android Build Template**).
   - Open `android/build/src/main/AndroidManifest.xml` and add `android:usesCleartextTraffic="true"` inside the `<application ...>` tag so Android allows `http://<laptop-ip>:7350` and `ws://<laptop-ip>:7350` over local Wi-Fi.
3. **Export & Install the APK**:
   - Export `build/RangerOutbreak.apk` and install it on both Android phones connected to the **same Wi-Fi** as the laptop.
4. **Connect & Play**:
   - On **both phones**, switch from Offline to **Online Co-op (Nakama)** -> open the Auth modal -> set **Nakama Server URL** to `http://<your-laptop-ip>:7350` (for example `http://192.168.1.50:7350`) -> Sign In or tap **Online Guest**.
   - Use a different Nakama account on each client. This also applies when opening the game twice on one laptop.
   - **Phone 1** creates a Public/Private room and shares the **4-character room code** -> **Phone 2** joins via **Join by Code** or **Quick Match** -> the host starts the mission in the room.
   - Each player reviews the introduction and presses **Deploy Squad**. The arena starts after every squad member has deployed.
   - Each client controls its own selected Ranger or Medic. The host simulates the shared enemies, waves, pickups, combat, and result, then sends that world state to the squad. If the host leaves during a match, the other clients return to the lobby.
