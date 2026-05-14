#!/usr/bin/env python3
"""Dev server with no-cache headers for ES modules."""
import http.server
import sys

import os

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_POST(self):
        if self.path == '/upload-image':
            filename = self.headers.get('X-Filename', 'upload.png')
            subdir = self.headers.get('X-Upload-Subdir', 'maps')
            content_length = int(self.headers.get('Content-Length', 0))
            data = self.rfile.read(content_length)

            safe_subdir = os.path.basename(subdir.strip('/')) or 'maps'
            target_dir = os.path.join('game/assets', safe_subdir)
            os.makedirs(target_dir, exist_ok=True)
            filepath = os.path.join(target_dir, os.path.basename(filename))
            
            with open(filepath, 'wb') as f:
                f.write(data)
                
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_error(404)

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
print(f"Dev server on http://localhost:{port} (no-cache)")
http.server.HTTPServer(('', port), NoCacheHandler).serve_forever()
