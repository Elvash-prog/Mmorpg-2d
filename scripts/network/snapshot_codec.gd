extends RefCounted
## Original Aurora envelope. This is not the proprietary SVP/Warspear protocol.
const MAGIC := 0x41525541 # Bytes A U R A in little endian.
const VERSION := 1
const WORLD_SNAPSHOT := 1
const HEADER_SIZE := 12
const MAX_COMPRESSED := 1048576
const MAX_DECOMPRESSED := 1048576

static func encode(state: Array) -> PackedByteArray:
	var raw := var_to_bytes(state)
	if raw.size()>MAX_DECOMPRESSED:
		return PackedByteArray()
	var payload := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if payload.size()>MAX_COMPRESSED:
		return PackedByteArray()
	var frame := PackedByteArray()
	frame.resize(HEADER_SIZE)
	frame.encode_u32(0,MAGIC)
	frame.encode_u16(4,VERSION)
	frame.encode_u16(6,WORLD_SNAPSHOT)
	frame.encode_u32(8,payload.size())
	frame.append_array(payload)
	return frame

static func decode(frame: PackedByteArray) -> Dictionary:
	if frame.size()<HEADER_SIZE or frame.decode_u32(0)!=MAGIC:
		return {"ok":false,"error":"invalid_header"}
	if frame.decode_u16(4)!=VERSION:
		return {"ok":false,"error":"incompatible_version"}
	if frame.decode_u16(6)!=WORLD_SNAPSHOT:
		return {"ok":false,"error":"unknown_message"}
	var size := frame.decode_u32(8)
	if size>MAX_COMPRESSED or size!=frame.size()-HEADER_SIZE:
		return {"ok":false,"error":"invalid_size"}
	var payload := frame.slice(HEADER_SIZE)
	if payload.is_empty():
		return {"ok":false,"error":"empty_payload"}
	var raw := payload.decompress_dynamic(MAX_DECOMPRESSED,FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return {"ok":false,"error":"invalid_compression"}
	var state: Variant = bytes_to_var(raw)
	if not state is Array or state.size()!=5 or not state[0] is Dictionary:
		return {"ok":false,"error":"invalid_snapshot"}
	for i in range(1,5):
		if not state[i] is Array:
			return {"ok":false,"error":"invalid_snapshot"}
	return {"ok":true,"state":state}
