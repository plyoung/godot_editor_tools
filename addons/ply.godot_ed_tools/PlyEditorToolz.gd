@tool
class_name PlyEditorToolz
extends EditorPlugin

const BulkImportDialog = preload("res://addons/ply.godot_ed_tools/bulk_import/bulk_import_dialog.tscn")
const PrefabsMakerSetupDialog = preload("res://addons/ply.godot_ed_tools/prefabs_maker/prefab_maker_setup_dialog.tscn")
const RemapMatsDialog = preload("res://addons/ply.godot_ed_tools/remap_materials/remap_materials_dialog.tscn")
const PlyProgressDialog = preload("res://addons/ply.godot_ed_tools/progress_dialog/progress_dialog.tscn")
const MenuName := "plyTools"

var _tools_menu: PopupMenu
var _bulk_import_dialog: ConfirmationDialog
var _prefabs_maker_dialog: ConfirmationDialog
var _remap_materials_dialog: ConfirmationDialog
static var _progress_dialog: PlyToolsProgressDialog

# ----------------------------------------------------------------------------------------------------------------------
#region system

func _enter_tree() -> void:
	_add_menu_entries()


func _disable_plugin() -> void:
	_remove_menu_entries()
	_remove_windows()


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region setup

func _remove_windows() -> void:
	if _bulk_import_dialog: _bulk_import_dialog.queue_free()
	if _prefabs_maker_dialog: _prefabs_maker_dialog.queue_free()
	if _remap_materials_dialog: _remap_materials_dialog.queue_free()
	hide_progress_dialog()


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region menu entries

func _add_menu_entries() -> void:
	var menu := _add_submenu_to_tools_menu(MenuName)
	menu.id_pressed.connect(_on_model_tools_popup_menu)
	menu.add_item("Import Settings for Selected", 1)
	menu.add_item("Remap Materials on Selected", 2)
	menu.add_item("Prefabs Maker", 3)
	pass


func _remove_menu_entries() -> void:
	_remove_submenu_from_tools_menu(MenuName)
	pass


func _on_model_tools_popup_menu(id: int) -> void:
	if id == 1:
		_open_bulk_import_dialog()
	if id == 2:
		_open_remap_mats_dialog()
	if id == 3: 
		_open_prefabs_maker_dialog()


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region dialogs

func _open_bulk_import_dialog() -> void:
	if not _bulk_import_dialog: 
		_bulk_import_dialog = BulkImportDialog.instantiate()
		EditorInterface.get_base_control().add_child(_bulk_import_dialog)
	_bulk_import_dialog.popup()


func _open_remap_mats_dialog() -> void:
	if not _remap_materials_dialog: 
		_remap_materials_dialog = RemapMatsDialog.instantiate()
		EditorInterface.get_base_control().add_child(_remap_materials_dialog)
	_remap_materials_dialog.popup()


func _open_prefabs_maker_dialog() -> void:
	if not _prefabs_maker_dialog: 
		_prefabs_maker_dialog = PrefabsMakerSetupDialog.instantiate()
		EditorInterface.get_base_control().add_child(_prefabs_maker_dialog)
	_prefabs_maker_dialog.popup()


static func show_progress_dialog() -> PlyToolsProgressDialog:
	if not _progress_dialog:
		_progress_dialog = PlyProgressDialog.instantiate() as PlyToolsProgressDialog
		EditorInterface.get_base_control().add_child(_progress_dialog)
	_progress_dialog.set_heading("")
	_progress_dialog.set_message("")
	_progress_dialog.set_progress(0)
	_progress_dialog.popup()
	return _progress_dialog


static func hide_progress_dialog() -> void:
	if _progress_dialog:
		_progress_dialog.queue_free()
		_progress_dialog = null


#endregion
# ----------------------------------------------------------------------------------------------------------------------
#region helpers

func _get_first_node_by_class(parent_node: Node, target_class_name: String) -> Node:
	if not parent_node: parent_node = EditorInterface.get_base_control()
	var nodes := parent_node.find_children("*", target_class_name, true, false)
	if !nodes.size(): return null
	return nodes[0]


func _get_first_node_by_name(parent_node: Node, target_node_name: String) -> Node:
	return parent_node.find_child(target_node_name, true, false)


func _get_menubar_entry(menu_name: String) -> PopupMenu:
	var menu_bar := _get_first_node_by_class(EditorInterface.get_base_control(), "MenuBar")
	var nodes := menu_bar.find_children("*", "PopupMenu", true, false)
	for node in nodes:
		var menu := node as PopupMenu
		if menu.name == menu_name:
			return menu
	return null


func _get_submenu(parent_menu: PopupMenu, menu_name: String) -> PopupMenu:
	for i in parent_menu.item_count:
		var entry_name := parent_menu.get_item_text(i)
		if entry_name == menu_name:
			var node_name := parent_menu.get_item_submenu(i)
			var node := parent_menu.find_child(node_name, false, false) as PopupMenu
			return node
	return null


func _remove_submenu(parent_menu: PopupMenu, menu_name: String) -> void:
	for i in parent_menu.item_count:
		var entry_name := parent_menu.get_item_text(i)
		if entry_name == menu_name:
			var node_name := parent_menu.get_item_submenu(i)
			var node := parent_menu.find_child(node_name, false, false) as PopupMenu
			parent_menu.remove_item(i)
			node.queue_free()
			return


func _add_submenu_to_tools_menu(name: String) -> PopupMenu:
	if not _tools_menu:
		var project_menu := _get_menubar_entry("Project")
		_tools_menu = _get_submenu(project_menu, "Tools")
	var submenu = PopupMenu.new()
	submenu.name = name
	_tools_menu.add_child(submenu)
	_tools_menu.add_submenu_item(name, name)
	return submenu


func _remove_submenu_from_tools_menu(name: String) -> void:
	if _tools_menu:
		_remove_submenu(_tools_menu, name)


static func _print_layout_direct_children(base: Node) -> void:
	print("%s > %s" % [base.name, base.get_class()])
	var nodes := base.get_children()
	for node in nodes:
		var control = node as Control
		if control:
			var text : String = control.text if control is Label else control.tooltip_text
			print("\t%s > %s (%s) - %s" % [control.name, control.get_class(), control.visible,  text])
		else:
			print("\t%s > %s" % [node.name, node.get_class()])


static func _print_layout(base: Node, max_depth: int = -1, containers_only : bool = true, limit_non_containers : int = -1, indent: String = "") -> void:
	if base == null:
		return
		
	if max_depth > 0:
		max_depth -= 1
		if max_depth == 0: return
		
	var non_container_count := 0
	var nodes := base.get_children()
	for node in nodes:
		if containers_only:
			var control = node as Container
			if control:
				print("%s %s > %s (%s)" % [indent, control.name, control.get_class(), control.visible])
				_print_layout(node, max_depth, containers_only, limit_non_containers, indent + "\t")
		else:
			if not node is Container and limit_non_containers > 0:
				non_container_count += 1
				if non_container_count > limit_non_containers: continue
			var control = node as Control
			if control:
				print("%s %s > %s (%s) - %s" % [indent, control.name, control.get_class(), control.visible, control.tooltip_text])
			else:
				print("%s %s > %s" % [indent, node.name, node.get_class()])
			_print_layout(node, max_depth, containers_only, limit_non_containers, indent + "\t")


func get_all_file_paths(path: String, file_ext := "", recursive := false) -> Array:
	var file_paths: Array[String] = []  
	var dir = DirAccess.open(path)  
	dir.list_dir_begin()  
	var file_name = dir.get_next()  
	while file_name != "":  
		var file_path = path + "/" + file_name  
		if dir.current_is_dir():  
			if recursive:
				file_paths += get_all_file_paths(file_path, file_ext, recursive)  
		else:
			if not file_ext or file_path.get_extension() == file_ext:
				file_paths.append(file_path)  
		file_name = dir.get_next()  
	return file_paths


#endregion
# ----------------------------------------------------------------------------------------------------------------------
