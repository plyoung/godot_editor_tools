@tool
extends ConfirmationDialog

@onready var PrefabsPathEd : LineEdit = %PrefabsPathEdit
@onready var MaterialsPathEd : LineEdit = %MaterialsPathEdit
@onready var TexturesPathEd : LineEdit = %TexturesPathEdit
@onready var PrefabsPathButton : Button = %PrefabsPathButton
@onready var MaterialsPathButton : Button = %MaterialsPathButton
@onready var TexturesPathButton : Button = %TexturesPathButton

var file_dialog: EditorFileDialog
var fabs_path : String
var mats_path : String
var text_path : String

# ----------------------------------------------------------------------------------------------------------------------
#region system and ui

func _ready() -> void:
	var icon := get_theme_icon("Load", "EditorIcons")
	PrefabsPathButton.icon = icon
	MaterialsPathButton.icon = icon
	TexturesPathButton.icon = icon
	PrefabsPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): PrefabsPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	MaterialsPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): MaterialsPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	TexturesPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): TexturesPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
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
	mats_path = MaterialsPathEd.text
	text_path = TexturesPathEd.text	
	var fabs_dir : DirAccess = null if fabs_path.is_empty() else DirAccess.open(fabs_path)
	if fabs_dir == null:
		printerr("Invalid prefabs path")
		return false
	if not mats_path.is_empty():
		var mats_dir = DirAccess.open(mats_path)
		if mats_dir == null:
			printerr("Invalid materials path")
			return false
	if not text_path.is_empty():
		var text_dir = DirAccess.open(text_path)
		if text_dir == null:
			printerr("Invalid textures path")
			return false
	return true


func _process_selection() -> void:
	var paths := EditorInterface.get_selected_paths()
	for path in paths: _process_file(path)


func _process_file(path: String) -> void:
	# do not continue if prefab already exist
	var prefab_path := fabs_path.path_join(path.get_file().get_basename() + ".tscn")
	if ResourceLoader.exists(prefab_path):
		print("Skipped, file exist: %s" % prefab_path)
		return
	
	# load and check that is it a packedscene
	var model = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if model == null: return
	var new_scene := model.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	
	# process the scene materials
	if not mats_path.is_empty():
		_process_node(new_scene, path)
	
	# save new scene/prefab
	var prefab := PackedScene.new()
	var result := prefab.pack(new_scene)
	if result == OK:
		result = ResourceSaver.save(prefab, prefab_path)
		if result != OK: printerr("An error occurred while saving the scene to disk.")
	else:
		printerr("An error occurred while packing scene.")


func _process_node(node: Node, model_path: String) -> void:
	if not node: return
	var meshinstance := node as MeshInstance3D
	if meshinstance:
		var mesh := meshinstance.mesh
		for i in mesh.get_surface_count():
			var sourcemat := mesh.surface_get_material(i)
			# skip if already pointing to extern material. will start with packedscene's path if not pointing to extern material
			if not sourcemat.resource_path.is_empty() and not sourcemat.resource_path.contains(model_path): continue
 			# get or create material and set the mesh to use it
			var filename := sourcemat.resource_name.validate_filename() + ".tres"
			var path := mats_path.path_join(filename)
			var newmat := _get_or_create_material(sourcemat, path)
			mesh.surface_set_material(i, newmat)
	# process children too
	for n in node.get_children():
		_process_node(n, model_path)


func _get_or_create_material(source: Material, path: String) -> Material:
	if ResourceLoader.exists(path):
		var material := ResourceLoader.load(path) as Material
		if material: 
			return material
		else:
			printerr("Failed to load material: %s" % path)
			return source
	# make duplicate of original to mess with
	var material := source.duplicate()
	_update_material(material)
	# save and return it
	var error := ResourceSaver.save(material, path)
	if error == OK: return material
	printerr("Could not save material: %s", path)
	return source


func _update_material(mat: Material) -> void:
	# try to set the textures of the material, only if tetures path provided
	if text_path.is_empty(): return
	# TODO
	pass


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

#func _export_material(dir: String, file_path: String) -> void:
	#if file_path.get_extension().to_lower() != "glb": return
	#var gltf_doc = GLTFDocument.new()
	#var gltf_state = GLTFState.new()
	#var error = gltf_doc.append_from_file(file_path, gltf_state)
	#if error != OK:
		#print("%s > Couldn't load glTF: %s" % [error_string(error), file_path])
		#return
	#var mats := gltf_state.get_materials()
	#var new_mats : Array[Material]
	#for mat in mats:		
		#if mat.resource_name.is_empty():
			#print("Material name invalid in: ", file_path)
			#continue
		#var mat_path := dir.path_join(mat.resource_name + ".tres")
		#if ResourceLoader.exists(mat_path):
			#print("Using existing material: ", mat_path)
		#else:
			#print("Saving material: ", mat_path)
			#error = ResourceSaver.save(mat, mat_path)
			#if error != OK:
				#print("%s > Couldn't save Material: %s" % [error_string(error), mat_path])
				#continue
