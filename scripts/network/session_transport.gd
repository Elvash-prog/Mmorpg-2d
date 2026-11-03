extends RefCounted
const Codec = preload("res://scripts/network/snapshot_codec.gd")
var world: Node
var sent_packets := 0
var received_packets := 0
var rejected_packets := 0
var sent_bytes := 0
var received_bytes := 0

func _init(context: Node) -> void:
	world = context

func snapshot() -> PackedByteArray:
	var packet := Codec.encode([world.players,world.monsters,world.projectiles,world.zones,world.effects])
	if not packet.is_empty():
		sent_packets += 1
		sent_bytes += packet.size()
	return packet

func receive(packet: PackedByteArray) -> bool:
	var result := Codec.decode(packet)
	if not result.ok:
		rejected_packets += 1
		if result.error in ["incompatible_version","invalid_header"]:
			world.status_label.text = "Versão de rede incompatível. Atualize cliente e servidor juntos."
		return false
	var state: Array = result.state
	world.players = state[0]
	world.monsters.assign(state[1])
	world.projectiles.assign(state[2])
	world.zones.assign(state[3])
	world.effects.assign(state[4])
	received_packets += 1
	received_bytes += packet.size()
	return true

func input(id: int,direction: Vector2,attack: bool,target: int) -> bool:
	if not world.players.has(id) or not is_finite(direction.x) or not is_finite(direction.y) or target< -1 or target>=world.monsters.size():
		return false
	world.commands[id] = {"direction":direction.limit_length(),"attack":attack,"target":target,"received":world.clock}
	return true
