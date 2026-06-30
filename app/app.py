import os
import socket
from flask import Flask, jsonify


def create_app():
    app = Flask(__name__)

    version = os.environ.get("APP_VERSION", "0.0.0")

    @app.get("/")
    def index():
        # socket.gethostname() = the container ID, so we can SEE
        # which ECS task served each request (load balancing made visible)
        return jsonify(
            message="Hello from a CI/CD pipeline",
            version=version,
            served_by=socket.gethostname(),
        )

    @app.get("/health")
    def health():
        return jsonify(status="healthy"), 200

    return app


# gunicorn imports this module-level object in production
app = create_app()


if __name__ == "__main__":
    # Local dev only — gunicorn runs the app in the container
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 3000)))