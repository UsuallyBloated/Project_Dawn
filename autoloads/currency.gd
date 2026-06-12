# Currency — four-tier coin math: Copper, Silver, Gold, Platinum at 100:1
# ratios (100c = 1s, 100s = 1g, 100g = 1p). Mirrors the server's
# `protocol::world::Coins` (Rust) — keep the two in sync. The four stacks are
# independent on purpose: holding raw copper instead of its reduced form is a
# player choice with a real weight cost (encumbrance), so nothing here ever
# silently consolidates a wallet. Design: docs/concepts/world/currency.md.
extends Node

# Copper-equivalent value of one coin of each tier, indexed copper→platinum
# (matches the Rust TIER_VALUE ordering).
const TIER_VALUE: Array[int] = [1, 100, 10_000, 1_000_000]

const COPPER := 0
const SILVER := 1
const GOLD := 2
const PLATINUM := 3


## Total copper-equivalent value of a wallet.
func total_copper(platinum: int, gold: int, silver: int, copper: int) -> int:
	return copper + silver * TIER_VALUE[SILVER] + gold * TIER_VALUE[GOLD] \
		+ platinum * TIER_VALUE[PLATINUM]


## Fully-reduced (minimal-coin) representation of a copper amount, as
## [platinum, gold, silver, copper]. For fresh payouts only — never use it to
## rewrite a player's existing holdings.
func from_copper(amount: int) -> Array[int]:
	amount = maxi(amount, 0)
	var p := amount / TIER_VALUE[PLATINUM]
	amount %= TIER_VALUE[PLATINUM]
	var g := amount / TIER_VALUE[GOLD]
	amount %= TIER_VALUE[GOLD]
	var s := amount / TIER_VALUE[SILVER]
	amount %= TIER_VALUE[SILVER]
	return [p, g, s, amount]


## Display string, skipping empty tiers: "2g 5s 30c". An empty wallet is "0c".
func format_coins(platinum: int, gold: int, silver: int, copper: int) -> String:
	var parts: Array[String] = []
	if platinum > 0:
		parts.append("%dp" % platinum)
	if gold > 0:
		parts.append("%dg" % gold)
	if silver > 0:
		parts.append("%ds" % silver)
	if copper > 0:
		parts.append("%dc" % copper)
	if parts.is_empty():
		return "0c"
	return " ".join(parts)


## Spend `cost` copper-equivalents from a wallet ([platinum, gold, silver,
## copper], mutated in place), disturbing it as little as possible: low coins
## go first (shedding heavy copper), and a single higher coin is broken into
## change only when the lower stacks fall short — so a deliberate copper hoard
## survives unrelated purchases. Returns false (wallet untouched) if the
## wallet can't cover the cost. Mirrors Rust `Coins::spend`.
func spend(wallet: Array[int], cost: int) -> bool:
	var total := total_copper(wallet[0], wallet[1], wallet[2], wallet[3])
	if cost < 0 or total < cost:
		return false
	# Working copy indexed copper→platinum; commit only on success.
	var counts: Array[int] = [wallet[3], wallet[2], wallet[1], wallet[0]]
	var remaining := cost
	for i in 4:
		if remaining == 0:
			break
		var val := TIER_VALUE[i]
		var whole := mini(remaining / val, counts[i])
		counts[i] -= whole
		remaining -= whole * val
		# Sub-`val` remainder: break one coin of this tier and scatter the
		# change back down into the lower tiers.
		if remaining > 0 and remaining < val and counts[i] > 0:
			counts[i] -= 1
			var change := val - remaining
			remaining = 0
			for j in range(i - 1, -1, -1):
				counts[j] += change / TIER_VALUE[j]
				change %= TIER_VALUE[j]
	if remaining > 0:
		# Greedy couldn't settle (shouldn't happen once affordable); fall back
		# to full reduction so the balance stays correct.
		var reduced := from_copper(total - cost)
		for k in 4:
			wallet[k] = reduced[k]
		return true
	wallet[0] = counts[3]
	wallet[1] = counts[2]
	wallet[2] = counts[1]
	wallet[3] = counts[0]
	return true
