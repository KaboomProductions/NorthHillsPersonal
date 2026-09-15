--// SharedAssets/Dictionaries/NPCDialogue/Zara

local zaraNode = workspace.Ignore.Other:WaitForChild("ZaraNode")
local nodeRoot = zaraNode.PrimaryPart
local promptHolder = nodeRoot:WaitForChild("PromptHolder")

local maxInteractDistance = 15

local zaraDialogue = {
	npcId = "zara",
	displayName = "Zara",

	validateDistance = function(playerPosition: Vector3): boolean
		local distance = (promptHolder.WorldPosition - playerPosition).Magnitude
		return distance <= maxInteractDistance
	end,

	conditions = {
		firstTimeFamiliarity = 0,
		veryLow = 15,
		low = 30,
		mid = 50,
		high = 70,
	},

	nightStarting = {
		lowTrust = {
			"Get out of here, I'm not waiting around for that thing to kill me.",
		},
		neutral = {
			"Go somewhere else. It's on the way right now, I'm sure.",
		},
		default = {
			"Good luck out there.",
		},
	},

	busy = {
		lowTrust = {
			"Can't you see I'm busy? Wait.",
			"I'm dealing with someone. Get in line.",
		},
		neutral = {
			"Hold on. I'm with someone right now.",
			"Wait your turn.",
		},
		highTrust = {
			"Give me a second, I'll get to you.",
			"Almost done here. Hang on.",
		},
	},

	greetings = {
		firstTime = {
			"You're new. Make it quick.",
			"Don't waste my time.",
			"Welcome to my tower, what do you want.",
			"What do you need.",
		},
		lowTrust = {
			"You're back again?",
			"What now.",
			"You must be real desperate huh.",
		},
		lowRespect = {
			"Try not to make a bad decision this time.",
			"Let me guess. You need saving again.",
			"You are too dependent on me for your survival.",
		},
		lowPatience = {
			"Say what you need.",
			"I don't have all day.",
		},
		neutral = {
			"What do you want.",
			"Go ahead.",
		},
		highFamiliarity = {
			"You're early.",
			"Back already?",
		},
		highTrust = {
			"You're fine. Just tell me what you need.",
			"You survived again. Good.",
		},
		highTrustHighRespect = {
			"Alright. What are we doing today.",
			"You usually know what you're doing.",
		},
	},

	playerChoices = {
		buy = {
			exchanges = {
				{
					player = "I need supplies.",
					zara = {
						lowTrust = { "You better not waste them." },
						lowRespect = { "Pick something you can actually use." },
						neutral = { "Fine. Take a look." },
						highTrust = { "Take what you need." },
					},
				},
				{
					player = "Show me what you've got.",
					zara = {
						lowTrust = { "Don't touch anything you can't afford." },
						lowRespect = { "Try not to break anything while you look." },
						neutral = { "Everything's right there." },
						highTrust = { "I just restocked. You've got good timing." },
					},
				},
				{
					player = "I need something useful.",
					zara = {
						lowTrust = { "Everything here is useful. That's on you to figure out." },
						lowRespect = { "You need a lot of things. Let's start with common sense." },
						neutral = { "Useful is all I sell." },
						highTrust = { "I might have something in mind for you." },
					},
				},
				{
					player = "What's in stock?",
					zara = {
						lowTrust = { "More than you can afford, probably." },
						neutral = { "See for yourself." },
						highTrust = { "Got a few things you'd like. Check it out." },
					},
				},
			},
		},

		repair = {
			exchanges = {
				{
					player = "Can you fix this?",
					zara = {
						lowRespect = { "What did you do to it?" },
						lowTrust = { "Depends. Don't expect a miracle." },
						neutral = { "Put it here. I'll see what I can do." },
						highFamiliarity = { "You always come back with something broken." },
						highTrust = { "Yeah, hand it over." },
					},
				},
				{
					player = "I need this repaired.",
					zara = {
						lowRespect = { "You must be rough with your stuff." },
						lowTrust = { "Don't ruin it again after I fix it." },
						neutral = { "Let me take a look." },
						highTrust = { "I'll handle it." },
					},
				},
				{
					player = "This is damaged.",
					zara = {
						lowRespect = { "Obviously. I can see that from here." },
						lowTrust = { "And whose fault is that?" },
						neutral = { "Set it down. I'll check it." },
						highTrust = { "I'll get it sorted. Give me a minute." },
					},
				},
			},
		},

		sell = {
			exchanges = {
				{
					player = "I found something. Want it?",
					zara = {
						lowTrust = { "If it's junk, I'm not buying it." },
						lowRespect = { "This better be worth my time." },
						neutral = { "Let me see what you've got." },
						highTrust = { "You usually bring decent stuff. Show me." },
					},
				},
				{
					player = "I've got something to sell.",
					zara = {
						lowTrust = { "Don't try to scam me." },
						lowRespect = { "I'll be the judge of what it's worth." },
						neutral = { "Alright. What is it?" },
						highTrust = { "Sure, let's see." },
					},
				},
				{
					player = "Buy this off me.",
					zara = {
						lowTrust = { "I don't just buy anything." },
						lowRespect = { "You don't get to set the price." },
						neutral = { "Maybe. Depends on what it is." },
						highTrust = { "Hand it over. I'll give you a fair deal." },
					},
				},
			},
		},

		quests = {
			exchanges = {
				{
					player = "Need anything done?",
					zara = {
						lowFamiliarity = { "Why would I trust you with that?" },
						lowTrust = { "Don't mess this up." },
						neutral = { "Actually, yeah. I need a few things." },
						highTrust = { "Good. I was hoping you'd ask." },
						highTrustHighRespect = { "I knew you'd show up." },
					},
				},
				{
					player = "What are you short on?",
					zara = {
						lowFamiliarity = { "How is that your business?" },
						lowTrust = { "Nothing I'd trust you to get." },
						neutral = { "I could use some supplies. Check the list." },
						highTrust = { "A few things, actually. Here." },
					},
				},
				{
					player = "Got any work for me?",
					zara = {
						lowFamiliarity = { "I don't hand out work to strangers." },
						lowTrust = { "Maybe. If you can handle it." },
						neutral = { "Yeah. I need supplies brought in." },
						highTrust = { "Always. Take a look." },
						highTrustHighRespect = { "Been saving one for you." },
					},
				},
			},
		},
	},

	insufficientCredits = {
		lowTrust = {
			"Unfortunately, you are too broke to buy this.",
			"Come back when you aren't broke.",
		},
		lowRespect = {
			"Do you not know math? You don't have enough for this item.",
		},
		neutral = {
			"You don't have enough to buy this.",
		},
	},

	insufficientSurvivals = {
		lowTrust = {
			"I don't trust you with this, you're just going to die with it.",
		},
		lowRespect = {
			"I have limited stock, too limited for you to go out and lose it.",
		},
		neutral = {
			"Come back when you have actual survival skills.",
		},
		veryLowRespect = {
			"You have a skill issue, fix that, then you can have it.",
		},
	},

	buyConfirm = {
		lowTrust = {
			"Money's money. Don't come back complaining.",
			"Transaction done. Move along.",
		},
		lowRespect = {
			"Try not to lose it within the hour.",
		},
		neutral = {
			"Done. Take care of it.",
			"All yours.",
		},
		highTrust = {
			"Good choice. That'll serve you well.",
			"Solid pick. You know what you're doing.",
		},
	},

	haggle = {
		lowTrust = {
			"You're joking. Full price.",
			"No. You pay what I ask.",
			"That's bold of you. The answer is no.",
		},
		lowRespect = {
			"You're in no position to negotiate.",
			"You think I run a charity?",
		},
		neutral = {
			"I don't do discounts.",
			"Price is what it is.",
		},
		highTrust = {
			"Normally I'd say no, but... let me think about it.",
		},
	},

	discounts = {
		midTrust = {
			"You're not totally useless after all.",
			"Don't make a big deal out of this.",
		},
		highTrust = {
			"I'm not going to be doing this all the time.",
			"Don't think you are special, or anything.",
		},
		highTrustHighFamiliarity = {
			"Just take it.",
		},
	},

	impatience = {
		lowPatience = {
			"Anytime now.",
			"Are you thinking or staring.",
		},
		veryLowPatience = {
			"I'm closing soon.",
			"Pick something or leave.",
		},
	},

	exit = {
		lowTrust = {
			"We're done.",
		},
		neutral = {
			"That's it.",
		},
		highTrust = {
			"Stay alive.",
		},
		veryLowPatience = {
			"Leave.",
		},
	},
}

return zaraDialogue
