# Godot Editor Tools

Godot editor addon where I dump various useful tools and scripts.

## Install

Copy folder in addons to the addons folder in your Godot project's folder and then activate the plugin in project settings.

Tested in: 4.2.x, 4.3.dev5

## Bulk Extract Materials

This tool can be used to extract the materials from all selected model/scenes (ex. GLB and FBX files). It is similar to the Extract Materials action in the scene advanced import settings window.

The tool's dialog can be opened via menu: `Project > Tools > plyTools > Extract Materials from Selected.`

It will itterate over the scenes (model files) you have selected inthe FileSystem dock.
You must specify a folder for the material and optionally a path to where textures are kept. It will attrempt to set the albedo, normal, metallic, etc maps in the material based on the material and textures names and the regex pattens provided in the other fields.

![sample](/img/extract_mats.png)




