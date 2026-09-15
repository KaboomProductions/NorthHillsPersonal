local weapons = {
	WoodenBat = {
		displayName = "Wooden Bat",
		itemId = "WoodenBat",
		category = "Weapons",
		rarity = "Common",
		rarityColor = Color3.fromRGB(180, 180, 180),
		description = "A weapon commonly found in every cabin used for this purpose, notorious for slowing down wielders but has high durability.",
		weaponType = "Melee",
		price = 250,
		discountedPrice = 150,
		stock = 5,
		minSurvivals = 0,

		stats = {
			{	name = "Damage", 
				value = 0.7 
			},
			
			{	name = "Speed", 
				value = 0.4 
			},
			
			{	name = "Durability", 
				value = 0.9 
			},
			
			{	name = "Range", 
				value = 0.5 
			},
		},

		tips = {
			"This weapon is highly effective but lacks in durability, it is very easy to swing though. However pay attention to its durability so it does not break on you.",
			"This weapon can be repaired for a pretty cheap price as well and can be stored at Zara's lockers for when you might need it.",
		},

		zaraComments = {
			lowTrust = {
				"A bat. Try not to hurt yourself.",
				"Basic, but it works. Barely.",
			},
			lowRespect = {
				"A bat in good condition, it's hard to find one of those around these days. Anyways, what do you say? You gonna buy it or keep wastin' my time?",
			},
			neutral = {
				"Solid choice. Cheap, reliable, gets the job done.",
				"Can't go wrong with a bat. Simple.",
			},
			highTrust = {
				"Good pick. These hold up better than you'd think.",
				"I keep these in stock for a reason. Reliable.",
			},
		},
	},
}

return weapons