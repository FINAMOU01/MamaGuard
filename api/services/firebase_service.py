import firebase_admin
from firebase_admin import credentials, firestore, messaging
from config import Config

_firebase_initialized = False


def ensure_initialized():
    global _firebase_initialized
    if _firebase_initialized:
        return True

    creds = Config.get_firebase_credentials()
    if not creds:
        return False

    try:
        cred = credentials.Certificate(creds)
        firebase_admin.initialize_app(cred, {
            "databaseURL": Config.FIREBASE_DATABASE_URL or "",
        })
        _firebase_initialized = True
        return True
    except Exception:
        return False


def get_db():
    if not ensure_initialized():
        return None
    return firestore.client()


def get_messaging():
    if not ensure_initialized():
        return None
    return messaging
