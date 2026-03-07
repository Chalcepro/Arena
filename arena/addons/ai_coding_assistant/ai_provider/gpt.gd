@tool
extends RefCounted

const BaseProvider = preload("res://addons/ai_coding_assistant/ai_provider/base_provider.gd")

static func get_name() -> String:
	return "ollama"  # Changed to "ollama" to avoid confusion

static func get_base_url() -> String:
	return "http://localhost:11434/v1/"

static func get_default_model() -> String:
	return "qwen2.5-coder:3b"

static func parse_response(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
		var choice = response_data["choices"][0]
		if choice is Dictionary and choice.has("message"):
			return str(choice["message"].get("content", ""))
	return ""

static func parse_stream_chunk(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
		var choice = response_data["choices"][0]
		if choice is Dictionary and choice.has("delta"):
			return str(choice["delta"].get("content", ""))
	return ""

static func build_request(base_url: String, api_key: String, model: String, message: String, history: Array, system_prompt: String) -> Dictionary:
	var actual_key = ""
	
	var headers = [
		"Authorization: Bearer " + actual_key,
		"Content-Type: application/json"
	]
	
	var body = {
		"model": model,
		"messages": BaseProvider.build_chat_messages(message, history, system_prompt),
		"max_tokens": 2048,
		"temperature": 0.7,
		"stream": true
	}
	
	var full_url = base_url + "chat/completions"
	print("🔍 DEBUG - Full URL: ", full_url)  # ADD THIS
	
	return {
		"url": full_url,
		"headers": headers,
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body)
	}
