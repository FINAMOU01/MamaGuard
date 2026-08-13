from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db, get_messaging
from services.predictor import PredictorService
from services.pregnancy_service import (
    get_active_pregnancy,
    get_active_or_legacy,
    create_pregnancy,
    compute_pregnancy_week,
)
import uuid
import hashlib
from datetime import datetime, timezone, timedelta

doctor_bp = Blueprint("doctor", __name__)

_predictor = PredictorService()


@doctor_bp.route("/doctor/register", methods=["POST"])
def register_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        name = data.get("name", "Médecin")
        specialty = data.get("specialty", "Généraliste")
        hospital = data.get("hospital", "")

        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        existing = get_db().collection("doctors").where("phone", "==", phone).stream()
        existing_docs = list(existing)

        if existing_docs:
            doc = existing_docs[0]
            d = doc.to_dict()
            return jsonify({
                "succes": True,
                "deja_existant": True,
                "id": doc.id,
                "status": d.get("status", "en_attente"),
                "name": d.get("name", "Médecin"),
            }), 200

        doc_ref = get_db().collection("doctors").document()
        doc_ref.set({
            "phone": phone,
            "name": name,
            "specialty": specialty,
            "hospital": hospital,
            "status": "en_attente",
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        return jsonify({
            "succes": True,
            "id": doc_ref.id,
            "name": name,
            "specialty": specialty,
            "hospital": hospital,
            "status": "en_attente",
        }), 200

    except Exception as e:
        current_app.logger.error(f"Doctor register error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/activate", methods=["POST"])
def activate_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        code = data.get("code", "").strip()

        if not phone or not code:
            return jsonify({"succes": False, "erreur": "phone et code requis"}), 400

        docs = list(get_db().collection("doctors").where("phone", "==", phone).limit(1).stream())
        if not docs:
            return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404

        doc = docs[0]
        d = doc.to_dict()

        if d.get("status") != "valide":
            return jsonify({"succes": False, "erreur": "Votre compte n'a pas encore été validé par l'administration"}), 403

        stored_code = d.get("activation_code") or d.get("liaison_code", "")
        if not stored_code:
            return jsonify({"succes": False, "erreur": "Aucun code d'activation trouvé. Contactez l'administration."}), 400

        if code != stored_code:
            return jsonify({"succes": False, "erreur": "Code d'activation incorrect"}), 400

        return jsonify({
            "succes": True,
            "message": "Compte activé avec succès",
            "doctor_id": doc.id,
            "name": d.get("name", "Médecin"),
        }), 200

    except Exception as e:
        current_app.logger.error(f"Doctor activate error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


DOCTOR_MAX_ATTEMPTS = 5
DOCTOR_LOCK_MINUTES = 15


def _now():
    return datetime.now(timezone.utc)



def _hash_pin(phone, pin):
    raw = f"{phone}|{pin}"
    return hashlib.sha256(raw.encode()).hexdigest()


def _send_doctor_alert(phone, message):
    try:
        from services.sms_service import SmsService
        sms = SmsService()
        if sms.is_configured:
            sms.send(phone, message)
    except Exception:
        pass


def _find_doctor_by_phone(db, phone):
    """Find the best doctor document by phone. Prefers the one with 'name' field."""
    docs = list(db.collection("doctors").where("phone", "==", phone).stream())
    if not docs:
        return None, None
    if len(docs) == 1:
        return docs[0], docs[0].to_dict()
    # Prefer document with 'name' field
    for doc in docs:
        d = doc.to_dict()
        if d.get("name"):
            return doc, d
    # Fallback to first
    return docs[0], docs[0].to_dict()


@doctor_bp.route("/doctor/pin/create", methods=["POST"])
def doctor_create_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pin = data.get("pin")

        if not phone or not pin:
            return jsonify({"succes": False, "erreur": "Champs requis"}), 400

        if len(str(pin)) != 4 or not str(pin).isdigit():
            return jsonify({"succes": False, "erreur": "Le PIN doit être un code à 4 chiffres"}), 400

        db = get_db()
        doc, d = _find_doctor_by_phone(db, phone)
        if not doc:
            return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404

        pin_hash = _hash_pin(phone, pin)
        db.collection("doctors").document(doc.id).set({
            "pin_hash": pin_hash,
        }, merge=True)

        return jsonify({"succes": True, "phone": phone}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor PIN create error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/pin/check", methods=["POST"])
def doctor_check_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        doc, d = _find_doctor_by_phone(db, phone)
        if not doc:
            return jsonify({"succes": True, "exists": False}), 200

        exists = "pin_hash" in d

        if d.get("status") != "valide":
            return jsonify({"succes": True, "exists": False, "status": d.get("status", "inconnu")}), 200

        locked_until = d.get("locked_until")
        is_locked = False
        remaining_seconds = 0

        if locked_until and isinstance(locked_until, datetime):
            remaining = (locked_until - _now()).total_seconds()
            if remaining > 0:
                is_locked = True
                remaining_seconds = int(remaining)

        return jsonify({
            "succes": True,
            "exists": exists,
            "is_locked": is_locked,
            "remaining_seconds": remaining_seconds,
            "failed_attempts": d.get("failed_attempts", 0),
            "max_attempts": DOCTOR_MAX_ATTEMPTS,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Doctor PIN check error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/pin/login", methods=["POST"])
def doctor_login_pin():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pin = data.get("pin")

        if not phone or not pin:
            return jsonify({"succes": False, "erreur": "Champs requis"}), 400

        db = get_db()
        doc, d = _find_doctor_by_phone(db, phone)
        if not doc:
            return jsonify({"succes": False, "erreur": "Aucun compte trouvé"}), 401

        doc_ref = db.collection("doctors").document(doc.id)
        stored_hash = d.get("pin_hash")
        if not stored_hash:
            return jsonify({"succes": False, "erreur": "Aucun PIN configuré"}), 401

        locked_until = d.get("locked_until")
        if locked_until and isinstance(locked_until, datetime):
            remaining = (locked_until - _now()).total_seconds()
            if remaining > 0:
                return jsonify({
                    "succes": False,
                    "erreur": f"Compte verrouillé. Réessayez dans {int(remaining // 60)} min.",
                    "locked": True,
                    "remaining_seconds": int(remaining),
                }), 401

        failed_attempts = d.get("failed_attempts", 0)

        if _hash_pin(phone, pin) != stored_hash:
            failed_attempts += 1
            remaining_attempts = DOCTOR_MAX_ATTEMPTS - failed_attempts

            if failed_attempts >= DOCTOR_MAX_ATTEMPTS:
                lock_until = _now() + timedelta(minutes=DOCTOR_LOCK_MINUTES)
                doc_ref.update({
                    "failed_attempts": failed_attempts,
                    "locked_until": lock_until,
                })
                _send_doctor_alert(phone, f"MamaGuard: Compte medecin verrouille {DOCTOR_LOCK_MINUTES} min apres {DOCTOR_MAX_ATTEMPTS} echecs.")
                return jsonify({
                    "succes": False,
                    "erreur": f"Compte verrouillé pour {DOCTOR_LOCK_MINUTES} minutes.",
                    "locked": True,
                    "remaining_seconds": DOCTOR_LOCK_MINUTES * 60,
                }), 401

            doc_ref.update({"failed_attempts": failed_attempts})
            return jsonify({
                "succes": False,
                "erreur": f"PIN incorrect ({remaining_attempts} essai{'s' if remaining_attempts > 1 else ''} restant{'s' if remaining_attempts > 1 else ''})",
                "remaining_attempts": remaining_attempts,
            }), 401

        doc_ref.update({
            "failed_attempts": 0,
            "locked_until": firestore.DELETE_FIELD,
        })
        return jsonify({"succes": True, "phone": phone}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor PIN login error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/lookup", methods=["POST"])
def lookup_doctor():
    try:
        data = request.get_json()
        code = data.get("code", "").strip().upper()

        if not code or len(code) < 4:
            return jsonify({"succes": False, "erreur": "Code de liaison invalide"}), 400

        docs = get_db().collection("doctors").where("liaison_code", "==", code).limit(1).stream()
        for doc in docs:
            d = doc.to_dict()
            return jsonify({
                "succes": True,
                "id": doc.id,
                "name": d.get("name", "Médecin"),
                "phone": d.get("phone", ""),
                "specialty": d.get("specialty", "Généraliste"),
            }), 200

        return jsonify({"succes": False, "erreur": "Aucun médecin trouvé avec ce code"}), 404

    except Exception as e:
        current_app.logger.error(f"Doctor lookup error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/link-doctor", methods=["POST"])
def link_patient_to_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        code = data.get("code", "").strip().upper()

        if not phone or not code:
            return jsonify({"succes": False, "erreur": "phone et code requis"}), 400

        doctor_docs = list(get_db().collection("doctors").where("liaison_code", "==", code).limit(1).stream())
        if not doctor_docs:
            return jsonify({"succes": False, "erreur": "Code de liaison invalide"}), 404

        doctor = doctor_docs[0]
        doctor_data = doctor.to_dict()

        db = get_db()
        link_ref = db.collection("patient_links").document()
        link_ref.set({
            "patient_phone": phone,
            "doctor_id": doctor.id,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "doctor_phone": doctor_data.get("phone", ""),
            "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
            "liaison_code": code,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        # Also save doctor info on the active pregnancy
        active_id, _ = get_active_pregnancy(db, phone)
        if active_id:
            db.collection("users").document(phone).collection("pregnancies").document(active_id).update({
                "doctor_phone": doctor_data.get("phone", ""),
                "doctor_name": doctor_data.get("name", "Médecin"),
                "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
            })

        # Notification for doctor
        patient_name = data.get("patient_name", "Une patiente")
        try:
            notif_ref = db.collection("doctors").document(doctor_data.get("phone", "")).collection("notifications").document()
            notif_ref.set({
                "type": "nouvelle_patiente",
                "title": "Nouvelle patiente liée",
                "message": f"{patient_name} s'est connectée à vous via le code de liaison.",
                "patient_phone": phone,
                "lu": False,
                "created_at": firestore.SERVER_TIMESTAMP,
            })

            # FCM push so it rings even when app is closed
            doctor_doc = db.collection("doctors").document(doctor.id).get()
            fcm_token = (doctor_doc.to_dict() or {}).get("fcm_token") if doctor_doc.exists else None
            if fcm_token:
                messaging = get_messaging()
                if messaging:
                    push = messaging.Message(
                        token=fcm_token,
                        notification=messaging.Notification(
                            title="MamaGuard - Nouvelle patiente",
                            body=f"{patient_name} s'est connectée à vous via le code de liaison.",
                        ),
                        data={"type": "nouvelle_patiente"},
                        android=messaging.AndroidConfig(
                            priority="high",
                            notification=messaging.AndroidNotification(
                                channel_id="mamaguard_general",
                                priority="high",
                                sound="alarm",
                            ),
                        ),
                        apns=messaging.APNSConfig(
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(sound="default", badge=1, alert=messaging.ApsAlert(title="MamaGuard", body=f"{patient_name} s'est connectée à vous.")),
                            ),
                        ),
                    )
                    messaging.send(push)
        except Exception as e:
            current_app.logger.warning(f"Doctor notification error: {e}")

        return jsonify({
            "succes": True,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "doctor_phone": doctor_data.get("phone", ""),
            "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
        }), 200

    except Exception as e:
        current_app.logger.error(f"Link doctor error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/doctor-info", methods=["POST"])
def get_linked_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()

        # First check active pregnancy for doctor
        _, preg_data = get_active_pregnancy(db, phone)
        if preg_data and preg_data.get("doctor_phone"):
            return jsonify({"succes": True, "docteur": {
                "doctor_phone": preg_data.get("doctor_phone", ""),
                "doctor_name": preg_data.get("doctor_name", ""),
                "doctor_specialty": preg_data.get("doctor_specialty", ""),
            }}), 200

        # Fallback to patient_links
        docs = db.collection("patient_links").where("patient_phone", "==", phone).limit(1).stream()
        for doc in docs:
            d = doc.to_dict()
            return jsonify({"succes": True, "docteur": d}), 200

        return jsonify({"succes": False, "erreur": "Aucun médecin lié"}), 404

    except Exception as e:
        current_app.logger.error(f"Doctor info error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/patients", methods=["POST"])
def get_doctor_patients():
    try:
        data = request.get_json()
        doctor_id = data.get("doctor_id")
        phone = data.get("phone")
        if not doctor_id and not phone:
            return jsonify({"succes": False, "erreur": "doctor_id ou phone requis"}), 400

        db = get_db()
        links = []

        if doctor_id:
            links = list(db.collection("patient_links").where("doctor_id", "==", doctor_id).stream())
        elif phone:
            doctor_docs = list(db.collection("doctors").where("phone", "==", phone).limit(1).stream())
            if not doctor_docs:
                return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404
            links = list(db.collection("patient_links").where("doctor_id", "==", doctor_docs[0].id).stream())

        patients = []
        for link in links:
            d = link.to_dict()
            patient_phone = d.get("patient_phone", "")
            if not patient_phone:
                continue

            user_doc = db.collection("users").document(patient_phone).get()
            user_data = user_doc.to_dict() if user_doc.exists else {}

            # Get active pregnancy data
            active_id, preg_data = get_active_pregnancy(db, patient_phone)
            preg_source = preg_data if preg_data else user_data

            latest_couleur = "normal"
            latest_score = "Normal"
            latest_date = ""
            latest_bpm = 0
            latest_spo2 = 0

            # Get measures from pregnancy or legacy
            if active_id and preg_data:
                measures = (
                    db.collection("users").document(patient_phone)
                    .collection("pregnancies").document(active_id)
                    .collection("measures")
                    .order_by("timestamp", direction=firestore.Query.DESCENDING)
                    .limit(1)
                    .get()
                )
            else:
                measures = (
                    db.collection("users").document(patient_phone)
                    .collection("measures")
                    .order_by("timestamp", direction=firestore.Query.DESCENDING)
                    .limit(1)
                    .get()
                )
            for m in measures:
                mv = m.to_dict()
                latest_couleur = mv.get("couleur", "normal")
                latest_score = mv.get("score", "Normal")
                latest_date = mv.get("date", "")
                latest_bpm = mv.get("bpm", 0)
                latest_spo2 = mv.get("spo2", 0)

            # Normaliser la couleur IA (rouge/orange/vert) vers les clés du dashboard
            color_map = {"rouge": "critique", "orange": "surveillance", "vert": "normal"}
            latest_couleur = color_map.get(latest_couleur, latest_couleur)

            patients.append({
                "phone": patient_phone,
                "name": user_data.get("name", "Patiente"),
                "pregnancy_week": compute_pregnancy_week(preg_source),
                "hospital": user_data.get("hospital", ""),
                "risk_color": latest_couleur,
                "risk_label": latest_score,
                "last_measure_date": latest_date,
                "last_bpm": latest_bpm,
                "last_spo2": latest_spo2,
            })

        risk_order = {"danger": 0, "critique": 1, "surveillance": 2, "normal": 3}
        patients.sort(key=lambda p: risk_order.get(p["risk_color"], 4))

        return jsonify({"succes": True, "patients": patients}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor patients error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/patient-dossier", methods=["POST"])
def get_patient_dossier():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        user_doc = db.collection("users").document(phone).get()
        user_data = user_doc.to_dict() if user_doc.exists else {}

        # Get active pregnancy data
        active_id, preg_data = get_active_pregnancy(db, phone)
        preg_source = preg_data if preg_data else user_data

        measures = []
        if active_id:
            docs = (
                db.collection("users").document(phone)
                .collection("pregnancies").document(active_id)
                .collection("measures")
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(20)
                .get()
            )
        else:
            docs = (
                db.collection("users").document(phone)
                .collection("measures")
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(20)
                .get()
            )
        for doc in docs:
            m = doc.to_dict()
            ts = m.get("timestamp")
            score = m.get("score", "")
            try:
                alert_info = _predictor.build_alert(score)
            except Exception:
                alert_info = {}
            measures.append({
                "id": doc.id,
                "date": m.get("date", ""),
                "heure": m.get("heure", ""),
                "bpm": m.get("bpm", 0),
                "temperature": m.get("temperature", 0),
                "spo2": m.get("spo2", 0),
                "tension_s": m.get("tension_s", 0),
                "tension_d": m.get("tension_d", 0),
                "contractions": m.get("contractions", 0),
                "semaine": m.get("semaine", 0),
                "score": score,
                "couleur": m.get("couleur", ""),
                "analyse": alert_info,
                "timestamp": ts.isoformat() if hasattr(ts, "isoformat") else str(ts),
            })

        alerts = []
        try:
            alert_docs = (
                db.collection("alertes")
                .where("phone", "==", phone)
                .order_by("vuAt", direction=firestore.Query.DESCENDING)
                .limit(20)
                .get()
            )
        except Exception:
            alert_docs = (
                db.collection("alertes")
                .where("phone", "==", phone)
                .limit(20)
                .get()
            )
        for doc in alert_docs:
            a = doc.to_dict()
            vu_ts = a.get("vuAt")
            alerts.append({
                "id": doc.id,
                "score": a.get("score", ""),
                "alertes": a.get("alertes", []),
                "vu": a.get("vu", False),
                "status": a.get("status", ""),
                "vuAt": vu_ts.isoformat() if hasattr(vu_ts, "isoformat") else str(vu_ts) if vu_ts else "",
            })

        return jsonify({
            "succes": True,
            "profile": {
                "name": user_data.get("name", ""),
                "pregnancy_week": compute_pregnancy_week(preg_source),
                "hospital": user_data.get("hospital", ""),
                "doctor_phone": preg_source.get("doctor_phone", ""),
                "doctor_name": preg_source.get("doctor_name", ""),
            },
            "measures": measures,
            "alerts": alerts,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Patient dossier error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/notifications", methods=["POST"])
def get_doctor_notifications():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        docs = (
            db.collection("doctors").document(phone)
            .collection("notifications")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(50)
            .get()
        )
        notifications = []
        for doc in docs:
            n = doc.to_dict()
            ts = n.get("created_at")
            notifications.append({
                "id": doc.id,
                "type": n.get("type", ""),
                "title": n.get("title", ""),
                "message": n.get("message", ""),
                "lu": n.get("lu", False),
                "created_at": ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else "",
            })

        unread = sum(1 for n in notifications if not n["lu"])

        return jsonify({"succes": True, "notifications": notifications, "unread": unread}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor notifications error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/notifications/lu", methods=["POST"])
def mark_doctor_notifications_read():
    try:
        data = request.get_json()
        phone = data.get("phone")
        notif_id = data.get("notification_id")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if notif_id:
            db.collection("doctors").document(phone).collection("notifications").document(notif_id).update({"lu": True})
        else:
            docs = db.collection("doctors").document(phone).collection("notifications").where("lu", "==", False).stream()
            for doc in docs:
                doc.reference.update({"lu": True})

        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor mark read error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/notifications", methods=["POST"])
def get_patient_notifications():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        docs = (
            db.collection("users").document(phone)
            .collection("notifications")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(50)
            .get()
        )
        notifications = []
        for doc in docs:
            n = doc.to_dict()
            ts = n.get("created_at")
            notifications.append({
                "id": doc.id,
                "type": n.get("type", ""),
                "title": n.get("title", ""),
                "message": n.get("message", ""),
                "lu": n.get("lu", False),
                "meet_link": n.get("meet_link", ""),
                "doctor_message": n.get("doctor_message", ""),
                "appointment_id": n.get("appointment_id", ""),
                "appointment_date": n.get("appointment_date", ""),
                "created_at": ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else "",
            })

        unread = sum(1 for n in notifications if not n["lu"])

        return jsonify({"succes": True, "notifications": notifications, "unread": unread}), 200

    except Exception as e:
        current_app.logger.error(f"Notifications error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/notifications/lu", methods=["POST"])
def mark_notifications_read():
    try:
        data = request.get_json()
        phone = data.get("phone")
        notif_id = data.get("notification_id")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if notif_id:
            db.collection("users").document(phone).collection("notifications").document(notif_id).update({"lu": True})
        else:
            docs = db.collection("users").document(phone).collection("notifications").where("lu", "==", False).stream()
            for doc in docs:
                doc.reference.update({"lu": True})

        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Mark read error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/set-appointment", methods=["POST"])
def set_appointment():
    try:
        data = request.get_json()
        patient_phone = data.get("patient_phone")
        appointment_date = data.get("appointment_date")
        notes = data.get("notes", "")
        doctor_name = data.get("doctor_name", "Votre médecin")

        if not patient_phone or not appointment_date:
            return jsonify({"succes": False, "erreur": "patient_phone et appointment_date requis"}), 400

        db = get_db()

        appt_ref = db.collection("appointments").document()
        appt_ref.set({
            "patient_phone": patient_phone,
            "appointment_date": appointment_date,
            "notes": notes,
            "doctor_name": doctor_name,
            "status": "planifié",
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        appointment_id = appt_ref.id

        # Notification for patient
        notif_ref = db.collection("users").document(patient_phone).collection("notifications").document()
        notif_ref.set({
            "type": "rendez_vous",
            "title": "Nouveau rendez-vous",
            "message": f"Votre médecin {doctor_name} a fixé un rendez-vous le {appointment_date}. Vous recevrez un rappel 24h avant.",
            "appointment_id": appointment_id,
            "lu": False,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        # FCM push so it rings even when the app is closed
        try:
            user_doc = db.collection("users").document(patient_phone).get()
            fcm_token = (user_doc.to_dict() or {}).get("fcm_token") if user_doc.exists else None
            if fcm_token:
                messaging = get_messaging()
                if messaging:
                    push = messaging.Message(
                        token=fcm_token,
                        notification=messaging.Notification(
                            title="MamaGuard - Nouveau rendez-vous",
                            body=f"Votre médecin {doctor_name} a fixé un rendez-vous le {appointment_date}.",
                        ),
                        data={"type": "rendez_vous", "appointment_date": appointment_date, "appointment_id": appointment_id},
                        android=messaging.AndroidConfig(
                            priority="high",
                            notification=messaging.AndroidNotification(
                                channel_id="mamaguard_reminder",
                                priority="high",
                                sound="alarm",
                            ),
                        ),
                        apns=messaging.APNSConfig(
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(sound="default", badge=1, alert=messaging.ApsAlert(title="MamaGuard", body=f"Rendez-vous le {appointment_date}.")),
                            ),
                        ),
                    )
                    messaging.send(push)
        except Exception as e:
            current_app.logger.warning(f"Appointment FCM error: {e}")

        # Create reminders: T-24h and T-1h
        try:
            from datetime import datetime, timedelta
            appt_dt = datetime.fromisoformat(appointment_date)

            for label, delta in [("24h", timedelta(days=1)), ("1h", timedelta(hours=1))]:
                remind_dt = appt_dt - delta
                remind_at = remind_dt.isoformat()

                rem_ref = db.collection("reminders").document()
                rem_ref.set({
                    "phone": patient_phone,
                    "title": f"Rappel: Consultation {doctor_name} ({label})",
                    "remind_at": remind_at,
                    "appointment_date": appointment_date,
                    "appointment_id": appointment_id,
                    "status": "actif",
                    "created_at": firestore.SERVER_TIMESTAMP,
                })
        except Exception as e:
            current_app.logger.warning(f"Could not create reminder: {e}")

        return jsonify({
            "succes": True,
            "appointment_id": appointment_id,
            "message": "Rendez-vous fixé avec succès",
        }), 200

    except Exception as e:
        current_app.logger.error(f"Set appointment error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/generate-teleconsultation-link", methods=["POST"])
def generate_teleconsultation_link():
    try:
        data = request.get_json()
        patient_phone = data.get("patient_phone")
        doctor_name = data.get("doctor_name", "Votre médecin")
        doctor_phone = data.get("doctor_phone", "")

        if not patient_phone:
            return jsonify({"succes": False, "erreur": "patient_phone requis"}), 400

        db = get_db()

        room_id = str(uuid.uuid4())[:8]
        meet_link = f"https://meet.jit.si/MamaGuard_{room_id}"

        doc_ref = db.collection("consultations").document()
        doc_ref.set({
            "patient_phone": patient_phone,
            "doctor_name": doctor_name,
            "doctor_phone": doctor_phone,
            "room_id": room_id,
            "meet_link": meet_link,
            "message": "",
            "initiated_by": "doctor",
            "invitation_sent": False,
            "status": "en_attente",
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        consultation_id = doc_ref.id

        return jsonify({
            "succes": True,
            "meet_link": meet_link,
            "room_id": room_id,
            "consultation_id": consultation_id,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Generate teleconsultation link error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/send-teleconsultation-invitation", methods=["POST"])
def send_teleconsultation_invitation():
    try:
        data = request.get_json()
        consultation_id = data.get("consultation_id")
        message = data.get("message", "")
        doctor_name = data.get("doctor_name", "Votre médecin")

        if not consultation_id:
            return jsonify({"succes": False, "erreur": "consultation_id requis"}), 400

        db = get_db()

        consult_ref = db.collection("consultations").document(consultation_id)
        consult_doc = consult_ref.get()
        if not consult_doc.exists:
            return jsonify({"succes": False, "erreur": "Consultation introuvable"}), 404

        consult_data = consult_doc.to_dict()
        patient_phone = consult_data.get("patient_phone")
        meet_link = consult_data.get("meet_link", "")

        if not patient_phone:
            return jsonify({"succes": False, "erreur": "patient_phone introuvable"}), 400

        consult_ref.update({
            "message": message,
            "invitation_sent": True,
        })

        # Notification for patient
        notif_ref = db.collection("users").document(patient_phone).collection("notifications").document()
        notif_ref.set({
            "type": "teleconsultation",
            "title": "Téléconsultation demandée",
            "message": f"Votre médecin {doctor_name} vous a envoyé une invitation pour une téléconsultation.",
            "meet_link": meet_link,
            "consultation_id": consultation_id,
            "doctor_message": message,
            "lu": False,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        # High-priority FCM push notification
        try:
            user_doc = db.collection("users").document(patient_phone).get()
            user_data = user_doc.to_dict() if user_doc.exists else {}
            fcm_token = user_data.get("fcm_token")

            if fcm_token:
                messaging = get_messaging()
                if messaging:
                    fcm_message = messaging.Message(
                        token=fcm_token,
                        notification=messaging.Notification(
                            title="MamaGuard - Téléconsultation",
                            body=f"Votre médecin {doctor_name} vous a envoyé une invitation pour une téléconsultation.",
                        ),
                        data={
                            "type": "teleconsultation",
                            "meet_link": meet_link,
                            "consultation_id": consultation_id,
                            "doctor_name": doctor_name,
                            "doctor_message": message,
                        },
                        android=messaging.AndroidConfig(
                            priority="high",
                            notification=messaging.AndroidNotification(
                                channel_id="mamaguard_teleconsultation",
                                priority="high",
                                sound="alarm",
                                click_action="FLUTTER_NOTIFICATION_CLICK",
                            ),
                        ),
                        apns=messaging.APNSConfig(
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(
                                    sound="default",
                                    badge=1,
                                    alert=messaging.ApsAlert(title="MamaGuard - Téléconsultation", body=f"Votre médecin {doctor_name} vous a envoyé une invitation."),
                                ),
                            ),
                        ),
                    )
                    messaging.send(fcm_message)
        except Exception as e:
            current_app.logger.warning(f"FCM push error: {e}")

        return jsonify({
            "succes": True,
            "message": "Invitation envoyée avec succès",
        }), 200

    except Exception as e:
        current_app.logger.error(f"Send invitation error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/profile", methods=["POST"])
def get_doctor_profile():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        doc, d = _find_doctor_by_phone(db, phone)
        if not doc:
            return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404

        return jsonify({
            "succes": True,
            "doctor": {
                "id": doc.id,
                "name": d.get("name", ""),
                "specialty": d.get("specialty", ""),
                "hospital": d.get("hospital", ""),
                "phone": d.get("phone", ""),
                "liaison_code": d.get("liaison_code", ""),
                "status": d.get("status", ""),
            }
        }), 200

    except Exception as e:
        current_app.logger.error(f"Doctor profile error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/fcm-token", methods=["POST"])
def save_doctor_fcm_token():
    try:
        data = request.get_json()
        phone = data.get("phone")
        fcm_token = data.get("fcm_token")
        if not phone or not fcm_token:
            return jsonify({"succes": False, "erreur": "phone et fcm_token requis"}), 400

        db = get_db()
        doc, _ = _find_doctor_by_phone(db, phone)
        if not doc:
            return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404

        doc.reference.update({"fcm_token": fcm_token})
        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor fcm-token error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
