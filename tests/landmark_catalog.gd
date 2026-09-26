extends SceneTree


func _initialize() -> void:
	for civilization in ["English", "French"]:
		for age in [1, 2, 3]:
			var choices := RtsLandmarkCatalog.choices_for(civilization, age)
			assert(choices.size() == 2)
			for choice in choices:
				assert(choice["age"] == age + 1)
				assert(choice["civilization"] == civilization)
				assert(choice["cost"] == RtsTechTree.age_cost(age))
				assert(choice["time"] == RtsTechTree.age_time(age))
				assert(RtsLandmarkCatalog.choice_status(civilization, age, [], choice["id"])["available"])
				assert(not RtsLandmarkCatalog.choice_status(civilization, age, [], choice["id"], "busy")["available"])
				assert(not RtsLandmarkCatalog.choice_status(civilization, age, [choice["id"]], choice["id"])["available"])
			choices[0]["cost"]["food"] = -999
			assert(RtsLandmarkCatalog.landmark(choices[0]["id"])["cost"]["food"] > 0)
	assert(RtsLandmarkCatalog.choices_for("English", 4).is_empty())
	assert(not RtsLandmarkCatalog.choice_status("French", 1, [], "eng_council_hall")["available"])
	assert(not RtsLandmarkCatalog.choice_status("English", 1, [], "eng_white_tower")["available"])
	assert(not RtsLandmarkCatalog.choice_status("English", 1, ["eng_kings_mill"], "eng_council_hall")["available"])
	assert(RtsLandmarkCatalog.choice_status("English", 1, ["fr_school_of_cavalry"], "eng_council_hall")["available"])
	assert(RtsLandmarkCatalog.producer("eng_council_hall") == "archery_range")
	assert(RtsLandmarkCatalog.training_rate("eng_council_hall") == 0.5)
	assert(RtsLandmarkCatalog.producer("eng_white_tower") == "white_tower")
	assert(RtsLandmarkCatalog.landmark("eng_berkshire_fortress")["defense"]["range"] > GameData.BUILDINGS["keep"]["defense"]["range"])
	assert(RtsLandmarkCatalog.trade_multiplier("French", ["fr_chamber_of_commerce"]) == 1.0)
	assert(RtsLandmarkCatalog.trade_multiplier("English", ["fr_chamber_of_commerce"]) == 1.0)
	assert(RtsLandmarkCatalog.produced_siege_hp("zh_clocktower") == 1.5)
	assert(RtsLandmarkCatalog.research_discount("fr_royal_institute") == 0.5)
	print("LANDMARK_CATALOG_OK")
	quit()
