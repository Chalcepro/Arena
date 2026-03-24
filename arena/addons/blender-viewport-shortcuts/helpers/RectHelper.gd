extends Object
class_name RectHelper

var rect: Rect2

func _init(rect: Rect2) -> void:
	self.rect = rect

static func _left(rect: Rect2) -> float:
	return rect.position.x
static func _right(rect: Rect2) -> float:
	return rect.position.x + rect.size.x
	
static func _get_up(rect: Rect2) -> float:
	return rect.position.y
	
static func _get_down(rect: Rect2) -> float:
	return rect.position.y + rect.size.y


func left(rect: Rect2 = self.rect) -> float:
	return rect.position.x
	
func right(rect: Rect2 = self.rect) -> float:
	return rect.position.x + rect.size.x
	
func top(rect: Rect2 = self.rect) -> float:
	return rect.position.y
	
func bottom(rect: Rect2 = self.rect) -> float:
	return rect.position.y + rect.size.y
	

func UL(rect: Rect2 = self.rect) -> Vector2:
	return rect.position

func UR(rect: Rect2 = self.rect) -> Vector2:
	return Vector2(rect.position.x + rect.size.x, rect.position.y)

func DR(rect: Rect2 = self.rect) -> Vector2:
	return Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)

func DL(rect: Rect2 = self.rect) -> Vector2:
	return Vector2(rect.position.x, rect.position.y + rect.size.y)

func borders(rect: Rect2 = self.rect) -> Vector4:
	return Vector4(top(rect), right(rect), bottom(rect), left(rect))

func vertices(rect: Rect2 = self.rect) -> Array[Vector2]:
	return [UL(rect), UR(rect), DR(rect), DL(rect)]
