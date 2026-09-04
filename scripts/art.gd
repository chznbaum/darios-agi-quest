class_name QuestArt
extends RefCounted

# Tight atlas regions preserve the original generated PNG, including its alpha.
const REGIONS = [
	Rect2(68,48,179,304), Rect2(376,57,204,296), Rect2(673,57,198,296), Rect2(985,27,216,279),
	Rect2(57,460,202,174), Rect2(369,465,225,169), Rect2(661,395,220,239), Rect2(989,398,223,242),
	Rect2(77,709,164,175), Rect2(387,688,172,202), Rect2(713,668,116,224), Rect2(1010,725,175,161),
	Rect2(71,919,148,302), Rect2(382,908,190,289), Rect2(668,931,217,266), Rect2(986,931,225,265)
]
static var cache: Dictionary = {}

static func texture(index: int) -> AtlasTexture:
	if not cache.has(index):
		var result := AtlasTexture.new()
		result.atlas = load("res://assets/art/characters.png")
		result.region = REGIONS[index]
		result.filter_clip = true
		cache[index] = result
	return cache[index]

