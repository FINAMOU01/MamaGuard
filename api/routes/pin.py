import hashlib
from datetime import datetime, timezone, timedelta
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.sms_service import SmsService

_sms = SmsService()


def _send_alert(phone, message):
    if _sms.is_configured:
        _sms.send(phone, message)

pin_bp = Blueprint("pin", __name__)
MAX_ATTEMPTS = 5
LOCK_DURATION_MINUTES = 15


def _hash_pin(phone, pin):
    raw = f"{phone}|{pin}"
    return hashlib.sha256(raw.encode()).hexdigest()


def _now():
    return datetime.now(timezone.utc)


@pin_bp.route("/pin/create", methods=["POST"])
def create_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pin = data.get("pin")

        if not phone or not pin:
            return jsonify({"succes": False, "erreur": "Champs requis: 'phone' et 'pin'"}), 400

        if len(str(pin)) != 4 or not str(pin).isdigit():
            return jsonify({"succes": False, "erreur": "Le PIN doit être un code à 4 chiffres"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        pin_hash = _hash_pin(phone, pin)
        db.collection("users").document(phone).set({
            "phone": phone,
            "pin_hash": pin_hash,
            "created_at": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        return jsonify({"succes": True, "phone": phone}), 200

    except Exception as e:
        current_app.logger.error(f"PIN create error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pin_bp.route("/pin/check", methods=["POST"])
def check_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        if not doc.exists:
            return jsonify({"succes": True, "exists": False}), 200

        data = doc.to_dict()
        exists = "pin_hash" in data
        locked_until = data.get("locked_until")
        failed_attempts = data.get("failed_attempts", 0)
        is_locked = False
        remaining_seconds = 0

        if locked_until:
            if isinstance(locked_until, datetime):
                remaining = (locked_until - _now()).total_seconds()
                if remaining > 0:
                    is_locked = True
                    remaining_seconds = int(remaining)

        return jsonify({
            "succes": True,
            "exists": exists,
            "is_locked": is_locked,
            "remaining_seconds": remaining_seconds,
            "failed_attempts": failed_attempts,
            "max_attempts": MAX_ATTEMPTS,
        }), 200

    except Exception as e:
        current_app.logger.error(f"PIN check error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pin_bp.route("/pin/login", methods=["POST"])
def login_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pin = data.get("pin")

        if not phone or not pin:
            return jsonify({"succes": False, "erreur": "Champs requis: 'phone' et 'pin'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        if not doc.exists:
            return jsonify({"succes": False, "erreur": "Aucun compte trouvé"}), 401

        data = doc.to_dict()
        stored_hash = data.get("pin_hash")
        if not stored_hash:
            return jsonify({"succes": False, "erreur": "Aucun PIN configuré"}), 401

        # Vérifier verrouillage
        locked_until = data.get("locked_until")
        if locked_until and isinstance(locked_until, datetime):
            remaining = (locked_until - _now()).total_seconds()
            if remaining > 0:
                return jsonify({
                    "succes": False,
                    "erreur": f"Compte verrouillé. Réessayez dans {int(remaining // 60)} min.",
                    "locked": True,
                    "remaining_seconds": int(remaining),
                }), 401

        failed_attempts = data.get("failed_attempts", 0)

        if _hash_pin(phone, pin) != stored_hash:
            failed_attempts += 1
            remaining_attempts = MAX_ATTEMPTS - failed_attempts

            if failed_attempts >= MAX_ATTEMPTS:
                lock_until = _now() + timedelta(minutes=LOCK_DURATION_MINUTES)
                db.collection("users").document(phone).update({
                    "failed_attempts": failed_attempts,
                    "locked_until": lock_until,
                })
                _send_alert(phone, f"MamaGuard: Compte verrouille pour {LOCK_DURATION_MINUTES} min suite a {MAX_ATTEMPTS} echecs.")
                return jsonify({
                    "succes": False,
                    "erreur": f"Compte verrouillé pour {LOCK_DURATION_MINUTES} minutes.",
                    "locked": True,
                    "remaining_seconds": LOCK_DURATION_MINUTES * 60,
                }), 401

            db.collection("users").document(phone).update({
                "failed_attempts": failed_attempts,
            })
            return jsonify({
                "succes": False,
                "erreur": f"PIN incorrect ({remaining_attempts} essai{'s' if remaining_attempts > 1 else ''} restant{'s' if remaining_attempts > 1 else ''})",
                "remaining_attempts": remaining_attempts,
            }), 401

        # Succès → réinitialiser les tentatives
        db.collection("users").document(phone).update({
            "failed_attempts": 0,
            "locked_until": firestore.DELETE_FIELD,
        })
        return jsonify({"succes": True, "phone": phone}), 200

    except Exception as e:
        current_app.logger.error(f"PIN login error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pin_bp.route("/pin/change", methods=["POST"])
def change_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        old_pin = data.get("old_pin")
        new_pin = data.get("new_pin")

        if not phone or not old_pin or not new_pin:
            return jsonify({"succes": False, "erreur": "Champs requis: 'phone', 'old_pin', 'new_pin'"}), 400

        if len(str(new_pin)) != 4 or not str(new_pin).isdigit():
            return jsonify({"succes": False, "erreur": "Le nouveau PIN doit être un code à 4 chiffres"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        if not doc.exists:
            return jsonify({"succes": False, "erreur": "Aucun compte trouvé"}), 401

        data = doc.to_dict()
        stored_hash = data.get("pin_hash")
        if not stored_hash:
            return jsonify({"succes": False, "erreur": "Aucun PIN configuré"}), 401

        if _hash_pin(phone, old_pin) != stored_hash:
            return jsonify({"succes": False, "erreur": "Ancien PIN incorrect"}), 401

        new_hash = _hash_pin(phone, new_pin)
        db.collection("users").document(phone).update({
            "pin_hash": new_hash,
        })
        return jsonify({"succes": True, "phone": phone}), 200

    except Exception as e:
        current_app.logger.error(f"PIN change error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
