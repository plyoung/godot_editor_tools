@tool
extends ConfirmationDialog

@onready var SkipImportCheck : CheckBox = %SkipImportCheck
@onready var SkipImportEd : LineEdit = %SkipImportEdit
@onready var ExportMatsCheck : CheckBox = %ExportMaterialsCheck
@onready var MaterialsPathEd : LineEdit = %MaterialsPathEdit
@onready var TexturesPathEd : LineEdit = %TexturesPathEdit
@onready var MaterialsPathButton : Button = %MaterialsPathButton
@onready var TexturesPathButton : Button = %TexturesPathButton
@onready var AlbedoMapEd : LineEdit = %AlbedoMapEdit
@onready var NormalMapEd : LineEdit = %NormalMapEdit
@onready var MetallicMapEd : LineEdit = %MetallicMapEdit
@onready var RoughnessMapEd : LineEdit = %RoughnessMapEdit
@onready var AOcclusionMapEd : LineEdit = %AOcclusionMapEdit
@onready var EmissionMapEd : LineEdit = %EmissionMapEdit
@onready var MatNameCleanupEd : LineEdit = %MatNameCleanupEdit
@onready var TexNameCleanupEd : LineEdit = %TexNameCleanupEdit
@onready var OverrideMatsCheck : CheckBox = %OverrideMatsCheck
@onready var ForceUpdateScenesCheck : CheckBox = %ForceUpdateScenesCheck
@onready var SaveCleanMaterialNameCheck : CheckBox = %SaveCleanMaterialNameCheck
@onready var ResetCullModeCheck : CheckBox = %ResetCullModeCheck
@onready var ResetVertexAsAlbedoColorCheck : CheckBox = %ResetVertexAsAlbedoColorCheck
@onready var ResetAlbedoColorCheck : CheckBox = %ResetAlbedoColorCheck
@onready var ResetMetallicValueCheck : CheckBox = %ResetMetallicValueCheck
@onready var ResetRoughnessValueCheck : CheckBox = %ResetRoughnessValueCheck
@onready var ResetRoughnessValueEd : LineEdit = %ResetRoughnessValueEd
@onready var ResetEmissionCheck : CheckBox = %ResetEmissionCheck

@onready var skip_import_regex := RegEx.new()
@onready var albedo_tag_regex := RegEx.new()
@onready var normal_tag_regex := RegEx.new()
@onready var metallic_tag_regex := RegEx.new()
@onready var roughness_tag_regex := RegEx.new()
@onready var aocclusion_tag_regex := RegEx.new()
@onready var emission_tag_regex := RegEx.new()
@onready var matname_cleanup_regex := RegEx.new()
@onready var texname_cleanup_regex := RegEx.new()
@onready var search_regex := RegEx.new()
@onready var split_regex := RegEx.new()

@onready var textures := Dictionary()
@onready var changed_scene_files := PackedStringArray()
@onready var changed_material_files := PackedStringArray()

var file_dialog: EditorFileDialog
var mats_path : String
var texs_path : String
var roughness_value : float

const skip_import_check_key := "addons/ply_editor_tools/batch_import/process_skip_imports"
const skip_import_settings_key := "addons/ply_editor_tools/batch_import/skip_import_settings"
const export_materials_key := "addons/ply_editor_tools/batch_import/export_materials"
const last_materials_path_settings_key := "addons/ply_editor_tools/batch_import/last_materials_path"
const last_textures_path_settings_key := "addons/ply_editor_tools/batch_import/last_textures_path"
const albedo_tag_settings_key := "addons/ply_editor_tools/batch_import/albedo_tag"
const normal_tag_settings_key := "addons/ply_editor_tools/batch_import/normal_tag"
const metallic_tag_settings_key := "addons/ply_editor_tools/batch_import/metallic_tag"
const roughness_tag_settings_key := "addons/ply_editor_tools/batch_import/roughness_tag"
const aocclusion_tag_settings_key := "addons/ply_editor_tools/batch_import/aocclusion_tag"
const emission_tag_settings_key := "addons/ply_editor_tools/batch_import/emission_tag"
const matname_cleanup_settings_key := "addons/ply_editor_tools/batch_import/material_name_cleanup"
const texname_cleanup_settings_key := "addons/ply_editor_tools/batch_import/texture_name_cleanup"
const override_mats_settings_key := "addons/ply_editor_tools/batch_import/override_materials"
const force_update_scene_settings_key := "addons/ply_editor_tools/batch_import/force_update_scenes"
const save_clean_material_name_settings_key := "addons/ply_editor_tools/batch_import/save_with_cleaned_material_name"
const reset_cull_mode_settings_key := "addons/ply_editor_tools/batch_import/reset_cull_mode"
const reset_vertex_color_option_settings_key := "addons/ply_editor_tools/batch_import/reset_vertex_color_option"
const reset_albedo_color_settings_key := "addons/ply_editor_tools/batch_import/reset_albedo_color"
const reset_metallic_value_settings_key := "addons/ply_editor_tools/batch_import/reset_metallic_value"
const reset_roughness_value_settings_key := "addons/ply_editor_tools/batch_import/reset_roughness_value"
const reset_roughness_value_to_settings_key := "addons/ply_editor_tools/batch_import/reset_roughness_value_to"
const reset_emission_settings_key := "addons/ply_editor_tools/batch_import/reset_emission_settings"

# ----------------------------------------------------------------------------------------------------------------------

class TexturePaths:
	var albedo : Texture2D
	var normal : Texture2D
	var metallic : Texture2D
	var roughness : Texture2D
	var aocclusion : Texture2D
	var emission : Texture2D

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
	_read_settings()


func _exit_tree() -> void:
	_close_file_dialog()


func _read_settings() -> void:
	SkipImportCheck.button_pressed = ProjectSettings.get_setting(skip_import_check_key, false)
	SkipImportEd.text = ProjectSettings.get_setting(skip_import_settings_key, "(_lod1|_lod2|_lod3|_lod4|_lod5)$")
	ExportMatsCheck.button_pressed = ProjectSettings.get_setting(export_materials_key, false)
	MaterialsPathEd.text = ProjectSettings.get_setting(last_materials_path_settings_key, "")
	TexturesPathEd.text = ProjectSettings.get_setting(last_textures_path_settings_key, "")
	AlbedoMapEd.text = ProjectSettings.get_setting(albedo_tag_settings_key, "(_a|_d|_c|_bc)$")
	NormalMapEd.text = ProjectSettings.get_setting(normal_tag_settings_key, "_n$")
	MetallicMapEd.text = ProjectSettings.get_setting(metallic_tag_settings_key, "_m$")
	RoughnessMapEd.text = ProjectSettings.get_setting(roughness_tag_settings_key, "_ro$")
	AOcclusionMapEd.text = ProjectSettings.get_setting(aocclusion_tag_settings_key, "_ao$")
	EmissionMapEd.text = ProjectSettings.get_setting(emission_tag_settings_key, "_e$")
	MatNameCleanupEd.text = ProjectSettings.get_setting(matname_cleanup_settings_key, "^(m_|t_)")
	TexNameCleanupEd.text = ProjectSettings.get_setting(texname_cleanup_settings_key, "^(t_)|(_a|_bc|_d|_n|_m|_ro|_ao|_e)$")
	OverrideMatsCheck.button_pressed = ProjectSettings.get_setting(override_mats_settings_key, false)
	ForceUpdateScenesCheck.button_pressed = ProjectSettings.get_setting(force_update_scene_settings_key, false)
	SaveCleanMaterialNameCheck.button_pressed = ProjectSettings.get_setting(save_clean_material_name_settings_key, false)
	ResetCullModeCheck.button_pressed = ProjectSettings.get_setting(reset_cull_mode_settings_key, true)
	ResetVertexAsAlbedoColorCheck.button_pressed = ProjectSettings.get_setting(reset_vertex_color_option_settings_key, true)
	ResetAlbedoColorCheck.button_pressed = ProjectSettings.get_setting(reset_albedo_color_settings_key, false)
	ResetMetallicValueCheck.button_pressed = ProjectSettings.get_setting(reset_metallic_value_settings_key, false)
	ResetRoughnessValueCheck.button_pressed = ProjectSettings.get_setting(reset_roughness_value_settings_key, false)
	ResetRoughnessValueEd.text = ProjectSettings.get_setting(reset_roughness_value_to_settings_key, "0.5")
	ResetEmissionCheck.button_pressed = ProjectSettings.get_setting(reset_emission_settings_key, false)


func _save_settings() -> void:
	ProjectSettings.set_setting(skip_import_check_key, SkipImportCheck.button_pressed)
	ProjectSettings.set_setting(skip_import_settings_key, SkipImportEd.text)
	ProjectSettings.set_setting(export_materials_key, ExportMatsCheck.button_pressed)
	ProjectSettings.set_setting(last_materials_path_settings_key, MaterialsPathEd.text)
	ProjectSettings.set_setting(last_textures_path_settings_key, TexturesPathEd.text)
	ProjectSettings.set_setting(albedo_tag_settings_key, AlbedoMapEd.text)
	ProjectSettings.set_setting(normal_tag_settings_key, NormalMapEd.text)
	ProjectSettings.set_setting(metallic_tag_settings_key, MetallicMapEd.text)
	ProjectSettings.set_setting(roughness_tag_settings_key, RoughnessMapEd.text)
	ProjectSettings.set_setting(aocclusion_tag_settings_key, AOcclusionMapEd.text)
	ProjectSettings.set_setting(emission_tag_settings_key, EmissionMapEd.text)
	ProjectSettings.set_setting(matname_cleanup_settings_key, MatNameCleanupEd.text)
	ProjectSettings.set_setting(texname_cleanup_settings_key, TexNameCleanupEd.text)
	ProjectSettings.set_setting(override_mats_settings_key, OverrideMatsCheck.button_pressed)
	ProjectSettings.set_setting(force_update_scene_settings_key, ForceUpdateScenesCheck.button_pressed)
	ProjectSettings.set_setting(save_clean_material_name_settings_key, SaveCleanMaterialNameCheck.button_pressed)
	ProjectSettings.set_setting(reset_cull_mode_settings_key, ResetCullModeCheck.button_pressed)
	ProjectSettings.set_setting(reset_vertex_color_option_settings_key, ResetVertexAsAlbedoColorCheck.button_pressed)
	ProjectSettings.set_setting(reset_albedo_color_settings_key, ResetAlbedoColorCheck.button_pressed)
	ProjectSettings.set_setting(reset_metallic_value_settings_key, ResetMetallicValueCheck.button_pressed)
	ProjectSettings.set_setting(reset_roughness_value_settings_key, ResetRoughnessValueCheck.button_pressed)
	ProjectSettings.set_setting(reset_roughness_value_to_settings_key, ResetRoughnessValueEd.text)
	ProjectSettings.set_setting(reset_emission_settings_key, ResetEmissionCheck.button_pressed)


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region process

func _on_confirmation() -> void:
	changed_scene_files.clear()
	changed_material_files.clear()
	skip_import_regex.clear()
	albedo_tag_regex.clear()
	normal_tag_regex.clear()
	metallic_tag_regex.clear()
	roughness_tag_regex.clear()
	aocclusion_tag_regex.clear()
	emission_tag_regex.clear()
	matname_cleanup_regex.clear()
	texname_cleanup_regex.clear()
	
	if not SkipImportEd.text.is_empty(): skip_import_regex.compile(SkipImportEd.text)
	if not AlbedoMapEd.text.is_empty(): albedo_tag_regex.compile(AlbedoMapEd.text)
	if not NormalMapEd.text.is_empty(): normal_tag_regex.compile(NormalMapEd.text)
	if not MetallicMapEd.text.is_empty(): metallic_tag_regex.compile(MetallicMapEd.text)
	if not RoughnessMapEd.text.is_empty(): roughness_tag_regex.compile(RoughnessMapEd.text)
	if not AOcclusionMapEd.text.is_empty(): aocclusion_tag_regex.compile(AOcclusionMapEd.text)
	if not EmissionMapEd.text.is_empty(): emission_tag_regex.compile(EmissionMapEd.text)
	if not MatNameCleanupEd.text.is_empty(): matname_cleanup_regex.compile(MatNameCleanupEd.text)
	if not TexNameCleanupEd.text.is_empty(): texname_cleanup_regex.compile(TexNameCleanupEd.text)
	
	_save_settings()
	
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
	roughness_value = ResetRoughnessValueEd.text.to_float()
	
	var paths := EditorInterface.get_selected_paths()
	for path in paths: _process_file(path)
	var rfs := EditorInterface.get_resource_filesystem()
	rfs.reimport_files(changed_scene_files)
	if changed_material_files.size() > 0:
		print("You might see some `can't be imported` error now. Just ignore it.")
		rfs.reimport_files(changed_material_files) # need this for material(s) to update without restarting editor
		#rfs.scan()
		#rfs.scan_sources()


func _process_file(model_path: String) -> void:
	# load and check that is it a packedscene
	var model := ResourceLoader.load(model_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if model == null or not model.can_instantiate(): return
	
	# open the .import file since it is used to make changes
	var import_path := model_path + ".import"
	if not FileAccess.file_exists(import_path): 
		printerr("Could not load: %s" % import_path)
		return
	
	var updated := false
	var config := ConfigFile.new()
	var result := config.load(import_path)
	if result != OK:
		printerr("Could not load: %s" % import_path)
		return

	var parent_node := model.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)

	# check skip import
	if SkipImportCheck.button_pressed and skip_import_regex.is_valid():
		updated = _update_skip_import_options(config, parent_node) or updated
	
	# process the scene materials
	if ExportMatsCheck.button_pressed:
		var extracted_materials := Dictionary()
		var had_errors := _process_node(parent_node, extracted_materials)
		parent_node.queue_free()
		
		# if there were errors then it could be that the model is set to use extern materials
		# which were removed. check if that is the case and 1st reset the model to use
		# internal and then try again to export the material
		if had_errors:
			var can_reload := _reset_to_use_internal_materials(config, import_path, model_path)
			if can_reload:
				model = ResourceLoader.load(model_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
				if model == null or not model.can_instantiate(): return
				parent_node = model.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
				_process_node(parent_node, extracted_materials)
				parent_node.queue_free()
		
		# update the import settings with exported materials
		if not extracted_materials.is_empty():
			updated = _update_with_extern_mats(config, model_path, extracted_materials) or updated

	if updated:
		result = config.save(import_path)
		if result == OK: changed_scene_files.append(model_path)
		else: printerr("Could not save: %s" % import_path)


func _update_skip_import_options(config: ConfigFile, node: Node) -> bool:
	var changed = false
	var node_names : Array[String] = []
	_check_node_for_skip_import(node, "", node_names)
	if node_names.size() > 0:
		changed = true
		var subres := config.get_value("params", "_subresources", Dictionary()) as Dictionary
		if not subres.has("nodes"): subres["nodes"] = Dictionary()
		var subres_nodes : Dictionary = subres["nodes"]
		for name in node_names:
			var node_path_name := "PATH:" + name
			if not subres_nodes.has(node_path_name): subres_nodes[node_path_name] = Dictionary()
			var n : Dictionary = subres_nodes[node_path_name]
			n["import/skip_import"] = true
	return changed


func _check_node_for_skip_import(node: Node, path: String, node_names : Array[String]) -> void:
	if not node: return
	var node_path := node.name
	if path.length() > 0 and node.get_parent().get_parent(): 
		node_path = path + "/" + node.name
	var check_name = node.name.to_lower()
	if skip_import_regex.search(check_name):
		node_names.append(node_path)
	for n in node.get_children():
		_check_node_for_skip_import(n, node_path, node_names)


func _reset_to_use_internal_materials(config: ConfigFile, import_path: String, scene_path: String) -> bool:
	print("Model had invalid material(s): ", scene_path)
	
	# check if there are extern materials and remove the entries
	var subres := config.get_value("params", "_subresources", Dictionary()) as Dictionary
	if not subres.has("materials"): subres["materials"] = Dictionary()
	var subres_mats : Dictionary = subres["materials"]
	if subres_mats.size() > 0:
		print("... found %s extern materials, reverting to internal materials" % subres_mats.size())
		subres_mats.clear()
		var result = config.save(import_path)
		if result == OK:
			var reimport := PackedStringArray()
			reimport.append(scene_path)
			EditorInterface.get_resource_filesystem().reimport_files(reimport)
			return true
		else: 
			printerr("Could not save: %s" % import_path)
	return false


func _update_with_extern_mats(config: ConfigFile, scene_path: String, extracted_materials: Dictionary) -> bool:
	var changed := false
	var subres := config.get_value("params", "_subresources", Dictionary()) as Dictionary
	if not subres.has("materials"): subres["materials"] = Dictionary()
	var subres_mats : Dictionary = subres["materials"]
	for mat in extracted_materials:
		if ForceUpdateScenesCheck.button_pressed or not subres_mats.has(mat): 
			changed = true
			subres_mats[mat] = { "use_external/enabled": true, "use_external/path": extracted_materials[mat] }
	return changed


func _process_node(node: Node, extracted_materials: Dictionary) -> bool:
	if not node: return false
	var had_errors := false
	var meshinstance := node as MeshInstance3D
	if meshinstance:
		var mesh := meshinstance.mesh
		for i in mesh.get_surface_count():
			var surface_name := mesh.get("surface_"+ str(i) +"/name") as String
			var sourcemat := mesh.surface_get_material(i) as BaseMaterial3D
			if not surface_name or surface_name.is_empty():
				had_errors = true
			elif not sourcemat:
				had_errors = true
			else:
				var newmat_path := _get_or_create_exported_material(surface_name, sourcemat)
				if newmat_path.is_empty():
					had_errors = true
				elif not extracted_materials.has(surface_name):
					extracted_materials[surface_name] = newmat_path
			#elif not sourcemat or sourcemat.resource_name.is_empty(): 
				#had_errors = true
			#else:
				#var newmat_path := _get_or_create_exported_material(sourcemat)
				#if newmat_path.is_empty():
					#had_errors = true
				#elif not extracted_materials.has(sourcemat.resource_name):
					#extracted_materials[sourcemat.resource_name] = newmat_path
	# process children too
	for n in node.get_children():
		had_errors = _process_node(n, extracted_materials) or had_errors
	return had_errors


func _get_or_create_exported_material(surface_name: String, sourcemat: BaseMaterial3D) -> String:
	#var filename := sourcemat.resource_name.validate_filename() + ".tres"
	var filename := surface_name.validate_filename() + ".tres"
	if SaveCleanMaterialNameCheck.button_pressed and matname_cleanup_regex.is_valid():
		var old_name := filename
		filename = filename.to_lower()
		filename = matname_cleanup_regex.sub(filename, "", true)
		if filename.is_empty():
			printerr("Material name invalid after cleanup, reverting to: ", old_name)
			filename = old_name
	
	var path := mats_path.path_join(filename)
	var exists := ResourceLoader.exists(path)
	if exists and not OverrideMatsCheck.button_pressed:
		var material := ResourceLoader.load(path) as BaseMaterial3D
		if material: return path
	
	# make duplicate of original to mess with
	var material := sourcemat.duplicate()
	_update_material(material, filename)
	var error := ResourceSaver.save(material, path)
	if error == OK:
		EditorInterface.get_resource_filesystem().update_file(path)
		if exists and not changed_material_files.has(path): changed_material_files.append(path)
		return path
	
	printerr("Could not save material: %s", path)
	return ""


func _update_material(material: BaseMaterial3D, mat_filename: String) -> void:
	if texs_path.is_empty() or not material: return
	
	# get clean material name
	var mat_name := mat_filename.get_basename()
	if mat_name.is_empty(): mat_name = material.resource_name
	mat_name = mat_name.to_lower()
	if not SaveCleanMaterialNameCheck.button_pressed and matname_cleanup_regex.is_valid(): 
		mat_name = matname_cleanup_regex.sub(mat_name, "", true)
	
	# reset material props based on chosen options
	_reset_material_props(material)
	
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
	#for m in matches:
	#	print(m.weight, " > ", m.key.length(), " :: ", m.key)
	_set_material_textures(material, matches[0].key)


func _reset_material_props(material: StandardMaterial3D) -> void:
	if ResetCullModeCheck.button_pressed: material.cull_mode = BaseMaterial3D.CULL_BACK
	if ResetVertexAsAlbedoColorCheck.button_pressed: material.vertex_color_use_as_albedo = false
	if ResetAlbedoColorCheck.button_pressed: material.albedo_color = Color.WHITE	
	if ResetMetallicValueCheck.button_pressed: material.metallic = 0
	if ResetRoughnessValueCheck.button_pressed: material.roughness = roughness_value
	if ResetEmissionCheck.button_pressed: material.emission_enabled = false


func _set_material_textures(material: StandardMaterial3D, key: String) -> void:
	var paths : TexturePaths = textures[key]
	
	if paths.albedo and not material.albedo_texture:
		material.albedo_texture = paths.albedo
	
	if paths.metallic and not material.metallic_texture: 
		material.metallic_texture = paths.metallic
	if material.metallic_texture and material.metallic == 0: 
		material.metallic = 1
	
	if paths.roughness and not material.roughness_texture: 
		material.roughness_texture = paths.roughness
	if material.roughness_texture and material.roughness == 0: 
		material.roughness = 1
	
	if paths.normal and not material.normal_texture: 
		material.normal_texture = paths.normal
	if material.normal_texture: 
		material.normal_enabled = true
	
	if paths.aocclusion and not material.ao_texture: 
		material.ao_texture = paths.aocclusion
	if material.ao_texture:
		material.ao_enabled = true
		if material.ao_light_affect == 0: material.ao_light_affect = 1
		
	if paths.emission and not material.emission_texture:
		material.emission_texture = paths.emission
	if material.emission_texture:
		material.emission_enabled = true


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
			elif not entry.emission and emission_tag_regex.is_valid() and emission_tag_regex.search(file_name): entry.emission = texture
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
