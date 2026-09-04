extends Area2D

signal collected(kind: String, at: Vector2)
var kind := "token"
var base_y := 0.0
var elapsed := 0.0
var claimed := false
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	base_y = position.y
	elapsed = position.x * 0.02
	sprite = Sprite2D.new()
	var indexes := {"token":8, "shield":9, "coffee":10, "heart":11, "insight":15}
	sprite.texture = QuestArt.texture(indexes.get(kind, 8))
	var height := 27.0 if kind == "token" else 44.0
	sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
	add_child(sprite)
	var hit := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0 if kind == "token" else 24.0
	hit.shape = shape
	add_child(hit)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	elapsed += delta
	position.y = base_y + sin(elapsed * 3.0) * 4.0
	if kind == "token":
		sprite.scale.x = (0.75 + absf(sin(elapsed * 2.0)) * 0.25) * 27.0 / sprite.texture.get_height()

func _on_body(body: Node2D) -> void:
	if claimed or not body.is_in_group("player"):
		return
	claimed = true
	collected.emit(kind, global_position)
	queue_free()
