import logging
import os

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from config import Config

logger = logging.getLogger(__name__)

_firebase_initialized = False


def ensure_initialized():
    global _firebase_initialized
    if _firebase_initialized:
        return True

    creds = Config.get_firebase_credentials()
    if not creds:
        logger.error("Firebase credentials not found (FIREBASE_SERVICE_ACCOUNT_PATH=%s)", os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))
        return False

    try:
        cred = credentials.Certificate(creds)
        firebase_admin.initialize_app(cred, {
            "databaseURL": Config.FIREBASE_DATABASE_URL or "",
        })
        _firebase_initialized = True
        return True
    except Exception as e:
        logger.error("Firebase init failed: %s", e, exc_info=True)
        return False


def get_db():
    if not ensure_initialized():
        return None
    return firestore.client()


def get_messaging():
    if not ensure_initialized():
        return None
    return messaging
