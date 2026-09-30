extends RefCounted

static var texture_cache: Dictionary = {}

static func texture_at(path: String) -> Texture2D:
	if texture_cache.has(path): return texture_cache[path]
	var texture: Texture2D
	# The local template_debug binary cannot read textures imported by the
	# official editor, but it can decode the source PNGs directly.
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null and ResourceLoader.exists(path): texture = load(path) as Texture2D
	texture_cache[path] = texture
	return texture
