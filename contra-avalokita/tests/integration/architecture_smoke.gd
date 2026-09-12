extends Node

func _ready() -> void:
	var base_manifest := load("res://content/base/manifest.tres") as ContentManifest
	var test_manifest := load("res://extensions/dlc/test_dlc/manifest.tres") as ContentManifest
	var resolution := DependencyResolver.resolve([test_manifest, base_manifest])
	assert(resolution.ok)
	ContentRegistry.clear()
	for manifest: ContentManifest in resolution.ordered:
		assert(ContentRegistry.register_manifest(manifest) == OK)
	assert(ContentRegistry.has_content(&"base:sword"))
	assert(ContentRegistry.get_content(&"base:sword").resource is PackedScene)
	assert(ContentRegistry.has_content(&"test_dlc:red_sword"))
	assert(ContentRegistry.query_by_tag(&"weapon", [&"blade"]).size() == 2)
	assert(ContentRegistry.query(&"equipment").size() == 2)
	assert(ContentRegistry.query(&"morph").size() == 5)

	var campaign_a := SaveSchema.new_campaign(&"campaign_a", GameVersion.VERSION, ContentRegistry.list_packages())
	var campaign_b := SaveSchema.new_campaign(&"campaign_b", GameVersion.VERSION, ContentRegistry.list_packages())
	campaign_a.characters["base:mud_monkey"] = SaveSchema.new_character(&"base:mud_monkey")
	campaign_a.characters["base:mulian"] = SaveSchema.new_character(&"base:mulian")
	campaign_a.world_state.flags["temple_open"] = true
	assert(campaign_a.characters["base:mud_monkey"] != campaign_a.characters["base:mulian"])
	assert(campaign_a.world_state.flags.temple_open)
	assert(not campaign_b.world_state.flags.has("temple_open"))

	var missing := SaveManager.resolve_content_reference(&"missing_mod:item") as Dictionary
	assert(missing.missing_content)
	assert(CommandRegistry.execute("content.info base:sword") is Dictionary)
	print("ARCHITECTURE_SMOKE_OK")
	get_tree().quit()
