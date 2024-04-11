@tool
extends ConfirmationDialog

@onready var MaterialsPathEd : LineEdit = %MaterialsPathEdit
@onready var TexturesPathEd : LineEdit = %TexturesPathEdit
@onready var MaterialsPathButton : Button = %MaterialsPathButton
@onready var TexturesPathButton : Button = %TexturesPathButton
@onready var OverrideMatsCheck : CheckBox = %OverrideMatsCheck
@onready var ForceUpdateScenesCheck : CheckBox = %ForceUpdateScenesCheck
@onready var AlbedoMapEd : LineEdit = %AlbedoMapEdit
@onready var NormalMapEd : LineEdit = %NormalMapEdit
@onready var MetallicMapEd : LineEdit = %MetallicMapEdit
@onready var RoughnessMapEd : LineEdit = %RoughnessMapEdit
@onready var AOcclusionMapEd : LineEdit = %AOcclusionMapEdit
@onready var MatNameCleanupEd : LineEdit = %MatNameCleanupEdit
@onready var TexNameCleanupEd : LineEdit = %TexNameCleanupEdit

@onready var albedo_tag_regex := RegEx.new()
@onready var normal_tag_regex := RegEx.new()
@onready var metallic_tag_regex := RegEx.new()
@onready var roughness_tag_regex := RegEx.new()
@onready var aocclusion_tag_regex := RegEx.new()
@onready var matname_cleanup_regex := RegEx.new()
@onready var texname_cleanup_regex := RegEx.new()
@onready var search_regex := RegEx.new()
@onready var split_regex := RegEx.new()

@onready var textures := Dictionary()
@onready var changed_files := PackedStringArray()
@onready var changed_material_paths := PackedStringArray()

var file_dialog: EditorFileDialog
var mats_path : String
var texs_path : String

# ----------------------------------------------------------------------------------------------------------------------

class TexturePaths:
	var albedo : Texture2D
	var normal : Texture2D
	var metallic : Texture2D
	var roughness : Texture2D
	var aocclusion : Texture2D

class TextureMatch:
	var key : String
	var weight : int

# ----------------------------------------------------------------------------------------------------------------------
#region system and ui

func _ready() -> void:
	var icon := get_theme_icon("Load", "EditorIcons")
	MaterialsPathButton.icon = icon
	TexturesPathButton.icon = icon
	MaterialsPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): MaterialsPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	TexturesPathButton.pressed.connect(func(): _show_file_dialog(func(dir: String): TexturesPathEd.text = dir, EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES))
	confirmed.connect(_on_confirmation)
	split_regex.compile("([a-zA-Z0-9]+)")


func _exit_tree() -> void:
	_close_file_dialog()


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region process

func _on_confirmation() -> void:
	changed_files.clear()
	changed_material_paths.clear()
	albedo_tag_regex.clear()
	normal_tag_regex.clear()
	metallic_tag_regex.clear()
	roughness_tag_regex.clear()
	aocclusion_tag_regex.clear()
	matname_cleanup_regex.clear()
	texname_cleanup_regex.clear()
	if not AlbedoMapEd.text.is_empty(): albedo_tag_regex.compile(AlbedoMapEd.text)
	if not NormalMapEd.text.is_empty(): normal_tag_regex.compile(NormalMapEd.text)
	if not MetallicMapEd.text.is_empty(): metallic_tag_regex.compile(MetallicMapEd.text)
	if not RoughnessMapEd.text.is_empty(): roughness_tag_regex.compile(RoughnessMapEd.text)
	if not AOcclusionMapEd.text.is_empty(): aocclusion_tag_regex.compile(AOcclusionMapEd.text)
	if not MatNameCleanupEd.text.is_empty(): matname_cleanup_regex.compile(MatNameCleanupEd.text)
	if not TexNameCleanupEd.text.is_empty(): texname_cleanup_regex.compile(TexNameCleanupEd.text)
	
	if not _check_directories(): return
	_process_selected_files()


func _check_directories() -> bool:
	mats_path = MaterialsPathEd.text
	texs_path = TexturesPathEd.text	
	var mats_dir : DirAccess = null if mats_path.is_empty() else DirAccess.open(mats_path)
	if mats_dir == null:
		printerr("Invalid materials path")
		return false
	if not texs_path.is_empty():
		var text_dir = DirAccess.open(texs_path)
		if text_dir == null:
			printerr("Invalid textures path")
			return false
		else:
			_collect_textures(text_dir)
	return true


func _process_selected_files() -> void:
	var paths := EditorInterface.get_selected_paths()
	for path in paths: _process_file(path)	
	EditorInterface.get_resource_filesystem().reimport_files(changed_files)


func _process_file(path: String) -> void:
	# load and check that is it a packedscene
	var model = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if model == null: return
	var new_scene := model.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	
	# process the scene materials
	var extracted_materials := Dictionary()
	_process_node(new_scene, extracted_materials)
	
	# update the import settings with exported materials
	if extracted_materials.is_empty(): return
	_update_import_file(path, extracted_materials)


func _update_import_file(scene_path: String, extracted_materials: Dictionary) -> void:
	var path := scene_path + ".import"
	if not FileAccess.file_exists(path): 
		printerr("Could not find: %s" % path)
		return
		
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK:
		printerr("Could not load: %s" % path)
		return
		
	var subres := config.get_value("params", "_subresources", Dictionary()) as Dictionary
	if not subres.has("materials"): subres["materials"] = Dictionary()
	var subres_mats : Dictionary = subres["materials"]
	for mat in extracted_materials:
		if ForceUpdateScenesCheck.button_pressed or not subres_mats.has(mat): 
			subres_mats[mat] = { "use_external/enabled": true, "use_external/path": extracted_materials[mat] }
		
	result = config.save(path)
	if result == OK: changed_files.append(scene_path)
	else: printerr("Could not save: %s" % path)


func _process_node(node: Node, extracted_materials: Dictionary) -> void:
	if not node: return
	var meshinstance := node as MeshInstance3D
	if meshinstance:
		var mesh := meshinstance.mesh
		for i in mesh.get_surface_count():
			var sourcemat := mesh.surface_get_material(i) as BaseMaterial3D
			var newmat_path := _get_or_create_exported_material(sourcemat)
			if not newmat_path.is_empty():
				if not extracted_materials.has(sourcemat.resource_name):
					extracted_materials[sourcemat.resource_name] = newmat_path
	# process children too
	for n in node.get_children():
		_process_node(n, extracted_materials)


func _get_or_create_exported_material(sourcemat: BaseMaterial3D) -> String:
	if not sourcemat or sourcemat.resource_name.is_empty(): return ""
	var filename := sourcemat.resource_name.validate_filename() + ".tres"
	var path := mats_path.path_join(filename)
	if not OverrideMatsCheck.button_pressed and ResourceLoader.exists(path):
		var material := ResourceLoader.load(path) as BaseMaterial3D
		if material: return path
	
	# make duplicate of original to mess with
	var material := sourcemat.duplicate()
	_update_material(material, filename)
	var error := ResourceSaver.save(material, path)
	if error == OK:
		EditorInterface.get_resource_filesystem().update_file(path)
		return path
		
	printerr("Could not save material: %s", path)
	return ""


func _update_material(material: BaseMaterial3D, mat_filename: String) -> void:
	if texs_path.is_empty() or not material: return
	
	# get clean material name
	var mat_name := mat_filename.get_basename()
	if mat_name.is_empty(): mat_name = material.resource_name
	mat_name = mat_name.to_lower()
	if matname_cleanup_regex.is_valid(): mat_name = matname_cleanup_regex.sub(mat_name, "", true)

	# first use normal string comparison to find textures
	for key in textures:
		if key == mat_name:
			_set_material_textures(material, key)
			return

	# split the material name into parts and build search regex from it	
	var pattern := _build_search_pattern(mat_name)
	if pattern.is_empty():
		print("Could not find textures for: ", mat_filename)
		return
	search_regex.clear()
	search_regex.compile(pattern)
	if not search_regex.is_valid(): 
		print("Could not find textures for: ", mat_filename)
		return
	
	# search
	var matches : Array[TextureMatch] = []
	for key in textures:
		var results = search_regex.search_all(key)
		if results.size() > 0:
			var m := TextureMatch.new()
			m.key = key
			m.weight = results.size()
			matches.append(m)
	
	# sort and use highest weight and shortest name among those
	if matches.size() == 0:
		print("Could not find textures for: ", mat_filename)
		return
	matches.sort_custom(func(a, b): return a.weight > b.weight or (a.weight == b.weight and a.key.length() < b.key.length()))
	_set_material_textures(material, matches[0].key)


func _set_material_textures(material: StandardMaterial3D, key: String) -> void:
	var paths : TexturePaths = textures[key]
	#print("Set: %s with texture key: %s (albedo: %s)" % [material.resource_name, key, paths.albedo])
	if paths.albedo and not material.albedo_texture:
		material.albedo_texture = paths.albedo
	if paths.metallic and not material.metallic_texture: 
		material.metallic_texture = paths.metallic
	if paths.roughness and not material.roughness_texture: 
		material.roughness_texture = paths.roughness
	if paths.normal and not material.normal_texture: 
		material.normal_enabled = true
		material.normal_texture = paths.normal
	if paths.aocclusion and not material.ao_texture: 
		material.ao_enabled = true
		material.ao_texture = paths.aocclusion


func _collect_textures(dir : DirAccess) -> void:
	textures.clear()
	if texs_path.is_empty(): return
	var extensions := ResourceLoader.get_recognized_extensions_for_type("Texture")
	dir.list_dir_begin()
	var file_name : String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		var path := texs_path.path_join(file_name)
		file_name = file_name.to_lower()
		if extensions.has(file_name.get_extension()):
			var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
			if not texture:
				file_name = dir.get_next()
				continue
			file_name = file_name.get_basename()
			var key := file_name
			if texname_cleanup_regex.is_valid(): key = texname_cleanup_regex.sub(key, "", true)
			var entry := textures.get(key, null) as TexturePaths
			if not entry:
				entry = TexturePaths.new()
				textures[key] = entry
			if not entry.albedo and albedo_tag_regex.is_valid() and albedo_tag_regex.search(file_name): entry.albedo = texture
			elif not entry.normal and normal_tag_regex.is_valid() and normal_tag_regex.search(file_name): entry.normal = texture
			elif not entry.metallic and metallic_tag_regex.is_valid() and metallic_tag_regex.search(file_name): entry.metallic = texture
			elif not entry.roughness and roughness_tag_regex.is_valid() and roughness_tag_regex.search(file_name): entry.roughness = texture
			elif not entry.aocclusion and aocclusion_tag_regex.is_valid() and aocclusion_tag_regex.search(file_name): entry.aocclusion = texture
			elif not entry.albedo and AlbedoMapEd.text.is_empty(): entry.albedo = texture
		file_name = dir.get_next()
	dir.list_dir_end()


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


func _build_search_pattern(s: String) -> String:
	var words := split_string_with_regex(s)
	if words.size() == 0: return ""
	var pattern := ""
	for word in words: 
		if not pattern.is_empty(): pattern = pattern + "|"
		pattern = pattern + "("
		for c in word: pattern = pattern + ".*" + c
		pattern = pattern + ")"
	return pattern


func split_string_with_regex(s: String) -> Array[String]:
	var parts : Array[String] = []
	var results := split_regex.search_all(s)
	for r in results:
		if r.strings.size() > 0:
			parts.append(r.strings[0])
	return parts


func split_string(s: String, delimeters: Array[String]) -> Array[String]:
	var parts : Array[String] = []
	var start := 0
	var i := 0
	while i < s.length():
		if s[i] in delimeters:
			if start < i:
				parts.push_back(s.substr(start, i - start))
			start = i + 1
		i += 1
	if start < i:
		parts.push_back(s.substr(start, i - start))
	return parts


#endregion
# ----------------------------------------------------------------------------------------------------------------------

