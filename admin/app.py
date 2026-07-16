import os
from flask import Flask, jsonify

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "change_me")


@app.route("/")
def home():
    return jsonify({
        "message": "Admin MamaGuard operationnel",
        "version": "1.0"
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    host = os.getenv("FLASK_ADMIN_HOST", "0.0.0.0")
    port = int(os.getenv("FLASK_ADMIN_PORT", "5001"))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    app.run(debug=debug, host=host, port=port)
