# Mod API (Foundation)

Data mods belong under `user://mods/` and are intended for declarative JSON, images, audio, definitions, dialogue, level data, morph profiles, and loot tables. Their importer must whitelist schemas and never execute scripts.

Scripted mods are mounted `.pck` packages and may contain scenes, resources, shaders, and GDScript. They execute with game-process authority and must be labelled “Contains Executable Code” in future UI. Every mod owns a lowercase namespace and registers through a manifest and `ContentRegistry`; ordinary mods cannot replace `base:` or `core:` content.

