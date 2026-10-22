class_name SpriteLib
## Builds SpriteFrames / textures from the sheets described in SpriteMeta (generated file).

static var _frames_cache := {}


static func texture(sheet: String) -> Texture2D:
	return load(SpriteMeta.SHEETS[sheet].path)


static func frame_texture(sheet: String, index: int) -> AtlasTexture:
	var meta: Dictionary = SpriteMeta.SHEETS[sheet]
	var at := AtlasTexture.new()
	at.atlas = texture(sheet)
	var cols: int = meta.cols
	at.region = Rect2((index % cols) * meta.fw, (index / cols) * meta.fh, meta.fw, meta.fh)
	return at


static func frames(sheet: String) -> SpriteFrames:
	if _frames_cache.has(sheet):
		return _frames_cache[sheet]
	var meta: Dictionary = SpriteMeta.SHEETS[sheet]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in meta.anims:
		var a: Dictionary = meta.anims[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, a.fps)
		sf.set_animation_loop(anim, a.loop)
		for idx in a.frames:
			sf.add_frame(anim, frame_texture(sheet, idx))
	_frames_cache[sheet] = sf
	return sf


static func has_anim(sheet: String, anim: String) -> bool:
	return SpriteMeta.SHEETS[sheet].anims.has(anim)


## An AnimatedSprite2D whose bottom-center sits on the node origin (feet on the ground).
static func animated(sheet: String, anim := "") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(sheet)
	var meta: Dictionary = SpriteMeta.SHEETS[sheet]
	s.offset = Vector2(0, -meta.fh / 2.0)
	var first: String = meta.anims.keys()[0]
	s.play(anim if anim != "" else first)
	return s


## A static Sprite2D anchored at bottom-center.
static func sprite(sheet: String, index := 0) -> Sprite2D:
	var s := Sprite2D.new()
	var meta: Dictionary = SpriteMeta.SHEETS[sheet]
	s.texture = texture(sheet) if meta.cols == 1 and index == 0 else frame_texture(sheet, index)
	s.offset = Vector2(0, -meta.fh / 2.0)
	return s
