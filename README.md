# Godot Editor Tools

Godot editor addon where I dump various useful tools and scripts.

## Install

Copy folder in addons to the addons folder in your Godot project's folder and then activate the plugin in project settings.

Last tested in: 4.4 beta1

## Bulk Import and Materials extract

Opened via menu: `Project > Tools > plyTools > Import Settings for Selected.`

This tool can be used to extract the materials from all selected model/scenes (ex. GLB and FBX files). It is similar to the Extract Materials action in the scene advanced import settings window but to perform some batch actions.

It will itterate over the scenes (model files) you have selected in the FileSystem dock.

![sample](/img/extract_mats.png)


## Prefabs Maker (batch create Inherited Scenes)

Opened via menu: `Project > Tools > plyTools > Prefabs Maker.`

This tool will create inherited scenes in the target path from the selected source's models/scenes.

![sample](/img/prefabs.png)


## Material mapper

Opened via menu: `Project > Tools > plyTools > Remap Matewrials on Selected.`

This is used to set the material on the selected (in FileSystem dock) scenes or models. For models this will be similar to using the advanced import window to set the 'use exten' material of a model and for scenes/prefabs this will make use of the 'Surface Material Override' of the MeshInstance3D.

![sample](/img/map_mats.png)

