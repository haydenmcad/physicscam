import cv2
from http.server import BaseHTTPRequestHandler, HTTPServer

# Low-latency camera setup
camera = cv2.VideoCapture("/dev/video0", cv2.CAP_V4L2)
camera.set(cv2.CAP_PROP_BUFFERSIZE, 1)
camera.set(cv2.CAP_PROP_FPS, 30)

if not camera.isOpened():
    print("ERROR: Camera failed to open")
    exit(1)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Always serve MJPEG stream on "/"
        self.send_response(200)
        self.send_header(
            "Content-Type",
            "multipart/x-mixed-replace; boundary=frame"
        )
        self.end_headers()

        while True:
            ret, frame = camera.read()
            if not ret:
                continue

            # Lower latency encoding (balanced quality)
            ret2, jpeg = cv2.imencode(
                ".jpg",
                frame,
                [int(cv2.IMWRITE_JPEG_QUALITY), 70]
            )
            if not ret2:
                continue

            try:
                self.wfile.write(b"--frame\r\n")
                self.wfile.write(b"Content-Type: image/jpeg\r\n\r\n")
                self.wfile.write(jpeg.tobytes())
                self.wfile.write(b"\r\n")
            except Exception:
                break


# Bind to all interfaces
server = HTTPServer(("0.0.0.0", 8080), Handler)

print("Low-latency stream running on port 8080")
server.serve_forever()
