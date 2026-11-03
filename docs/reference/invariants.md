# The rules that must always hold

These are the rules this game depends on to stay fair and to lose nothing. Each one names
the tests that enforce it, so it can't go stale without someone noticing.

**How to use it**
- Before you change code in one of these areas, read its rules. If the change would break
  one, stop and say so; don't patch around it.
- When a fix closes a hole, add its rule here, or add its test to a rule that already
  exists, in the same commit as the fix.
- `tools/check_invariants.gd` (run by `tools/check_all.ps1`) fails if a rule names no
  test, or names a test or check that no longer exists. A renamed or deleted test can't
  silently leave a rule unenforced.

**Format.** Each rule is a heading, a sentence saying why it matters, and a `Held by:` line.
Names ending in `.gd` are client checks in `tools/`; every other name is a Rust test
function in the server repo. A name followed by `(on <branch>)` lives only on that server
branch for now, and is checked there instead; drop the tag once the branch merges.

Dev tools (the Test Panel, GM commands, `PD_DEV_CMDS`) are deliberate. A rule about what a
player can do does not forbid what a GM is allowed to do; rule D1 says how that stays safe.

---

## Items and coin

### I1. An item or a coin is in exactly one place
Every move between stores (bags, worn gear, the hand, the vaults, the wallet, a corpse,
the ground, another player) commits both sides in one transaction, or neither does. Why:
a crash between two separate writes either loses the item or duplicates it, and the
duplicate is the one that gets exploited quietly (RuneScape's 2020 crash dupe was exactly
this: trade, log out, crash the server).
Held by: `moves_never_create_or_destroy_items`, `save_corpse_strips_the_owner_in_the_same_transaction`,
`trade_commits_atomically_and_pays_both_sides`, `a_dropped_item_leaves_the_droppers_saved_inventory_at_once`,
`a_picked_up_drop_is_saved_on_the_picker_at_once`, `a_death_after_an_unsaved_bank_withdrawal_leaves_the_item_in_one_place`,
`a_traded_bank_withdrawal_leaves_the_givers_saved_vault`

### I2. Every change to what a character holds is in the ledger, and the books balance
A server-made change to items or coin writes its ledger row inside the same transaction
that saves it, so the ledger and the stores agree at every commit, and the daily check
names any account where they don't. Why: it's how a dupe or a loss gets found after the
fact.
Held by: `rows_ride_the_store_transaction_and_the_check_names_a_dupe_and_a_loss`,
`the_ledger_records_a_sale_a_purchase_a_drop_and_a_pickup_and_balances`, `the_ledger_records_the_bank_and_balances`,
`a_trade_writes_both_sides_of_the_ledger_and_balances`, `a_death_and_the_corpse_loot_keep_the_books_balanced`

### I3. An offered item is locked until the trade ends
Nothing in a trade leaves its owner until the one commit, every edit clears both accepts,
and what was offered (and the bag holding it) cannot be moved or swapped meanwhile. Why:
bait-and-switch.
Held by: `trade_edits_clear_accepts_and_locks_hold`, `trade_locks_the_bag_holding_an_offered_item`,
`trade_refuses_self_and_coin_overdraft`

### I4. Prices, stock and rewards come from the server's own tables
What a vendor sells, at what price, and what a quest pays are read from the server's data,
never from the message. Why: a modified client can name any item and any number.
Held by: `a_priced_item_no_merchant_stocks_cannot_be_bought`, `buy_item_rejected_when_no_vendor_in_range`,
`buy_item_rejects_insufficient_coins`, `a_quest_turn_in_saves_its_reward_xp_with_the_completion`

### I5. A NO DROP item never leaves the character holding it
It cannot be dropped on the ground, offered in a trade or put in the account-shared vault,
and the starting kit that carries the tag is worth nothing to a merchant; it can be
destroyed, banked in the character's own vault and looted back off its own corpse. Why:
without it, a new character's free kit is a coin farm (make a character, sell or hand on
its kit, delete it, make another).
Held by: `a_new_character_is_born_dressed_and_the_kit_cannot_leave`, `every_class_can_wear_its_kit`,
`the_starting_kit_comes_back_off_its_owners_corpse`, `no_one_is_born_encumbered`,
`a_fresh_character_holds_only_its_starting_kit`, `probe_no_drop.gd`

## Saving and leaving

### S1. A character's stores are saved together, through one path
Every save (the checkpoint, logout, the retry queue, shutdown) writes all of a character's
stores in one transaction through `persistence::flush_connection`. Things that must land
together, like a death's XP loss and its corpse, or a quest's XP and its completion, share
one transaction. Why: a save of one store alone recreates the I1 window.
Held by: `a_death_saves_its_xp_loss_with_the_corpse`, `a_quest_turn_in_saves_its_reward_xp_with_the_completion`,
`a_death_after_an_unsaved_bank_withdrawal_leaves_the_item_in_one_place`

### S2. A failed load refuses the login; a failed save holds the relogin
A character whose stores could not be read is not let in to play on empty stores, and a
logout save that failed keeps retrying while the account's relogin is refused. Why: the
next save after an empty load wipes the real rows; a relogin before the save lands loads
older state over newer.
Held by: `a_store_that_fails_to_load_refuses_the_login`, `a_failed_logout_save_holds_the_relogin_until_it_lands`,
`a_stop_signal_saves_everyone_and_tells_them`

### S3. Leaving is never a way out
An unclean drop (a crash, a pulled cable, a killed client) leaves the body in the world,
vulnerable, for the linkdead window, and a relogin is refused until it is reaped and saved.
A panic while handling a player's message undoes that player's whole tick and then leaves
the same way. Why: an instant exit is an escape from any fight, and a relogin that boots a
live session is the Lineage II force-off.
Held by: `an_unclean_drop_refuses_relogin_until_the_body_is_reaped`,
`a_panic_undoes_only_its_own_tick_and_drops_the_sender_as_cut`,
`a_panic_puts_the_connection_back_as_it_was_before_the_batch`

### S4. Handling a message touches only the sender
`handlers::handle_message` changes the sender's own connection and sends only to the sender;
everything that reaches another player, a mob or the database happens in the steps after
the drain, from the outcomes it returns. Why: this is what makes S3's undo complete. A
handler that reached any other state would let a panic leave half a change behind.
Held by: `a_panic_puts_the_connection_back_as_it_was_before_the_batch`,
`a_panic_undoes_only_its_own_tick_and_drops_the_sender_as_cut`

## Death

### X1. A death stands
A death writes its corpse, the stripped gear and coin, and the XP loss together, and a
character that left dead comes back dead (once, with no second penalty). Nothing a player
does afterwards (a relog, a crash, a panic) undoes it.
Held by: `a_dead_character_stays_dead_on_relogin_and_pays_once`, `a_dead_character_with_full_pools_is_told_it_is_dead`,
`a_death_saves_its_xp_loss_with_the_corpse`, `a_panic_undoes_only_its_own_tick_and_drops_the_sender_as_cut`

### X2. The dead can only do what the dead may do
A dead player can talk, respawn, accept a resurrection, manage the group and leave;
everything else (loot, inventory, combat, casting) is refused. Why: a dead player looting
their own corpse before respawning voided the corpse run.
Held by: `dead_players_cannot_loot_or_touch_inventory`, `a_dead_caster_casts_nothing`,
`respawn_requires_being_dead`, `dead_group_member_gets_no_xp_share`

## What the client may and may not decide

### A1. The server decides every outcome
Rolls, damage, heals, speed, swing timing, what a class may equip or cast: the server
computes them. A client message is a request, never a result. Why: anything a client
decides, a modified client decides in its own favour (the user's rule of 2026-10-19).
Held by: `the_server_rolls_the_melee_miss`, `a_heal_is_its_listed_number`, `the_server_decides_run_speed`,
`the_swing_rate_limit_reads_the_players_haste`, `cast_spell_rejected_before_cast_time`,
`equipping_is_refused_by_class_and_dual_wield`, `a_spell_not_memorized_is_refused`

### A2. A refusal costs nothing and tells the truth
Every gate runs before anything is spent (mana, stamina, a cooldown, a skill roll), and the
refusal sends the client the server's true state so its view is corrected. Why: a refusal
that costs something is a grief or a free skill-up; one that says nothing leaves the
client's view wrong until a relog.
Held by: `enemy_spell_without_a_target_refunds_and_reports`, `ally_heal_refuses_out_of_range_and_costs_nothing`,
`binding_a_stranger_is_refused_and_costs_nothing`, `a_refusal_reaches_only_the_caster_with_the_true_mana`,
`move_item_empty_source_corrects_client`

### A3. Untrusted input is checked once, at the message
A non-finite number, a negative coin amount or a malformed message is dropped where it
arrives, and range checks are written so that a bad number refuses (keep only when in
range). Random messages and random bytes never crash the handler. Why: NaN passes every
`if dist > range { refuse }` test.
Held by: `nan_move_direction_is_dropped`, `a_players_facing_reaches_the_watcher`,
`a_forged_negative_coin_amount_moves_nothing`,
`random_client_messages_never_panic_the_handler`, `random_bytes_never_panic_the_decoder`,
`a_chat_line_cut_inside_a_multibyte_char_does_not_crash_the_server`

### A4. Reach and rate are the server's
Everything aimed at something (a spell, an inspect, a vendor, a loot) checks the distance on
the server, and things a client could repeat are limited per tick or per swing. Refusals
for far, offline and never-existed targets read the same. Why: naming an id from across the
world, or a datagram with fifty casts in it.
Held by: `heals_reach_30_m_and_not_past_it`, `pvp_nuke_refuses_out_of_range`, `inspect_player_refuses_beyond_range`,
`one_cast_per_caster_per_tick`, `a_burst_of_drops_in_one_tick_is_capped`

### D1. Dev tools are gated and audited, or refused
A dev command runs only for a GM account or a dev-mode server, and only if its audit row
was queued; one that cannot be recorded is refused. A refused attempt writes nothing and
says nothing. Why: the tools are deliberate and essential for testing; this is what keeps
them from being anyone else's.
Held by: `is_gm_gates_dev_commands`, `gm_commands_are_audited_only_when_authorized`,
`gm_command_burst_is_recorded_whole`, `death_broadcast_is_a_dev_command`

## Client and server agree

### L1. A number both sides hold has a check
Spells, items, vendor stock, skills, characters, factions, shared constants and the wire
layer each live on both sides, and each pair has a check that exits 1 when they differ.
Why: the client draws what the server decides; when they disagree, the player sees one
thing and gets another.
Held by: `check_spell_lockstep.gd`, `check_item_lockstep.gd`, `check_vendor_lockstep.gd`,
`check_active_skill_lockstep.gd`, `check_character_lockstep.gd`, `check_constant_lockstep.gd`,
`check_discipline_lockstep.gd`, `check_faction_lockstep.gd`, `check_skill_table_lockstep.gd`,
`check_wire_layer.gd`
