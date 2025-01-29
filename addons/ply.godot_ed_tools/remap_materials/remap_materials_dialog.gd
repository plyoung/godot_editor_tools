@tool
extends ConfirmationDialog

@onready var MatPathEd : LineEdit = %MatPathEd
@onready var MatPathButton : Button = %MatPathButton
@onready var MatNameEd : LineEdit = %MatNameEd
@onready var MatNameLabel : Label = %MatNameLabel
@onready var MatMatchOption : OptionButton = %MatMatchOption

@onready var changed_scene_files := PackedStringArray()

var find_mat : String
var mat_path : String
var file_dialog: EditorFileDialog
var slot := -1

# ----------------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	var icon := get_theme_icon("Load", "EditorIcons")
	MatPathButton.icon = icon
	MatPathButton.pressed.connect(_show_file_dialog)
	MatMatchOption.item_selected.connect(_on_match_option_selected)
	confirmed.connect(_on_confirmation)


func _exit_tree() -> void:
	_close_file_dialog()


func _on_match_option_selected(index: int) -> void:
	if index <= 0:
		MatNameLabel.text = "Name of material:"
		MatNameEd.text = ""
	else:
		MatNameLabel.text = "Material index/slot:"
		MatNameEd.text = "0"


func _on_confirmation() -> void:
	changed_scene_files.clear()
	
	mat_path = MatPathEd.text
	if ResourceLoader.exists(mat_path, "BaseMaterial3D"):
		# rather use the UID as path if one exists
		var uid := ResourceLoader.get_resource_uid(mat_path)
		if uid >= 0 and ResourceUID.has_id(uid):
			mat_path = ResourceUID.id_to_text(uid)
	else:
		printerr("Invalid material path: ", mat_path)
		return
	
	find_mat = MatNameEd.text.to_lower()
	if MatMatchOption.selected <= 0:
		slot = -1
		if find_mat.length() == 0:
			printerr("No material name specified")
			return
	else:
		slot = find_mat.to_int()
		MatNameEd.text = str(slot)
		if slot < 0:
			printerr("Invalid slot/index specified")
			return
	
	var paths := EditorInterface.get_selected_paths()
	for path in paths:
		_process_file(path)
	
	if changed_scene_files.size() > 0:
		var rfs := EditorInterface.get_resource_filesystem()
		rfs.reimport_files(changed_scene_files)


func _process_file(model_path: String) -> void:
	# load and check that is it a packedscene
	if not ResourceLoader.exists(model_path, "PackedScene"):
		return
	var model := ResourceLoader.load(model_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if model == null or not model.can_instantiate(): return
	
	# open the .import file since it is used to make changes
	var import_path := model_path + ".import"
	if not FileAccess.file_exists(import_path):
		# if no import file then perhaps a scene file
		_process_prefab(model_path, model) #printerr("Could not load: %s" % import_path)
		return
	
	var config := ConfigFile.new()
	var result := config.load(import_path)
	if result != OK:
		printerr("Could not load: %s" % import_path)
		return

	var materials_paths := Array()
	
	# remap by name
	if slot < 0:
		# get list of where the material name is used if matching by name
		var parent_node := model.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		_process_node(parent_node, materials_paths)
		parent_node.queue_free()
		
	# remap by slot/index
	else:
		# else, use "@MATERIAL:0" pattern as name to set material slot
		materials_paths.append("@MATERIAL:%s" % slot)
	
	if materials_paths.size() > 0:
		var subres := config.get_value("params", "_subresources", Dictionary()) as Dictionary
		if not subres.has("materials"): subres["materials"] = Dictionary()
		var subres_mats : Dictionary = subres["materials"]
		for origin_mat in materials_paths:
			subres_mats[origin_mat] = { "use_external/enabled": true, "use_external/path": mat_path }
		
		result = config.save(import_path)
		if result == OK: changed_scene_files.append(model_path)
		else: printerr("Could not save: %s" % import_path)


func _process_prefab(prefab_path: String, prefab : PackedScene) -> void:
	# will need material instance
	var mat = ResourceLoader.load(mat_path) as Material
	if not mat:
		printerr("Could not load material: %s" % mat_path)
		return
	
	# instantiate prefab so that is can be modified
	var scene = prefab.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if not scene:
		printerr("Could not instantiate to process: %s" % prefab_path)
		return
	
	var todo : Array
	todo.append(scene)
	while todo.size() > 0:
		var node = todo.pop_back() as Node3D
		if not node: continue
		for n in node.get_children(): todo.append(n)
		var meshinstance = node as MeshInstance3D
		if not meshinstance: continue
		if slot >= 0: # slot method, just override
			if slot < meshinstance.get_surface_override_material_count():
				meshinstance.set_surface_override_material(slot, mat)
		else: # mat name method, must first check if has named mat on a mesh
			var mesh = meshinstance.mesh
			if not mesh: continue
			var count = mesh.get_surface_count()
			var override_count = meshinstance.get_surface_override_material_count()
			for i in count:
				if find_mat == mesh.surface_get_material(i).resource_name.to_lower() and i < override_count:
					meshinstance.set_surface_override_material(i, mat)
	
	# save/pack modifications into prefab
	var err = prefab.pack(scene)
	if err == OK:
		var result = ResourceSaver.save(prefab, prefab_path)
		if result != OK: printerr("An error occurred while saving the scene: ", prefab.resource_name)
	else:
		printerr("Could not process: %s" % prefab_path)
		printerr(" ... %s" % err)
	scene.queue_free()


func _process_node(node: Node, material_paths: Array) -> void:
	if not node: return
	var meshinstance := node as MeshInstance3D
	if meshinstance:
		var mesh := meshinstance.mesh
		for i in mesh.get_surface_count():
			var surface_name := mesh.get("surface_"+ str(i) +"/name") as String
			if surface_name and surface_name.to_lower().contains(find_mat) and not material_paths.has(surface_name): 
				material_paths.append(surface_name)
			#var sourcemat := mesh.surface_get_material(i) as BaseMaterial3D
			#if sourcemat and sourcemat.resource_name.to_lower().contains(find_mat) and not material_paths.has(sourcemat.resource_name): 
			#	material_paths.append(sourcemat.resource_name)
	# process children too
	for n in node.get_children():
		_process_node(n, material_paths)


# ----------------------------------------------------------------------------------------------------------------------

func _close_file_dialog() -> void:
	if file_dialog: 
		file_dialog.queue_free()
		file_dialog = null


func _show_file_dialog() -> void:
	if file_dialog: _close_file_dialog()
	file_dialog = EditorFileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.display_mode = EditorFileDialog.DISPLAY_LIST
	file_dialog.filters = PackedStringArray(["*.tres ; Materials"])
	file_dialog.file_selected.connect(func(path: String): MatPathEd.text = path)
	file_dialog.popup_centered(Vector2i(800, 600))


# ----------------------------------------------------------------------------------------------------------------------
