import os
import json


class Config:
    DEBUG = os.getenv("FLASK_DEBUG", "1") == "1"
    HOST = os.getenv("FLASK_HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", os.getenv("FLASK_PORT", "5000")))
    SECRET_KEY = os.getenv("SECRET_KEY", "change_me")
    ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")
    MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

    # Firebase — via env var (base64 or raw JSON) or file path
    FIREBASE_SERVICE_ACCOUNT = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    FIREBASE_DATABASE_URL = os.getenv("FIREBASE_DATABASE_URL")

    @staticmethod
    def get_firebase_credentials():
        raw = os.getenv("FIREBASE_SERVICE_ACCOUNT")
        if raw:
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                pass
        file_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
        if file_path and os.path.exists(file_path):
            with open(file_path) as f:
                return json.load(f)
        return None
