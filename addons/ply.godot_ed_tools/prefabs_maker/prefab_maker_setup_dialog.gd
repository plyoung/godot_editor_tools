@tool
extends ConfirmationDialog

@onready var SourcePathEd : LineEdit = %SourcePathEdit
@onready var SourcePathButton : Button = %SourcePathButton
@onready var PrefabsPathEd : LineEdit = %PrefabsPathEdit
@onready var PrefabsPathButton : Button = %PrefabsPathButton
@onready var NameCleanupEd : LineEdit = %NameCleanupEdit

@onready var name_cleanup_regex := RegEx.new()

var file_dialog: EditorFileDialog
var source_path : String
var fabs_path : String

const name_cleanup_settings_key := "addons/ply_editor_tools/prefabs_maker/name_cleanup"

# ----------------------------------------------------------------------------------------------------------------------
#region system and ui

func _ready() -> void:
	var icon := get_theme_icon("Load", "EditorIcons")
	SourcePathButton.icon = icon
	PrefabsPathButton.icon = icon
	SourcePathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): SourcePathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	PrefabsPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): PrefabsPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	confirmed.connect(_on_confirmation)


func _exit_tree() -> void:
	_close_file_dialog()


func _read_settings() -> void:
	NameCleanupEd.text = ProjectSettings.get_setting(name_cleanup_settings_key, "")


func _save_settings() -> void:
	ProjectSettings.set_setting(name_cleanup_settings_key, NameCleanupEd.text)


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region process

func _on_confirmation() -> void:	
	if not _check_directories(): return
	name_cleanup_regex.clear()
	if not NameCleanupEd.text.is_empty(): name_cleanup_regex.compile(NameCleanupEd.text)
	#_process_selection()
	_process_source_folder()


func _check_directories() -> bool:
	source_path = SourcePathEd.text
	fabs_path = PrefabsPathEd.text
	var source_dir : DirAccess = null if source_path.is_empty() else DirAccess.open(source_path)
	if source_dir == null:
		printerr("Invalid source path")
		return false
	var fabs_dir : DirAccess = null if fabs_path.is_empty() else DirAccess.open(fabs_path)
	if fabs_dir == null:
		printerr("Invalid prefabs path")
		return false
	return true


#func _process_selection() -> void:
	#var progress := PlyEditorToolz.show_progress_dialog()
	#progress.set_heading("Processing assets")
	#await get_tree().process_frame
	#
	#var paths := EditorInterface.get_selected_paths()
	#
	## if there is only one path and it is a directory then processing all
	## scenes and sub-directories of that directory and recreate the path 
	## structures in the target prefabs folder
	#
	#if paths.size() == 1 and not ResourceLoader.exists(paths[0]):
		#_process_selected_directory(paths[0], progress)
	#else:
		#_process_selected_paths(paths, progress)
	#
	#PlyEditorToolz.hide_progress_dialog()
	#EditorInterface.get_resource_filesystem().scan()

func _process_source_folder() -> void:
	var progress := PlyEditorToolz.show_progress_dialog()
	progress.set_heading("Processing assets")
	await get_tree().process_frame
	_process_selected_directory(source_path, progress)
	PlyEditorToolz.hide_progress_dialog()
	EditorInterface.get_resource_filesystem().scan()


func _process_selected_paths(paths : PackedStringArray, progress : PlyToolsProgressDialog) -> void:
	var step := 1.0 / len(paths)
	var prog := 0.0
	for i in len(paths):
		var path = paths[i]
		prog += step
		progress.set_message(path)
		progress.set_progress(prog)
		await get_tree().process_frame
		_process_file(path, fabs_path)


func _process_selected_directory(models_root : String, progress : PlyToolsProgressDialog) -> void:
	var dir = DirAccess.open(models_root)
	if not dir:
		printerr("Could not open directory: ", models_root)
		return
		
	var folders_todo : Array[String]
	folders_todo.append(models_root)
	while folders_todo.size() > 0:
		var root := folders_todo.pop_front() as String
		var target_path := fabs_path.path_join(root.substr(models_root.length()))
		dir.change_dir(root)
		dir.list_dir_begin()
		var nm := dir.get_next()
		while nm:
			if dir.current_is_dir():
				folders_todo.append(root.path_join(nm))
			else:
				var res := OK
				if not dir.dir_exists(target_path):
					res = dir.make_dir_recursive(target_path)
					if res != OK: printerr("Could not create path: ", target_path)
				if res == OK:
					_process_file(root.path_join(nm), target_path)
			nm = dir.get_next()
		dir.list_dir_end()


func _process_file(path: String, fab_root: String) -> void:
	# load and check that is it a packedscene
	if path.get_extension() == "import":
		#print("Skipped: ", path)
		return
		
	var source = ResourceLoader.load(path) as PackedScene
	if source == null: 
		print("Skipped: ", path)
		return
	
	# get the clean name
	var name := path.get_file().get_basename()
	if name_cleanup_regex.is_valid(): name = name_cleanup_regex.sub(name, "", true)
	
	# do not continue if prefab already exist
	var prefab_path := fab_root.path_join(name + ".tscn")
	if ResourceLoader.exists(prefab_path):
		print("Skipped, file exist: %s" % prefab_path)
		return
	
	var prefab := _create_inherited_scene(source, name)
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
