@tool
extends ConfirmationDialog

@onready var PrefabsPathEd : LineEdit = %PrefabsPathEdit
@onready var PrefabsPathButton : Button = %PrefabsPathButton

var file_dialog: EditorFileDialog
var fabs_path : String

# ----------------------------------------------------------------------------------------------------------------------
#region system and ui

func _ready() -> void:
	var icon := get_theme_icon("Load", "EditorIcons")
	PrefabsPathButton.icon = icon
	PrefabsPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): PrefabsPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	confirmed.connect(_on_confirmation)


func _exit_tree() -> void:
	_close_file_dialog()


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region process

func _on_confirmation() -> void:
	if not _check_directories(): return
	_process_selection()


func _check_directories() -> bool:
	fabs_path = PrefabsPathEd.text
	var fabs_dir : DirAccess = null if fabs_path.is_empty() else DirAccess.open(fabs_path)
	if fabs_dir == null:
		printerr("Invalid prefabs path")
		return false
	return true


func _process_selection() -> void:
	var progress := PlyEditorToolz.show_progress_dialog()
	progress.set_heading("Processing assets")
	await get_tree().process_frame
	
	var paths := EditorInterface.get_selected_paths()
	var step := 1.0 / len(paths)
	var prog := 0.0
	for i in len(paths):
		var path = paths[i]
		prog += step
		progress.set_message(path)
		progress.set_progress(prog)
		await get_tree().process_frame
		_process_file(path)
		
	PlyEditorToolz.hide_progress_dialog()


func _process_file(path: String) -> void:
	# do not continue if prefab already exist
	var prefab_path := fabs_path.path_join(path.get_file().get_basename() + ".tscn")
	if ResourceLoader.exists(prefab_path):
		print("Skipped, file exist: %s" % prefab_path)
		return
	
	# load and check that is it a packedscene
	var source = ResourceLoader.load(path) as PackedScene
	if source == null: return
	var prefab := _create_inherited_scene(source)
	var result = ResourceSaver.save(prefab, prefab_path)
	if result != OK: printerr("An error occurred while saving the scene to disk: ", prefab.resource_name)


func _create_inherited_scene(inherits: PackedScene, root_name := "") -> PackedScene:
	if(root_name == ""):
		root_name = inherits._bundled["names"][0];
	var scene := PackedScene.new()
	var bundled := scene._bundled
	bundled["names"] = [ root_name ]
	bundled["variants"] = [ inherits ]
	bundled["node_count"] = 1
	bundled["nodes"] = [-1, -1, 2147483647, 0, -1, 0, 0] # magic
	bundled["base_scene"] = 0 # more magic
	scene._bundled = bundled
	return scene


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region file dialog

func _close_file_dialog() -> void:
	if file_dialog: 
		file_dialog.queue_free()
		file_dialog = null


func _show_file_dialog(callback : Callable, file_mode: EditorFileDialog.FileMode, acces: EditorFileDialog.Access) -> void:
	if file_dialog: _close_file_dialog()
	file_dialog = EditorFileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = file_mode
	file_dialog.access = acces
	file_dialog.display_mode = EditorFileDialog.DISPLAY_LIST
	file_dialog.dir_selected.connect(callback)
	file_dialog.popup_centered(Vector2i(800, 600))


#endregion
# ----------------------------------------------------------------------------------------------------------------------
