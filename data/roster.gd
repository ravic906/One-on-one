class_name Roster
extends RefCounted
## Fighter look + stats. Everything visual is assembled from CC0 Quaternius parts (see assets/CREDITS.md).

static var FIGHTERS: Array = [
	{
		"id": "kade", "name": "KADE", "title": "Street Brawler",
		"sex": "Male", "outfit": "Male_Peasant", "outfit_tex": "T_Peasant_2_BaseColor.png",
		"hide": [], "hair": ["Hair_Buzzed", "Hair_Beard"], "hair_color": Color(0.24, 0.15, 0.09),
		"accent": Color(1.0, 0.62, 0.2),
		"speed": 1.0, "power": 1.0, "hp": 1000,
	},
	{
		"id": "vexa", "name": "VEXA", "title": "Forest Striker",
		"sex": "Female", "outfit": "Female_Ranger", "outfit_tex": "T_Ranger_3_BaseColor.png",
		"hide": ["Female_Ranger_Head_Hood", "Female_Ranger_Acc_Pauldrons"], "hair": ["Hair_Buns"], "hair_color": Color(0.55, 0.12, 0.1),
		"accent": Color(0.35, 0.85, 1.0),
		"speed": 1.15, "power": 0.9, "hp": 930,
	},
	{
		"id": "rook", "name": "ROOK", "title": "Hooded Warden",
		"sex": "Male", "outfit": "Male_Ranger", "outfit_tex": "T_Ranger_BaseColor.png",
		"hide": [], "hair": [], "hair_color": Color(0.1, 0.08, 0.06),
		"accent": Color(0.55, 1.0, 0.45),
		"speed": 0.9, "power": 1.15, "hp": 1080,
	},
]
