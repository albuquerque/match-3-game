#!/usr/bin/env python3
"""
Simple HTTP server for DLC testing
Serves files from the current directory on port 8000
"""
import http.server
import socketserver
import os
PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    def end_headers(self):
        # Add CORS headers for cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()
if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
        print(f"========================================")
        print(f"  DLC Test Server")
        print(f"========================================")
        print(f"")
        print(f"  Serving at: http://192.168.0.110:{PORT}/")
        print(f"  Directory: {DIRECTORY}")
        print(f"")
        print(f"  Available endpoints:")
        print(f"    - http://192.168.0.110:{PORT}/dlc/manifest_list.json")
        print(f"    - http://192.168.0.110:{PORT}/dlc/chapters/chapter_demo.zip")
        print(f"")
        print(f"  Press Ctrl+C to stop")
        print(f"========================================")
        print(f"")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nServer stopped.")
