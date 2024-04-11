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

It is imporant to get rid of the post/pre tags in the names to help identify which textures belong with which materials when using the auto texture option.

In this example the material names all start with `m_` so I set name cleanup to get rid of that. The textures all start with `t_` and end with `_bc` of albedo, `_n` for normal, `_m` for metallic, `_ro` for roughness, and `_ao` for ambient occlusion. So `^(t_)|(_bc|_n|_m|_ro|_ao)$` will help clean up the texture names while the indivisual tag patterns seen in image below help identify which are albedo, normal, etc.

![sample](/img/extract_mats.png)




