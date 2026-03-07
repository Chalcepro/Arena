# test_ollama.gd (run this as a tool script or in a test scene)
@tool
extends Node

#func _ready():
	#test_ollama()
#
#func test_ollama():
	#print("Testing Ollama connection...")
	#
	#var http = HTTPRequest.new()
	#add_child(http)
	#
	#http.request_completed.connect(_on_request_completed)
	#
	#var error = http.request(
		#"http://localhost:11434/api/generate",
		#["Content-Type: application/json"],
		#HTTPClient.METHOD_POST,
		#JSON.stringify({
			#"model": "qwen2.5-coder:3b",
			#"prompt": "Hello, are you working?",
			#"stream": false
		#})
	#)
	#
	#if error != OK:
		#print("Failed to create HTTP request: ", error)
#
#func _on_request_completed(result, response_code, headers, body):
	#if response_code == 200:
		#var json = JSON.new()
		#json.parse(body.get_string_from_utf8())
		#print("✅ Ollama is working!")
		#print("Response: ", json.data.get("response", ""))
	#else:
		#print("❌ Ollama returned error code: ", response_code)
		#print("Body: ", body.get_string_from_utf8())
