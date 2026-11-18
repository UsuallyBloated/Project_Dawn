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

### I6. A shot costs an arrow, and the server takes it
Ammunition goes in the ammo slot and nowhere else, nothing else goes there, and every bow
shot takes one arrow from it on the server, hit or miss, as a ledger row; with the slot empty
there is no shot. Why: a bow that fires for nothing has no cost, and a client that decided
its own ammo could shoot forever.
Held by: `a_bow_shot_takes_an_arrow_and_an_empty_quiver_fires_nothing`,
`the_quiver_gives_one_arrow_a_shot_until_empty`, `ammo_fits_the_ammo_slot_alone`,
`probe_ammo_slot.gd`

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
`a_chat_line_cut_inside_a_multibyte_char_does_not_crash_the_server`,
`a_flung_gm_lands_for_the_formulas_damage`

### A4. Reach and rate are the server's
Everything aimed at something (a spell, an inspect, a vendor, a loot) checks the distance on
the server, and things a client could repeat are limited per tick or per swing. Refusals
for far, offline and never-existed targets read the same. Why: naming an id from across the
world, or a datagram with fifty casts in it.
Held by: `heals_reach_30_m_and_not_past_it`, `pvp_nuke_refuses_out_of_range`, `inspect_player_refuses_beyond_range`,
`one_cast_per_caster_per_tick`, `a_burst_of_drops_in_one_tick_is_capped`

### A5. The ground and the sight are the server's
Where everything stands is the server's own ground (the client's terrain, compiled in), a
player's step up a slope is what the client's body could take and no step climbs a face past
the limit however short or however slanted (a diagonal or a zigzag up a cliff), a mob or pet
climbs nothing a player cannot and gives up on a target above a face, taking no damage while
it is held there or walks home (it cannot answer), and nothing targeted
reaches through the terrain: a spell, an arrow, an AoE's reach or an idle mob's notice. A fall is the server's too: it begins where
the ground drops away under a step, lands on the server's ground and costs what the height
says, and neither a Quit nor a port mid-air gets out of the landing. And the walkable
world is closed: the mountains outside its edge are a face at their foot all the way
round, so nobody walks out of the zone or off the plate. Why: a modified client
that sent its own height, walked up a cliff, cast from behind a hill, or never reported a
fall.
Held by: `micro_steps_climb_no_face`, `a_step_up_a_face_too_steep_to_climb_is_refused`,
`a_nuke_and_a_heal_across_a_ridge_are_refused_and_land_from_the_crest`,
`a_bow_needs_sight_of_its_target`, `an_idle_mob_behind_a_ridge_notices_a_player_only_at_the_crest`,
`a_mob_on_a_rise_closes_to_melee_with_a_player_at_its_foot`,
`a_walk_off_a_ten_metre_ledge_costs_a_fifth_of_max_hp`,
`a_quit_in_mid_air_still_takes_the_landing`,
`a_fall_to_zero_leaves_the_corpse_where_the_body_landed`,
`a_diagonal_climbs_no_face`, `nobody_walks_out_of_the_zone`,
`a_gap_in_the_mountains_is_a_way_out`,
`a_mob_at_a_face_stops_and_gives_up`,
`a_mob_at_a_face_gives_up_and_walks_home`,
`a_mob_held_below_a_face_evades_until_it_is_home`,
`a_mob_below_the_plateau_ramp_gives_up_on_a_player_on_its_edge`

### A6. What stands on the ground stops a body and a line of sight, and it is the server's
The zone's trees, rocks, walls and set pieces are solids the server holds (the client's
scenery, baked and compiled in). The server takes every step itself and turns it aside or
stops it at a solid, so a client that ignores its own obstacles is held at the server's. No
step crosses a solid, however fast or however squeezed. Everything put somewhere without
walking there (a login, a respawn, a port, a resurrection summon, a spawn, a landing) stands
at a point clear of every solid that a body can also walk away from, and a pet is summoned
on its owner's side of a wall. Nothing targeted reaches through a solid: every sight check
asks the ground, and the ground carries what stands on it. And nothing in the zone closes
ground a body could be put on and never leave. Why: a modified client that walked through
a wall, a cast or a pet sent through one, a body or a mob put where nothing can reach it.
Held by: `a_direction_held_through_a_house_ends_at_its_face`,
`a_body_slides_round_a_trunk_and_carries_on`,
`the_largest_step_crosses_nothing`,
`a_body_squeezed_between_solids_is_never_squirted_across_one`,
`random_walks_never_end_inside_anything`,
`a_body_is_never_put_in_a_gap_it_cannot_leave`,
`a_login_inside_a_solid_lands_beside_it`,
`a_spawn_under_scenery_stands_beside_it`,
`a_pet_summoned_at_a_wall_appears_on_its_owners_side`,
`a_spell_through_a_house_is_refused_and_lands_round_the_corner`,
`a_line_through_a_solid_is_blocked_and_one_over_it_is_not`,
`the_four_gates_are_open_and_the_wall_beside_them_is_not`,
`nothing_in_the_zone_closes_a_pocket_a_body_could_be_put_in`,
`a_file_round_trips_and_a_damaged_one_is_refused`,
`a_body_moved_out_of_a_solid_is_stood_on_a_floor`,
`a_line_from_inside_a_crown_sees_out_and_other_solids_still_block`

### D1. Dev tools are gated and audited, or refused
A dev command runs only for a GM account or a dev-mode server, and only if its audit row
was queued; one that cannot be recorded is refused. A refused attempt writes nothing and
says nothing. Why: the tools are deliberate and essential for testing; this is what keeps
them from being anyone else's.
Held by: `is_gm_gates_dev_commands`, `gm_commands_are_audited_only_when_authorized`,
`gm_command_burst_is_recorded_whole`, `death_broadcast_is_a_dev_command`,
`a_flung_gm_lands_for_the_formulas_damage`

## Creatures

### C1. A wanderer never chooses ground inside the town
The wandering animals of the roam table pick where they appear and where they walk, and none
of it is ever within 150 m of the town's middle: not a spawn spot, not the end of a leg, not a
leg's line, not a pack follower's line to its leader, and never the home a fight or a charm
leaves it with. A chase can still bring one in, as it can a camp mob, and it walks home after.
Why: an aggressive animal that settled among the vendors would kill everyone who logs in there.
Held by: `a_wanderer_never_chooses_ground_inside_the_town_ring`,
`a_follower_keeps_to_its_leader_and_never_cuts_through_the_town`,
`a_wanderers_home_is_where_its_fight_began_and_never_where_a_charm_ended`,
`a_line_through_the_town_is_refused_and_one_round_it_is_not`

### C2. A wanderer stays on ground it can walk back from
Wanderers appear and walk only on the roam map: floors reachable from the town without
crossing a face, in either direction. A mob never falls and the slope rule refuses only a step
that rises onto a face, so without this an animal would walk down a cliff into a pocket it can
never leave, or out onto a perch. Why: a mob somewhere no path leads is a mob nobody can reach
or one that can be hit from where it cannot answer.
Held by: `a_roam_step_onto_a_face_is_refused_going_down_as_well_as_up`,
`a_pit_reachable_only_downhill_is_not_roamable`,
`a_face_is_never_roamable_and_the_ground_behind_it_is_not_reached`,
`an_idle_wanderer_off_the_map_steps_onto_its_home`

### C3. One pet at a time, and a charm takes nothing from anyone
A new pet replaces the old one: a summoned pet is dismissed, a charmed one is handed back as
the mob it was, hostile to its charmer, with its HP and with the record of who had hurt it. A
charmed pet that has died stays a body. A charmed mob holds its place in its camp or its pack
for the charm's life. Why: each is a way a charm paid for nothing. A dead pet handed back
dropped its loot with no fight; a charm that wiped the damage record took the kill from
whoever did the work; a slot that refilled during a charm held one mob more after it, every
cast.
Held by: `a_second_charm_drops_the_first_which_turns_on_the_caster`,
`a_new_pet_replaces_the_old_and_a_charmed_one_comes_back_angry`,
`a_charmed_member_holds_its_head_so_a_charm_never_overfills_a_slot`,
`a_charmed_pet_that_dies_as_its_charm_runs_out_is_not_handed_back`

### C4. A respawn is never handed to whoever waits for it
A wanderer comes back at a fresh spot in its region, at least 60 m from every player's body,
and a pack short of members is refilled without waiting for its last one to die. Why: a spawn
that appears beside the player who killed it is a farm, one that appears on a fight is a
death nobody earned, and a pack that waits for its last member can be kept out of the world
by anyone who leaves one alive.
Held by: `a_respawn_never_lands_beside_a_player`,
`a_wanderer_appears_in_its_region_clear_of_every_body`,
`a_pack_is_refilled_beside_its_leader_while_one_member_lives`

### C5. A mob is as wide as a player, and one that cannot reach its target takes no damage
A mob or a pet is stopped by the same solids as a player, at the same body radius, so there
is nowhere a player fits and a mob does not. A mob held at a wall tries to walk round it;
while its steps are not going as aimed, past a second's grace, it takes no damage, and after
eight seconds with no way found it gives up on that target (the rule for a mob below a
cliff, A5). A tree on the way costs it a step aside and never makes it immune. Why: a wall
with a gap too narrow for a mob, or a spot a mob pushes at forever, is a place to kill from
in safety.
Held by: `a_mob_walks_round_a_house_to_its_target`,
`a_mob_rounds_a_long_wall_to_a_target_close_behind_it`,
`a_mob_slides_round_a_trunk_and_never_evades`,
`a_mob_glancing_along_a_wall_is_not_held`,
`a_clean_second_ends_the_stuck_clock`,
`a_mob_in_a_dead_end_evades_and_gives_up`

## Client and server agree

### L1. A number both sides hold has a check
Spells, items, vendor stock, skills, characters, factions, shared constants, the terrain and the wire
layer each live on both sides, and each pair has a check that exits 1 when they differ.
Why: the client draws what the server decides; when they disagree, the player sees one
thing and gets another.
Held by: `check_spell_lockstep.gd`, `check_item_lockstep.gd`, `check_vendor_lockstep.gd`,
`check_active_skill_lockstep.gd`, `check_character_lockstep.gd`, `check_constant_lockstep.gd`,
`check_discipline_lockstep.gd`, `check_faction_lockstep.gd`, `check_skill_table_lockstep.gd`,
`check_wire_layer.gd`, `check_terrain_lockstep.gd`, `check_terrain_sight.gd`,
`check_obstacle_lockstep.gd`, `check_obstacle_rule.gd`

### L2. What stops a body is one set of data and one rule, the same on both sides
The zone's obstacles are exported once from the scenery and held as the same bytes by the
client and the server; the rule that turns a step aside at them is written once on each
side, and the client's copy gives the server's answers. What stops the client's body is that
rule on that data and nothing else: no scenery node is a physics body the player's body
reads (the one set of physics shapes made from the scenery, the camera's blockers, is on a
layer of its own). Why: the client sends a direction and the server moves the player; a
wall that stopped the client's body and not the server's, or stood in a different place,
would leave the player drawn in one place and standing in another, and the next correction
would pull them through it.
Held by: `check_obstacle_lockstep.gd`, `check_obstacle_rule.gd`, `check_zone_scenery.gd`,
`the_rule_fixtures_are_current`

### L3. The world is its map, the right way round
The zone is authored on a map (north up, east right) and reaches the world through one
mapping (`ZoneLayout.to_world`: north is the world's -Z, east its +X). Facing north, east is
on the right; `/sense` names the directions the map names; the client's set pieces stand at
the server's camps.
Why: Godot is right-handed, so a world with north at +Z is the map's mirror image (the zone
stood that way until 2026-11-14). A half-mirrored pair, the client's ground one way and the
server's camps the other, puts every mob where the zone shows nothing.
Held by: `check_compass.gd`
