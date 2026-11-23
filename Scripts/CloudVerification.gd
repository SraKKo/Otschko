extends "res://Scripts/ControllerVerification.gd"
var phase := "write"

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://cloud-" + name + ".png")

func idle() -> void:
	await frames(3)
	var deadline := Time.get_ticks_msec() + 6000
	while (RoamingSave.busy or RoamingSave.queued_sync) and Time.get_ticks_msec() < deadline: await frames(1)
	check(not RoamingSave.busy, "HTTP operation completes")
	await frames(2)

func mock_control(data: Dictionary) -> void:
	# This endpoint exists only on the local test server, never on the real cloud.
	if not RoamingSave.client.base_url.begins_with("http://127.0.0.1:"):
		push_error("Refusing non-local test fixture write")
		get_tree().quit(1)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request(RoamingSave.client.base_url + "/_test", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	var result: Array = await http.request_completed
	check(result[1] == 200, "Local mock fixture configured")
	http.queue_free()

func seed_remote(version: int, rounds: int) -> void:
	var data := {"rounds": rounds, "wins": 1, "best_stage": 2, "best_bankroll": 800}
	await mock_control({"seed": {"profile": RoamingSave.client.cloud_user("ala"), "value": RoamingSave._payload(data), "version": version}})

func sign_in(id: String) -> void:
	if not UserSession.primary.is_empty():
		UserSession.change_user()
		await frames()
	UserSession.pending_device = "keyboard"
	UserSession.login(id)
	await idle()

func modal_click(name: String) -> void:
	await frames(3) # Wait until the newly built modal has completed its layout.
	var button := RoamingSave.modal.find_child(name, true, false) as Button if is_instance_valid(RoamingSave.modal) else null
	if button == null:
		check(false, "Cloud button exists: " + name)
		return
	await click(button)

func save_from_menu() -> void:
	RoamingSave.show_panel()
	await frames()
	await modal_click("SaveCloud")
	await idle()

func run() -> void:
	Engine.max_fps = 120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-cloud="): phase = arg.trim_prefix("--verify-cloud=")
		if arg.begins_with("--cloud-output="): output = arg.trim_prefix("--cloud-output=")
	if not RoamingSave.client.base_url.begins_with("http://127.0.0.1:"):
		push_error("Cloud tests must use localhost")
		get_tree().quit(1)
		return
	await frames()
	var service := RoamingSave
	check(service.client.SPACE == "51796", "Correct album namespace 51796")
	check(service.decision(false, 0, false, false, 0) == "new", "Decision: both saves absent")
	check(service.decision(true, 0, true, false, 0) == "upload", "Decision: only local exists")
	check(service.decision(false, 0, false, true, 2) == "download", "Decision: only cloud exists")
	check(service.decision(true, 2, false, true, 2) == "same", "Decision: matching version and clean local")
	check(service.decision(true, 2, true, true, 2) == "upload", "Decision: pending local changes on unchanged cloud")
	check(service.decision(true, 2, false, true, 3) == "download", "Decision: clean local follows newer cloud")
	check(service.decision(true, 2, true, true, 3) == "conflict", "Decision: both sides changed")
	check(service.decision(true, 3, false, true, 2) == "older_server", "Decision: older server cannot silently replace local")
	await sign_in("ala")
	var path := UserSession.profiles_dir.path_join("ala.json")
	check(service.client.path_for("ala").ends_with("/51796/Ala/save"), "Cloud URL uses the profile name instead of the local ID")
	if phase == "read":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UserSession.profiles_dir.path_join("expected.json")))
		check(service._normalized(UserSession.progress) == service._normalized(expected.progress), "Restart restores cleared local progress from cloud")
		check(service.record.cloud.base_version == expected.version and not service.record.cloud.dirty, "Restored cloud version persists cleanly")
		check(FileAccess.file_exists(path), "Cloud restore recreates local save")
		check(service.client.post_count == 0, "Restoring from cloud never uploads")
		await screenshot("restored")
		await sign_in(str(UserSession.profiles.back().id))
		var earned := Achievements.Catalog.earned(UserSession.progress)
		check("natural_blackjack" in earned and "three_trinkets" in earned, "Achievement events survive restart and cloud restore")
		check("ten_rounds" in earned, "Counter achievement survives restart and cloud restore")
		check(not Achievements.notice.visible and service.client.post_count == 0, "Restored achievements do not replay notices or upload")
	else:
		check(service.record.is_empty(), "Fresh profile does not create an empty pending save")
		check(service.client.post_count == 0, "Login does not write to cloud")
		await service.save_clicked()
		check(service.client.post_count == 0, "An empty save cannot upload")
		UserSession.record_round(true, 2, 600)
		check(service.record.cloud.dirty and service.record.cloud.base_version == 0, "Local save carries dirty flag and base version")
		check(FileAccess.file_exists(path) and service.client.post_count == 0, "Saving locally requires no cloud write")
		service.show_panel()
		await frames()
		await screenshot("save-panel")
		check(service.client.post_count == 0, "Opening the cloud panel does not write")
		await modal_click("CloseCloud")
		check(service.client.post_count == 0 and service.record.cloud.dirty, "Closing the panel leaves changes local")
		await save_from_menu()
		check(service.client.post_count == 1 and service.record.cloud.base_version == 1 and not service.record.cloud.dirty, "One Save click sends one write without a confirmation dialog")
		check(not is_instance_valid(service.modal), "Successful Save closes the panel without extra confirmation")
		await service.save_clicked()
		check(service.client.post_count == 1, "Unchanged synchronized progress cannot create redundant writes")
		await key(KEY_F9)
		var requests_before: int = service.client.request_count
		UserSession.record_round(false, 2, 700)
		check(service.record.cloud.dirty and service.record.cloud.base_version == 1, "Offline progress persists without changing base version")
		await service.synchronize()
		check(service.client.request_count == requests_before, "Offline mode makes no HTTP requests")
		await key(KEY_F9)
		await idle()
		check(service.client.post_count == 1 and service.record.cloud.dirty, "Network return reads cloud but waits for Save click")
		await save_from_menu()
		check(service.record.cloud.base_version == 2 and not service.record.cloud.dirty, "Save click synchronizes pending offline changes")
		# Unrelated clock changes do not participate in decision logic.
		UserSession.record_round(false, 2, 700)
		service.record.cloud.saved_at = 1
		service._persist(service.record)
		await seed_remote(3, 40)
		await service.synchronize()
		check(is_instance_valid(service.modal) and service.status == "LOC_CLOUD_CONFLICT", "Independent changes open conflict choice despite clock skew")
		await screenshot("conflict")
		await modal_click("KeepCloud")
		check(UserSession.progress.rounds == 40 and service.record.cloud.base_version == 3 and not service.record.cloud.dirty, "Keep Cloud adopts server progress and version")
		check(FileAccess.file_exists(UserSession.profiles_dir.path_join("ala.conflict-local.json")), "Conflict keeps backup of discarded local progress")
		UserSession.record_round(false, 2, 800)
		await seed_remote(4, 50)
		await service.synchronize()
		var posts_before: int = service.client.post_count
		await seed_remote(5, 60)
		await modal_click("KeepLocal")
		await idle()
		check(service.client.post_count == posts_before + 1 and int(service.remote.version) == 5 and service.record.cloud.dirty, "HTTP 409 preserves local changes and newer cloud")
		check(is_instance_valid(service.modal), "HTTP 409 returns to conflict choice without retry")
		await modal_click("KeepLocal")
		await idle()
		check(service.record.cloud.base_version == 6 and UserSession.progress.rounds == 41, "Keep Local saves directly against the latest selected server version")
		# A later local save must survive completion of an older saved snapshot.
		UserSession.record_round(false, 2, 800)
		await mock_control({"delay_post": 0.15})
		service.show_panel()
		await frames()
		await modal_click("SaveCloud")
		UserSession.record_round(false, 2, 800)
		await idle()
		check(service.record.cloud.base_version == 7 and service.record.cloud.dirty and UserSession.progress.rounds == 43, "In-flight response cannot erase later local changes")
		await mock_control({"delay_post": 0})
		await save_from_menu()
		check(service.record.cloud.base_version == 8 and not service.record.cloud.dirty, "Later changes are sent by another Save click")
		var ala_saved := FileAccess.get_file_as_string(path)
		await sign_in("olek")
		check(UserSession.progress.rounds == 0 and service.record.is_empty(), "Olek has an independent cloud key")
		UserSession.record_round(false, 1, 500)
		await save_from_menu()
		check(service.record.cloud.base_version == 1, "Other profile starts its own server version sequence")
		check(FileAccess.get_file_as_string(path) == ala_saved, "Other profile never overwrites Ala's local save")
		await mock_control({"delay_get": 0.15})
		service.synchronize()
		UserSession.change_user()
		await frames()
		UserSession.login("ala")
		await idle()
		check(UserSession.progress.rounds == 43 and service.profile_id == "ala", "Late response for previous profile cannot overwrite current user's data")
		await mock_control({"delay_get": 0})
		check(UserSession.progress.rounds == 43 and service.record.cloud.base_version == 8, "Switching back reloads the correct profile")
		check(UserSession.create_profile("malykamis").is_empty(), "Create named profile for cloud migration test")
		var named_id := str(UserSession.profiles.back().id)
		check(service.client.path_for(named_id).ends_with("/51796/malykamis/save"), "New random local IDs resolve to the name malykamis in cloud")
		var migration_progress := {"rounds": 9, "wins": 2, "best_stage": 2, "best_bankroll": 900}
		await mock_control({"seed": {"profile": named_id, "value": service._payload(migration_progress), "version": 2}})
		var posts_before_migration: int = service.client.post_count
		await sign_in(named_id)
		check(UserSession.progress.rounds == 9 and service.record.cloud.base_version == 0 and service.record.cloud.dirty, "Legacy ID save is restored locally with a new name-key version base")
		check(service.client.post_count == posts_before_migration, "Legacy discovery never writes or deletes cloud data automatically")
		await save_from_menu()
		check(service.record.cloud.base_version == 1 and service.record.cloud.user_key == "malykamis" and not service.record.cloud.dirty, "Save click migrates progress to the named cloud key")
		var old: Dictionary = await service.client.load_legacy_save(named_id)
		check(old.get("found", false) and int(old.get("version", 0)) == 2, "Migrating keeps the previous remote save unchanged")
		await sign_in("ala")
		var expected := {"progress": UserSession.progress.duplicate(), "version": int(service.record.cloud.base_version)}
		UserSession._write_json(UserSession.profiles_dir.path_join("expected.json"), expected)
		var no_more_writes: int = service.client.post_count
		service.show_clear_confirmation()
		await frames()
		await modal_click("ConfirmClearLocal")
		check(not FileAccess.file_exists(path), "Clear Local removes only active local save")
		check(FileAccess.file_exists(UserSession.profiles_dir.path_join("ala.cleared-backup.json")), "Clear Local preserves a local backup")
		check(service.client.post_count == no_more_writes, "Clear Local never deletes or writes cloud data")
		await key(KEY_F8)
		check(not FileAccess.file_exists(path), "Logout does not recreate empty local progress after Clear Local")
		await verify_achievements(named_id)
	await finish()

func verify_achievements(id: String) -> void:
	await sign_in(id)
	await click(get_tree().current_scene.get_node("Achievements"))
	var screen := get_tree().current_scene
	var secret := screen.find_child("natural_blackjack", true, false)
	check(secret.find_child("Title", true, false).text == "LOC_ACH_HIDDEN", "Locked secret hides its name")
	check(screen.find_child("ten_rounds", true, false).find_child("State", true, false).text == "9 / 10", "Achievement screen displays counter progress")
	await click(screen.find_child("Back", true, false))
	var posts: int = RoamingSave.client.post_count
	await click(get_tree().current_scene.get_node("Play"))
	var game := get_tree().current_scene
	game.change_bet(10)
	game.on_deal()
	game.round_timer.stop()
	game.player_cards.assign([0, 9])
	game.dealer_cards.assign([8, 7])
	game.check_winner()
	var earned := Achievements.Catalog.earned(UserSession.progress)
	check("natural_blackjack" in earned and "ten_rounds" in earned, "One resolved round unlocks the event and counter achievements")
	check(Achievements.notice.visible and Achievements.pending.size() == 1, "Simultaneous awards are queued for display")
	check(RoamingSave.client.post_count == posts, "Achievement unlocks do not write to cloud automatically")
	var revision := int(RoamingSave.record.cloud.revision)
	Achievements.grant("natural_blackjack")
	check(int(RoamingSave.record.cloud.revision) == revision and Achievements.pending.size() == 1, "Repeated grant does not save or notify twice")
	for index in range(3):
		var item: TrinketDef = TrinketDb.trinkets[index]
		inventory.add_trinket(item)
		inventory.equip(item)
	check("three_trinkets" in Achievements.Catalog.earned(UserSession.progress), "Equipping three distinct items unlocks the collection achievement")
	var all_events := {"rounds": 10, "wins": 5, "best_stage": 3, "achievements": ["split", "three_trinkets", "natural_blackjack", "victory"]}
	check("completion" in Achievements.Catalog.earned(all_events), "Completion requires every other achievement")
	await get_tree().create_timer(1.15).timeout
	game.change_bet(10)
	game.on_deal()
	game.round_timer.stop()
	game.player_cards.assign([8, 21])
	game._on_split_button_pressed()
	check("split" in Achievements.Catalog.earned(UserSession.progress), "Using a legal split unlocks its achievement")
	await key(KEY_F8)
	check(not Achievements.notice.visible and Achievements.pending.is_empty(), "Logout clears queued notifications")
	await sign_in(id)
	await click(get_tree().current_scene.get_node("Achievements"))
	screen = get_tree().current_scene
	secret = screen.find_child("natural_blackjack", true, false)
	check(secret.find_child("Title", true, false).text == "LOC_ACH_BLACKJACK", "Unlocked secret displays its name")
	await screenshot("achievements")
	await click(screen.find_child("Back", true, false))
	var merged_progress := UserSession.progress.duplicate(true)
	var cloud_progress := {"achievements": ["victory"]}
	check(RoamingSave._merge_event_achievements(merged_progress, cloud_progress) and "victory" in merged_progress.achievements and "natural_blackjack" in merged_progress.achievements, "Cloud conflict union preserves both sets of event achievements")
	await save_from_menu()
	check(RoamingSave.client.post_count == posts + 1, "One explicit save uploads the earned achievements")
	RoamingSave.clear_local()
	await sign_in("olek")
	check("natural_blackjack" not in Achievements.Catalog.earned(UserSession.progress), "Achievements remain isolated across profiles")

func finish() -> void:
	service_cleanup()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "phase": phase, "checks": results, "real_cloud_writes": 0, "transport": RoamingSave.client.base_url}, "\t"))
	file.close()
	print("CLOUD_CHECK_" + ("FAILED" if failed else "OK") + ": " + str(results.size()))
	if failed: get_tree().quit(1)
	else: await PCRuntime._quit_cleanly()

func service_cleanup() -> void:
	RoamingSave.close_modal()
