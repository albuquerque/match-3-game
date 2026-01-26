extends Node
## DLCConfig - Centralized DLC configuration

# Set to true for local testing, false for production
const USE_LOCAL_SERVER: bool = true

# Local server (for testing)
const LOCAL_SERVER_IP: String = "192.168.0.110"
const LOCAL_SERVER_PORT: int = 8000

# Production server
const PRODUCTION_SERVER_URL: String = "https://your-cdn.com/dlc/"

## Get active DLC server URL
static func get_dlc_server_url() -> String:
	if USE_LOCAL_SERVER:
		return "http://%s:%d/dlc/" % [LOCAL_SERVER_IP, LOCAL_SERVER_PORT]
	else:
		return PRODUCTION_SERVER_URL

## Check if using local server
static func is_local_mode() -> bool:
	return USE_LOCAL_SERVER

## Print configuration
static func print_config():
	print("[DLCConfig] Mode: %s" % ("LOCAL" if USE_LOCAL_SERVER else "PRODUCTION"))
	print("[DLCConfig] Server: %s" % get_dlc_server_url())


