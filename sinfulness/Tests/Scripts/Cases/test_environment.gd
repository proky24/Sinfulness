extends TestCase
## Smoke test: things execute_code cannot reach work inside a test case.

const POTION_PATH: String = "res://GUI/PauseMenu/Inventory/Items/potion.tres"


func test_resource_loader_reachable() -> void:
	assert_true(ResourceLoader.exists(POTION_PATH), POTION_PATH)


func test_load_returns_item_data() -> void:
	var item: Resource = load(POTION_PATH)
	assert_true(item is ItemData, "potion.tres should load as ItemData")


func test_autoload_reachable() -> void:
	assert_not_null(get_autoload("GlobalPlayerManager"), "GlobalPlayerManager autoload")


func test_global_inventory_registered() -> void:
	if get_autoload("GlobalInventory") == null:
		skip("GlobalInventory is created in Phase 1")
		return
	assert_not_null(get_autoload("GlobalInventory"))


func test_await_works() -> void:
	var start_frame: int = Engine.get_process_frames()
	await wait_seconds(0.2)
	var frames: int = Engine.get_process_frames() - start_frame
	assert_true(frames > 0, "the test should resume on a later frame, resumed after %d frames" % frames)
