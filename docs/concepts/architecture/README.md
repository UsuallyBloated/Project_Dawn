# Architecture

Server architecture, wire protocol, database schema, and the client-side
migration path live in the companion server repository:

- **`Projects/server/docs/server_design.md`** (absolute)
- From this file: `../../../../server/docs/server_design.md`

Read it before making changes that affect:

- Networking, RPCs, or anything sent over the wire
- Save persistence (`autoloads/save_manager.gd`) — server-authoritative once online
- Authoritative gameplay state on `PlayerStats`, `Inventory`, `Equipment`,
  `QuestManager`, the passive skill trackers, `Combat`, `Loot`
- Lobby flow, character creation, login

Local-only client concerns (HUD layout, UI scaling, input gating, debug panel,
cosmetic effects) don't need to consult the server design.
