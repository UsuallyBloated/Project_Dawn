# gdext_net

Rust GDExtension that wraps a [renet](https://crates.io/crates/renet) 2.0
client + Secure-mode `netcode.io` transport, exposing a `NetClient` class
to GDScript. The `Net` autoload (`autoloads/net.gd`) extends this class.

Source lives in the **server repo** at `F:/Projects/server/crates/gdext-net/`
so it can share the wire-format crate (`protocol`) and the renet pin with
the server side. The compiled artifact is copied into this directory.

## Build

The `.dll` is **not committed** — it's a build artifact, regenerated
from source on every clone.

```powershell
# From this directory:
.\build.ps1
```

This shells out to `cargo build -p gdext-net --release` in the server repo
and copies the resulting `gdext_net.dll` into this folder. Build takes ~3
minutes the first time (gdext is large) and ~30 seconds on incremental
rebuilds.

Manual equivalent:

```powershell
cd F:/Projects/server
cargo build -p gdext-net --release
Copy-Item target/release/gdext_net.dll F:/Projects/Project_Dawn/addons/gdext_net/
```

## Why a GDExtension?

renet is a UDP protocol with a `netcode.io`-style cryptographic handshake.
None of Godot's built-in net stacks (WebSocket, ENet) speak it. The Rust
crate is the canonical client implementation, so we use it directly via
[gdext](https://github.com/godot-rust/gdext) bindings. Sharing the
`protocol` crate verbatim eliminates an entire class of "GDScript and
server bincode disagreed about a field order" bugs.

## Public surface (GDScript-callable)

`NetClient extends Node` — see `autoloads/net.gd` for the wrapper that
adds state-machine glue and high-level signals.

| Method | Purpose |
|---|---|
| `connect_to_server(token_bytes: PackedByteArray, world_endpoint: String) -> bool` | Decode a renet `ConnectToken` and start the transport handshake. |
| `disconnect_now()` | Tear down the transport. |
| `is_world_connected() -> bool` | True only when handshake completed. |
| `poll(delta: float)` | Pump renet for one frame. Call from `_process(delta)`. |
| `send_app_connect(session_token: PackedByteArray, char_id: int, client_version: String) -> bool` | App-layer Connect on system channel. |
| `send_disconnect() -> bool` | Clean app-layer disconnect. |
| `send_heartbeat() -> bool` | App-layer keepalive. |
| `send_move(sequence: int, direction: Vector3, jumping: bool) -> bool` | Movement intent on unreliable channel. |

| Signal | Fired on |
|---|---|
| `transport_connected()` | renet handshake complete; safe to send `Connect`. |
| `transport_disconnected(reason: String)` | Transport-level drop or timeout. |
| `connect_ok(player_id: int)` | Server accepted the app-layer Connect. |
| `kicked(reason: String, code: String)` | Server sent a `Kick`. |
| `position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int)` | Server position broadcast. |
| `heartbeat()` | Server-initiated app heartbeat. |
| `unhandled_server_message(channel: int, bytes: PackedByteArray)` | Catch-all for variants slice 1 doesn't decode yet. |

## Versioning

- `gdext` pinned at `=0.5.2` (Cargo.toml in the server repo).
- `renet` / `renet_netcode` pinned at `=2.0.0` (workspace deps, shared with server).
- Channel layout, `available_bytes_per_tick`, and `WORLD_PROTOCOL_ID` come
  from the shared `protocol` crate — bumped together with the server.

## Cross-platform

Slice 1 ships Windows-only. To add Linux/Mac:

1. Cross-build `gdext-net` for the target.
2. Copy the resulting `libgdext_net.so` / `libgdext_net.dylib` here.
3. Add the matching `linux.*` / `macos.*` lines to `gdext_net.gdextension`.
