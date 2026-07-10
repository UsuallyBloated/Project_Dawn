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
		}
	}
}
