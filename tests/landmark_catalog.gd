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
	assert(RtsLandmarkCatalog.gather_multiplier("English", ["eng_kings_mill"], "food", true) == 1.25)
	assert(RtsLandmarkCatalog.gather_multiplier("English", ["eng_kings_mill"], "food", false) == 1.0)
	assert(RtsLandmarkCatalog.gather_multiplier("French", ["eng_kings_mill"], "food", true) == 1.0)
	assert(RtsLandmarkCatalog.gather_multiplier("French", ["fr_chamber_of_commerce"], "gold") == 1.2)
	assert(RtsLandmarkCatalog.training_multiplier("English", ["eng_council_hall", "eng_wynguard_palace"], "archery_range", "longbow") == 0.675)
	assert(RtsLandmarkCatalog.training_multiplier("English", ["eng_council_hall"], "barracks") == 1.0)
	assert(RtsLandmarkCatalog.unit_bonus("English", ["eng_abbey", "eng_wynguard_palace"], "longbow", ["military", "infantry", "ranged"]) == {"hp": 15.0, "damage": 2.0})
	assert(RtsLandmarkCatalog.unit_bonus("French", ["fr_college_of_artillery"], "battering_ram", ["military", "siege"])["damage"] == 5.0)
	assert(RtsLandmarkCatalog.building_bonus("English", ["eng_white_tower", "eng_berkshire_fortress"], "town_center") == {"hp": 300.0, "armor_ranged": 2.0, "armor_melee": 2.0})
	assert(RtsLandmarkCatalog.building_bonus("English", ["eng_white_tower", "eng_white_tower"], "town_center")["hp"] == 100.0)
	print("LANDMARK_CATALOG_OK")
	quit()
