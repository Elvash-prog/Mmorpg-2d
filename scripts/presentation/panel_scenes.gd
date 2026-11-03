extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const SCENES := {
	"journal":preload("res://content/ui/journal.tscn"),
	"classes":preload("res://content/ui/classes.tscn"),
	"menu":preload("res://content/ui/menu.tscn"),
	"story":preload("res://content/ui/story.tscn"),
	"character":preload("res://content/ui/character.tscn"),
	"network":preload("res://content/ui/network.tscn")
}

static func build(h: Control,key: String) -> Panel:
	var panel: Panel = SCENES[key].instantiate()
	h.add_child(panel)
	panel.hide()
	panel.get_node("Close").pressed.connect(h.close_modals)
	match key:
		"journal":
			h.journal_panel = panel
			h.quest_rows.clear()
			for card in panel.get_node("QuestScroll/QuestList").get_children():
				h.quest_rows.append(card.get_node("Content"))
			panel.get_node("Deliver").pressed.connect(h.world.interact)
			panel.get_node("Story").pressed.connect(h.open_story)
		"classes":
			h.class_panel = panel
			h.class_buttons.clear()
			for i in range(3):
				var card: Button = panel.get_node(["WarriorCard","MageCard","RangerCard"][i])
				card.get_node("ClassName").text = Data.CLASS_NAMES[i]
				card.get_node("BaseStats").text = "%s vida · %s EN" % [int(Data.CLASS_HP[i]),int(Data.CLASS_MANA[i])]
				card.pressed.connect(func():h.world.choose_class(i))
				h.class_buttons.append(card)
			h.class_details = panel.get_node("SkillsScroll/SkillDetails")
			h.class_feedback = panel.get_node("Feedback")
		"menu":
			h.guide_panel = panel
			panel.get_node("Resume").pressed.connect(h.close_modals)
			panel.get_node("Story").pressed.connect(h.open_story)
			panel.get_node("Character").pressed.connect(h.toggle_character)
			panel.get_node("Network").pressed.connect(func():h._toggle(h.network_panel))
		"story":
			h.story_panel = panel
			h.story_title = panel.get_node("ChapterTitle")
			h.story_speaker = panel.get_node("Speaker")
			h.story_body = panel.get_node("Body")
			panel.get_node("Resume").pressed.connect(h.close_modals)
			panel.get_node("Journal").pressed.connect(h.toggle_journal)
		"character":
			h.character_panel = panel
			h.character_stats = panel.get_node("Stats")
			h.character_feedback = panel.get_node("Feedback")
			h.item_details = panel.get_node("ItemDetails")
			h.equip_button = panel.get_node("Equip")
			h.inventory_list = panel.get_node("InventoryScroll/Inventory")
			h.gear_buttons.clear()
			for i in range(Realm.SLOTS.size()):
				var slot: String = Realm.SLOTS[i]
				var button: Button = panel.get_node(["Weapon","Armor","Boots","Amulet"][i])
				button.pressed.connect(func():h.world.equip_item(slot,""))
				h.gear_buttons.append(button)
			h.equip_button.pressed.connect(func():
				if Realm.ITEMS.has(h.selected_item):
					h.world.equip_item(Realm.ITEMS[h.selected_item].slot,h.selected_item))
		"network":
			h.network_panel = panel
			h.address = panel.get_node("Address")
			h.host_button = panel.get_node("Host")
			h.join_button = panel.get_node("Join")
			h.host_button.pressed.connect(func():h.world._host();h.network_panel.hide())
			h.join_button.pressed.connect(func():h.world._join();h.network_panel.hide())
	return panel
