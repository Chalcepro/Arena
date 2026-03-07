@tool
extends RefCounted

const BaseProvider = preload("res://addons/ai_coding_assistant/ai_provider/base_provider.gd")

static func get_name() -> String:
	return "ollama"

static func get_base_url() -> String:
	return "http://localhost:11434/v1/"

static func get_default_model() -> String:
	return "qwen2.5-coder:3b"

static func build_request(base_url: String, api_key: String, model: String, message: String, history: Array, system_prompt: String) -> Dictionary:
	# Build messages
	var messages = BaseProvider.build_chat_messages(message, history, system_prompt)
	
	# CRITICAL FIX: Use integer for max_tokens, not float
	var body = {
		"model": model,
		"messages": messages,
		"stream": true,
		"options": {
			"num_predict": 2048,  # Ollama uses num_predict instead of max_tokens
			"temperature": 0.7
		}
	}
	
	# Optional: Add a dummy API key if needed (Ollama ignores it)
	var headers = [
		"Content-Type: application/json"
	]
	
	# Only add Authorization if API key is provided and not empty
	if api_key and api_key != "" and api_key != "ollama":
		headers.append("Authorization: Bearer " + api_key)
	
	var full_url = base_url + "chat/completions"
	print("🌐 Ollama requesting: ", full_url)
	print("📦 Body: ", JSON.stringify(body))
	
	return {
		"url": full_url,
		"headers": headers,
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body)
	}

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
