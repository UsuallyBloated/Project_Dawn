class_name FactionDefinitions

# The world's factions, mirrored from the server's data/factions.toml: ids
# and display names only (the links and the hits live on the server; the
# client learns its standings from FactionUpdate). Kept in lockstep by
# tools/check_faction_lockstep.gd. The Test Panel's GM faction sliders are
# built from this list before the server has said anything.
const ALL := [
	{"id": "greyveil_town",  "name": "The Folk of Greyveil"},
	{"id": "greyveil_watch", "name": "The Greyveil Watch"},
	{"id": "gnoll_raiders",  "name": "The Gnoll Raiders"},
	{"id": "bandits",        "name": "The Road Bandits"},
	{"id": "restless_dead",  "name": "The Restless Dead"},
	{"id": "wildlife",       "name": "Wildlife"},
]
