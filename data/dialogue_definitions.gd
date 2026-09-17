class_name DialogueDefinitions

# NPC dialogue trees. Key = NPC name (must match DialogueNPC.npc_name export).
# Each tree has a "npc_title" string and one dict per node id.
#
# Node fields:
#   text: String      — what the NPC says
#   responses: Array  — list of response dicts
#
# Response fields:
#   text: String           — button label
#   goto: String           — navigate to this node id
#   action: String         — "close", "open_vendor", "give_quest", "complete_quest"
#   quest_id: String       — used with give_quest / complete_quest actions
#   quest_condition: Dict  — {id, status} filters response visibility:
#                            status "none" = quest not yet accepted
#                            status "ACTIVE" = quest accepted and in progress
#                            status "READY" = all objectives done, not yet turned in
#                            status "COMPLETED" = turned in (reward paid)

const ALL: Dictionary = {
	"Aldric the Guard": {
		"npc_title": "Town Guard",
		"root": {
			"text": "Halt. State your business in Valdis.",
			"responses": [
				# Quest offer — only if wolf_threat not yet started
				{
					"text": "I heard you might have work.",
					"goto": "work_offer",
					"quest_condition": {"id": "wolf_threat", "status": "none"}
				},
				# Active wolf quest check-in
				{
					"text": "I'm hunting the wolves. Still at it.",
					"goto": "wolf_active",
					"quest_condition": {"id": "wolf_threat", "status": "ACTIVE"}
				},
				# Wolf quest turn-in
				{
					"text": "The wolves are dealt with.",
					"goto": "wolf_turn_in",
					"quest_condition": {"id": "wolf_threat", "status": "READY"}
				},
				# Rotfang offer — only after wolf quest done, rotfang not started
				{
					"text": "Any other work for me?",
					"goto": "rotfang_offer",
					"quest_condition": {"id": "rotfang_hunt", "status": "none"}
				},
				# Rotfang active
				{
					"text": "Still tracking Rotfang.",
					"goto": "rotfang_active",
					"quest_condition": {"id": "rotfang_hunt", "status": "ACTIVE"}
				},
				# Rotfang turn-in
				{
					"text": "Rotfang is dead.",
					"goto": "rotfang_turn_in",
					"quest_condition": {"id": "rotfang_hunt", "status": "READY"}
				},
				# Restless Bones (phase 4) — offer / active / turn-in
				{
					"text": "The graves outside town look disturbed.",
					"goto": "bones_offer",
					"quest_condition": {"id": "restless_bones", "status": "none"}
				},
				{
					"text": "Still breaking bones.",
					"goto": "bones_active",
					"quest_condition": {"id": "restless_bones", "status": "ACTIVE"}
				},
				{
					"text": "The skeletons are settled.",
					"goto": "bones_turn_in",
					"quest_condition": {"id": "restless_bones", "status": "READY"}
				},
				# Champion's Crypt (phase 4)
				{
					"text": "What is the broken crypt north of town?",
					"goto": "crypt_offer",
					"quest_condition": {"id": "champions_crypt", "status": "none"}
				},
				{
					"text": "The crypt work continues.",
					"goto": "crypt_active",
					"quest_condition": {"id": "champions_crypt", "status": "ACTIVE"}
				},
				{
					"text": "Six of the crypt's champions are down.",
					"goto": "crypt_turn_in",
					"quest_condition": {"id": "champions_crypt", "status": "READY"}
				},
				# The Undying (phase 4 finale)
				{
					"text": "Something is wrong in the western barrow.",
					"goto": "undying_offer",
					"quest_condition": {"id": "the_undying", "status": "none"}
				},
				{
					"text": "The thing in the barrow still moves.",
					"goto": "undying_active",
					"quest_condition": {"id": "the_undying", "status": "ACTIVE"}
				},
				{
					"text": "The Undying is ended.",
					"goto": "undying_turn_in",
					"quest_condition": {"id": "the_undying", "status": "READY"}
				},
				{"text": "Just passing through.", "goto": "passing"},
				{"text": "What can you tell me about the area?", "goto": "area"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"passing": {
			"text": "Move along then. Stay on the roads and you'll be fine. Stray east and you're on your own.",
			"responses": [
				{"text": "Understood.", "action": "close"}
			]
		},
		"area": {
			"text": "Valdis sits at the edge of the settled lands. East is the Gnoll Flats — bad country. North is Greywood, worse. The wilds are full of things that don't want us here. We hold the line as best we can.",
			"responses": [
				{"text": "Sounds grim.", "goto": "root"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"work_offer": {
			"text": "As a matter of fact, yes. Wolves have been harassing travelers on the eastern road — three attacks in the last fortnight. I need someone to thin the pack. Kill five and I'll see you paid.",
			"responses": [
				{
					"text": "I'll do it.",
					"action": "give_quest",
					"quest_id": "wolf_threat",
					"goto": "wolf_accepted"
				},
				{"text": "Maybe another time.", "goto": "root"}
			]
		},
		"wolf_accepted": {
			"text": "Good. The pack hunts south of the road, about a quarter mile out. Don't go alone if you can help it.",
			"responses": [
				{"text": "I'll be careful.", "action": "close"}
			]
		},
		"wolf_active": {
			"text": "Keep at it. We need those roads safe before the next supply run.",
			"responses": [
				{"text": "Understood.", "action": "close"}
			]
		},
		"wolf_turn_in": {
			"text": "That's a relief. The merchants will be glad to hear it. Here — your payment, as promised.",
			"responses": [
				{
					"text": "Thank you.",
					"action": "complete_quest",
					"quest_id": "wolf_threat",
					"goto": "wolf_rewarded"
				}
			]
		},
		"wolf_rewarded": {
			"text": "Well earned. Come back if you're looking for more work — this frontier always has need of capable hands.",
			"responses": [
				{"text": "I will.", "action": "close"}
			]
		},
		"rotfang_offer": {
			"text": "There's a beast called Rotfang the Feared — a massive old wolf that's killed three hunters this month. It's smart, territorial, and it knows the southern wilds. I'll pay well for proof it's dead.",
			"responses": [
				{
					"text": "I'll hunt it.",
					"action": "give_quest",
					"quest_id": "rotfang_hunt",
					"goto": "rotfang_accepted"
				},
				{"text": "That sounds dangerous. Not yet.", "goto": "root"}
			]
		},
		"rotfang_accepted": {
			"text": "You'll know it by its size and the black streak across its muzzle. Its den is in the old rock formation south of the mill. Good luck — you'll need it.",
			"responses": [
				{"text": "I'll find it.", "action": "close"}
			]
		},
		"rotfang_active": {
			"text": "Rotfang's still out there. Be careful — it's cunning. It'll ambush you if you're not watching.",
			"responses": [
				{"text": "Understood.", "action": "close"}
			]
		},
		"rotfang_turn_in": {
			"text": "By the Architects — you actually did it. I half-expected to be sending a search party. The garrison owes you a debt. Take this medal. You've earned it.",
			"responses": [
				{
					"text": "It wasn't easy.",
					"action": "complete_quest",
					"quest_id": "rotfang_hunt",
					"goto": "rotfang_rewarded"
				}
			]
		},
		"rotfang_rewarded": {
			"text": "The frontier is a little safer today. If you're ever looking for work again, you know where to find me.",
			"responses": [
				{"text": "Until next time.", "action": "close"}
			]
		},
		"bones_offer": {
			"text": "You noticed that too. The dead have been clawing out of the ground west of the walls — slow, stupid things, but a farmer with a hoe is no match for even one. Break eight of them and the garrison will owe you. There's a leather cap in the stores with your name on it.",
			"responses": [
				{
					"text": "I'll see them buried properly.",
					"action": "give_quest",
					"quest_id": "restless_bones",
					"goto": "bones_accepted"
				},
				{"text": "Grave-digging isn't my trade.", "goto": "root"}
			]
		},
		"bones_accepted": {
			"text": "The Bonepile is west of town, past the old markers. The rotting ones by the eastern graves count the same — a broken bone is a broken bone.",
			"responses": [
				{"text": "Understood.", "action": "close"}
			]
		},
		"bones_active": {
			"text": "Still at it? Good. Every skull you crack is one that doesn't crack a farmer's.",
			"responses": [
				{"text": "Back to work.", "action": "close"}
			]
		},
		"bones_turn_in": {
			"text": "Eight fewer dead things walking my frontier. Take the cap — garrison issue, better than nothing, and you earned it.",
			"responses": [
				{
					"text": "Thank you.",
					"action": "complete_quest",
					"quest_id": "restless_bones",
					"goto": "bones_rewarded"
				}
			]
		},
		"bones_rewarded": {
			"text": "The graves are quieter already. There will be more work when you're ready for it.",
			"responses": [
				{"text": "I'll be back.", "action": "close"}
			]
		},
		"crypt_offer": {
			"text": "The Broken Crypt. Old — older than Valdis, older than the road. The dead inside wear armour and keep discipline, which frightens me more than the shambling kind. Put six of its champions down so I know it can be done. The garrison will pay in iron.",
			"responses": [
				{
					"text": "The crypt gets its reckoning.",
					"action": "give_quest",
					"quest_id": "champions_crypt",
					"goto": "crypt_accepted"
				},
				{"text": "Not yet. That place feels wrong.", "goto": "root"}
			]
		},
		"crypt_accepted": {
			"text": "Due north, past the far graves — you'll know it by the fallen stones. Take a friend. I mean that.",
			"responses": [
				{"text": "I will.", "action": "close"}
			]
		},
		"crypt_active": {
			"text": "The champions still hold the crypt. Careful — discipline means they don't break and run like the rest.",
			"responses": [
				{"text": "Neither do I.", "action": "close"}
			]
		},
		"crypt_turn_in": {
			"text": "Six armoured dead, unmade. You're not the same fighter who first walked through my gate. The leggings are yours — the garrison's best iron.",
			"responses": [
				{
					"text": "They fought like soldiers.",
					"action": "complete_quest",
					"quest_id": "champions_crypt",
					"goto": "crypt_rewarded"
				}
			]
		},
		"crypt_rewarded": {
			"text": "If the crypt can bleed, whatever commands it can too. We'll speak again.",
			"responses": [
				{"text": "Count on it.", "action": "close"}
			]
		},
		"undying_offer": {
			"text": "I'll speak plainly. The Sunken Barrow in the western hills wasn't dug to bury something — it was dug to HOLD something. The wards are failing, and the thing inside, the old records only call it the Undying, is awake. The garrison's finest blade goes to whoever ends it. I don't expect volunteers.",
			"responses": [
				{
					"text": "Then it dies by my hand.",
					"action": "give_quest",
					"quest_id": "the_undying",
					"goto": "undying_accepted"
				},
				{"text": "There are limits to my courage.", "goto": "root"}
			]
		},
		"undying_accepted": {
			"text": "The barrow mouth is beyond the western hills, past the bone fields. The records say fire is how they held it the first time. Flamebrand waits for your return.",
			"responses": [
				{"text": "Keep it ready.", "action": "close"}
			]
		},
		"undying_active": {
			"text": "Still standing? Then there's still hope. The barrow won't empty itself.",
			"responses": [
				{"text": "Soon.", "action": "close"}
			]
		},
		"undying_turn_in": {
			"text": "By the Architects — it's done. Whatever the Undying was, you've ended a fear older than this town. Flamebrand is yours. Carry it well.",
			"responses": [
				{
					"text": "It earned its grave.",
					"action": "complete_quest",
					"quest_id": "the_undying",
					"goto": "undying_rewarded"
				}
			]
		},
		"undying_rewarded": {
			"text": "The frontier owes you more than it knows. So do I.",
			"responses": [
				{"text": "Until the next fight.", "action": "close"}
			]
		}
	},

	"Elara": {
		"npc_title": "General Merchant",
		"root": {
			"text": "Welcome, traveler! Looking to buy or sell? I stock a little of everything — tools, sundries, whatever a weary adventurer might need.",
			"responses": [
				{"text": "Let me see your wares.", "action": "open_vendor"},
				{"text": "What do you know about this town?", "goto": "town"},
				{"text": "Have you heard any news?", "goto": "news"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"town": {
			"text": "Valdis is growing, believe it or not. A year ago this was just a watchtower and three buildings. Now we've got merchants, a garrison, even a few crafters. The frontier draws people — sometimes those running from something, sometimes those looking for it.",
			"responses": [
				{"text": "Interesting.", "goto": "root"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"news": {
			"text": "Nothing good. Supply caravans from the capital have been delayed — gnoll raids on the eastern road. And I've heard stranger things from traders coming in from the north. Something in the Greywood has them spooked. Won't say what.",
			"responses": [
				{"text": "I'll keep my eyes open.", "goto": "root"},
				{"text": "Farewell.", "action": "close"}
			]
		}
	},

	"Brom": {
		"npc_title": "Provisioner",
		"root": {
			"text": "Hail! Brom's Provisions — food, drink, and trail supplies. What can I do for you?",
			"responses": [
				{"text": "Show me what you have.", "action": "open_vendor"},
				# Rat quest offer
				{
					"text": "You look capable. Got a problem I need help with.",
					"goto": "rat_offer",
					"quest_condition": {"id": "rat_infestation", "status": "none"}
				},
				# Rat quest active
				{
					"text": "Still clearing out those rats.",
					"goto": "rat_active",
					"quest_condition": {"id": "rat_infestation", "status": "ACTIVE"}
				},
				# Rat quest turn-in
				{
					"text": "The rats are cleared out.",
					"goto": "rat_turn_in",
					"quest_condition": {"id": "rat_infestation", "status": "READY"}
				},
				# Gnoll quest offer — available after rat quest done
				{
					"text": "Any more work?",
					"goto": "gnoll_offer",
					"quest_condition": {"id": "gnoll_raiders", "status": "none"}
				},
				# Gnoll quest active
				{
					"text": "Still fighting gnolls out east.",
					"goto": "gnoll_active",
					"quest_condition": {"id": "gnoll_raiders", "status": "ACTIVE"}
				},
				# Gnoll quest turn-in
				{
					"text": "The gnoll raiders are dealt with.",
					"goto": "gnoll_turn_in",
					"quest_condition": {"id": "gnoll_raiders", "status": "READY"}
				},
				# Road Toll (phase 4) — offer / active / turn-in
				{
					"text": "Heard about trouble on the northwest road?",
					"goto": "toll_offer",
					"quest_condition": {"id": "road_toll", "status": "none"}
				},
				{
					"text": "Still collecting the road toll.",
					"goto": "toll_active",
					"quest_condition": {"id": "road_toll", "status": "ACTIVE"}
				},
				{
					"text": "The bandits have paid up.",
					"goto": "toll_turn_in",
					"quest_condition": {"id": "road_toll", "status": "READY"}
				},
				# The Silk Harvest (phase 4)
				{
					"text": "Work for someone who isn't afraid of the eastern trees?",
					"goto": "silk_offer",
					"quest_condition": {"id": "silk_harvest", "status": "none"}
				},
				{
					"text": "Still clearing the silk paths.",
					"goto": "silk_active",
					"quest_condition": {"id": "silk_harvest", "status": "ACTIVE"}
				},
				{
					"text": "Ten spiders cleared, as asked.",
					"goto": "silk_turn_in",
					"quest_condition": {"id": "silk_harvest", "status": "READY"}
				},
				{"text": "What's the road east like?", "goto": "east_road"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"east_road": {
			"text": "Rough going lately. Gnolls hit another caravan last tenday — three guards dead. I wouldn't travel it without a full pack and company. If you're going anyway, stock up first. Hunger and thirst kill as surely as a blade.",
			"responses": [
				{"text": "Thanks for the warning.", "goto": "root"},
				{"text": "Farewell.", "action": "close"}
			]
		},
		"rat_offer": {
			"text": "Rats have gotten into my storage cellar — fat ones, aggressive. They've ruined half my winter stock already. Kill eight of them and I'll make it worth your time.",
			"responses": [
				{
					"text": "I'll handle it.",
					"action": "give_quest",
					"quest_id": "rat_infestation",
					"goto": "rat_accepted"
				},
				{"text": "Not right now.", "goto": "root"}
			]
		},
		"rat_accepted": {
			"text": "Cellar entrance is around back, left of the barrels. Mind your step — the floor's rotten in spots.",
			"responses": [
				{"text": "Got it.", "action": "close"}
			]
		},
		"rat_active": {
			"text": "They're still down there? Nasty things. Keep at it.",
			"responses": [
				{"text": "I will.", "action": "close"}
			]
		},
		"rat_turn_in": {
			"text": "Finally! I can breathe again. That cellar's been keeping me up at night. No coin this time, I'm afraid — took a loss on the spoiled stock — but you have my thanks.",
			"responses": [
				{
					"text": "Glad to help.",
					"action": "complete_quest",
					"quest_id": "rat_infestation",
					"goto": "rat_rewarded"
				}
			]
		},
		"rat_rewarded": {
			"text": "If you ever need trail supplies, I'll give you a fair price. You've earned that much.",
			"responses": [
				{"text": "Appreciated.", "action": "close"}
			]
		},
		"gnoll_offer": {
			"text": "Those gnoll scouts are going to bring a full war party down on us if someone doesn't hit them first. Kill eight of their raiders east of town and maybe they'll think twice. I'll pay in equipment — good boots, better than anything you'd find out there.",
			"responses": [
				{
					"text": "Consider it done.",
					"action": "give_quest",
					"quest_id": "gnoll_raiders",
					"goto": "gnoll_accepted"
				},
				{"text": "Not ready for that yet.", "goto": "root"}
			]
		},
		"gnoll_accepted": {
			"text": "They camp in the rocky flats about a mile east. Hit them fast and don't let them surround you.",
			"responses": [
				{"text": "I'll be ready.", "action": "close"}
			]
		},
		"gnoll_active": {
			"text": "Stay after them. Every raider you kill is a caravan that makes it through.",
			"responses": [
				{"text": "Understood.", "action": "close"}
			]
		},
		"gnoll_turn_in": {
			"text": "Eight gnoll raiders — I wouldn't have believed it if I didn't know you. The caravans owe you one. Here, as promised.",
			"responses": [
				{
					"text": "They won't be raiding again soon.",
					"action": "complete_quest",
					"quest_id": "gnoll_raiders",
					"goto": "gnoll_rewarded"
				}
			]
		},
		"gnoll_rewarded": {
			"text": "Good boots last a lifetime if you take care of them. Stay safe out there.",
			"responses": [
				{"text": "I will.", "action": "close"}
			]
		},
		"toll_offer": {
			"text": "Bandits have set up in the northwest hills — calling it a 'road toll', taking a cut of every caravan through. My suppliers pay it, which means I pay it. Kill six of them and I'll pay YOU instead. Good chain coif in it for you, caravan-guard quality.",
			"responses": [
				{
					"text": "Consider the toll cancelled.",
					"action": "give_quest",
					"quest_id": "road_toll",
					"goto": "toll_accepted"
				},
				{"text": "Not my fight yet.", "goto": "root"}
			]
		},
		"toll_accepted": {
			"text": "Their outpost is up in the northwest hills, past the graves. They're trained — not like the rats. They watch each other's backs, so watch yours.",
			"responses": [
				{"text": "I'll be careful.", "action": "close"}
			]
		},
		"toll_active": {
			"text": "Every bandit down is coin back in honest pockets. Keep at it.",
			"responses": [
				{"text": "I will.", "action": "close"}
			]
		},
		"toll_turn_in": {
			"text": "Six of them! The caravans will breathe easier, and so will my ledger. Here — the coif, as promised. Wear it in good health.",
			"responses": [
				{
					"text": "The road's yours again.",
					"action": "complete_quest",
					"quest_id": "road_toll",
					"goto": "toll_rewarded"
				}
			]
		},
		"toll_rewarded": {
			"text": "Trade flows again, thanks to you. Whatever you need from my shelves, you'll get my best price.",
			"responses": [
				{"text": "Appreciated.", "action": "close"}
			]
		},
		"silk_offer": {
			"text": "The trees east of the far graves are webbed roof to root — giant spiders, big as hounds. That silk is worth more than anything in this shop, but no harvester will go near it. Kill ten and clear the paths. I'll pay in good leather.",
			"responses": [
				{
					"text": "The spiders die today.",
					"action": "give_quest",
					"quest_id": "silk_harvest",
					"goto": "silk_accepted"
				},
				{"text": "I've seen those webs. No.", "goto": "root"}
			]
		},
		"silk_accepted": {
			"text": "The copse is east, past the festering mound. If the webbing gets thick overhead, that's when they drop on you. Don't stop moving.",
			"responses": [
				{"text": "Noted.", "action": "close"}
			]
		},
		"silk_active": {
			"text": "The webs still stand. Ten spiders, then the harvest crews go in.",
			"responses": [
				{"text": "Working on it.", "action": "close"}
			]
		},
		"silk_turn_in": {
			"text": "Ten! The silk crews are already packing their shears. This vest is cured from the best hide I had — you've more than earned it.",
			"responses": [
				{
					"text": "Mind the little ones I missed.",
					"action": "complete_quest",
					"quest_id": "silk_harvest",
					"goto": "silk_rewarded"
				}
			]
		},
		"silk_rewarded": {
			"text": "First profit from the silk is yours in spirit. Safe roads, friend.",
			"responses": [
				{"text": "Safe roads, Brom.", "action": "close"}
			]
		}
	},

	# Soul Binder. Binding sets where you wake up after dying. Before bind points
	# existed you always respawned exactly where you fell, which beside a live mob
	# was an unwinnable loop. Stationed by the town spawn so a newly respawned
	# player can reach her without a corpse run.
	"Sister Maelis": {
		"npc_title": "Soul Binder",
		"root": {
			"text": "Death comes for everyone in these lands, friend. The question is only where you wake afterward.",
			"responses": [
				{"text": "What do you mean, where I wake?", "goto": "explain"},
				{"text": "Bind my soul to this place.", "action": "bind_soul", "goto": "bound"},
				{"text": "Not today.", "action": "close"}
			]
		},
		"explain": {
			"text": "Bind your soul here and this ground will call you back. Fall anywhere in the world and you will rise here instead, whole enough to walk. Leave it unbound and you return to the town gate, as all the unbound do.",
			"responses": [
				{"text": "Then bind me here.", "action": "bind_soul", "goto": "bound"},
				{"text": "I will think on it.", "action": "close"}
			]
		},
		"bound": {
			"text": "It is done. However far you wander, however badly it ends, this is where you will open your eyes.",
			"responses": [
				{"text": "My thanks.", "action": "close"}
			]
		}
	}
}
