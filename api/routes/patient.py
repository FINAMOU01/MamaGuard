import uuid
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.sms_service import SmsService

_sms_svc = SmsService()

patient_bp = Blueprint("patient", __name__)


@patient_bp.route("/patient/profile", methods=["POST"])
def profile():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        user_data = doc.to_dict() if doc.exists else {}

        name = data.get("name")
        if name is not None:
            name = name.strip()
            if not name:
                return jsonify({"succes": False, "erreur": "Le nom est requis"}), 400
            pregnancy_week = int(data.get("pregnancy_week", 0))
            hospital = data.get("hospital", "").strip()
            db.collection("users").document(phone).set({
                "name": name,
                "pregnancy_week": pregnancy_week,
                "hospital": hospital,
            }, merge=True)
            return jsonify({"succes": True, "phone": phone}), 200

        return jsonify({
            "succes": True,
            "profile": {
                "name": user_data.get("name", ""),
                "pregnancy_week": user_data.get("pregnancy_week", 0),
                "hospital": user_data.get("hospital", ""),
            }
        }), 200

    except Exception as e:
        current_app.logger.error(f"Profile error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/contacts", methods=["POST"])
def contacts():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        user_data = doc.to_dict() if doc.exists else {}

        contacts_data = data.get("contacts")
        if contacts_data is not None:
            if not isinstance(contacts_data, list):
                return jsonify({"succes": False, "erreur": "'contacts' doit être une liste"}), 400
            db.collection("users").document(phone).set({
                "emergency_contacts": contacts_data,
            }, merge=True)
            return jsonify({"succes": True, "phone": phone}), 200

        return jsonify({
            "succes": True,
            "contacts": user_data.get("emergency_contacts", []),
        }), 200

    except Exception as e:
        current_app.logger.error(f"Contacts error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/measure/save", methods=["POST"])
def save_measurement():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        measurement = {
            "timestamp": firestore.SERVER_TIMESTAMP,
            "date": data.get("date", ""),
            "heure": data.get("heure", ""),
            "bpm": data.get("bpm", 0),
            "temperature": data.get("temperature", 0),
            "spo2": data.get("spo2", 0),
            "tension_s": data.get("tension_s", 0),
            "tension_d": data.get("tension_d", 0),
            "contractions": data.get("contractions", 0),
            "semaine": data.get("semaine", 0),
            "score": data.get("score", ""),
            "couleur": data.get("couleur", ""),
        }

        doc_ref = db.collection("users").document(phone).collection("measures").document()
        doc_ref.set(measurement)
        return jsonify({"succes": True, "id": doc_ref.id}), 200

    except Exception as e:
        current_app.logger.error(f"Save measure error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/measure/history", methods=["POST"])
def get_history():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        from datetime import datetime, timedelta, timezone
        sept_jours = datetime.now(timezone.utc) - timedelta(days=7)

        docs = (
            db.collection("users").document(phone)
            .collection("measures")
            .where("timestamp", ">=", sept_jours)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .get()
        )

        mesures = []
        for doc in docs:
            m = doc.to_dict()
            ts = m.get("timestamp")
            mesures.append({
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
                "score": m.get("score", ""),
                "couleur": m.get("couleur", ""),
                "timestamp": ts.isoformat() if hasattr(ts, "isoformat") else str(ts),
            })

        return jsonify({"succes": True, "mesures": mesures}), 200

    except Exception as e:
        current_app.logger.error(f"History error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/report/sms", methods=["POST"])
def send_sms_report():
    try:
        data = request.get_json()
        phone = data.get("phone")
        doctor_phone = data.get("doctor_phone")
        patient_name = data.get("patient_name", "Patiente")
        score = data.get("score", "")
        bpm = data.get("bpm", 0)
        spo2 = data.get("spo2", 0)
        tension_s = data.get("tension_s", 0)
        tension_d = data.get("tension_d", 0)
        contractions = data.get("contractions", 0)

        if not phone or not doctor_phone:
            return jsonify({"succes": False, "erreur": "Champs requis: 'phone' et 'doctor_phone'"}), 400

        message = (
            f"MamaGuard - {patient_name}: Risque {score}. "
            f"BPM {bpm} SpO2 {spo2}% TA {tension_s}/{tension_d} "
            f"Ctx {contractions}/10min"
        )

        result = _sms_svc.send(doctor_phone, message, add_timestamp=True)
        status = 200 if result.get("succes") else 500
        return jsonify(result), status

    except Exception as e:
        current_app.logger.error(f"SMS report error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/consultation/create", methods=["POST"])
def create_consultation():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        room_id = str(uuid.uuid4())[:8]
        meet_link = f"https://meet.jit.si/MamaGuard_{room_id}"
        doc_ref = get_db().collection("consultations").document()
        doc_ref.set({
            "patient_phone": phone,
            "room_id": room_id,
            "meet_link": meet_link,
            "status": "en_attente",
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        return jsonify({"succes": True, "id": doc_ref.id, "meet_link": meet_link, "room_id": room_id}), 200

    except Exception as e:
        current_app.logger.error(f"Consultation create error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/consultations", methods=["POST"])
def get_consultations():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        docs = (
            get_db().collection("consultations")
            .where("patient_phone", "==", phone)
            .stream()
        )
        consultations = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            ts = d.get("created_at")
            d["created_at"] = ts.isoformat() if hasattr(ts, "isoformat") else str(ts)
            consultations.append(d)
        consultations.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        consultations = consultations[:20]

        return jsonify({"succes": True, "consultations": consultations}), 200

    except Exception as e:
        current_app.logger.error(f"Consultations list error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/reminder/create", methods=["POST"])
def create_reminder():
    try:
        data = request.get_json()
        phone = data.get("phone")
        remind_at = data.get("remind_at")
        title = data.get("title", "MamaGuard - Rappel de consultation")
        if not phone or not remind_at:
            return jsonify({"succes": False, "erreur": "phone et remind_at requis"}), 400

        doc_ref = get_db().collection("reminders").document()
        doc_ref.set({
            "phone": phone,
            "title": title,
            "remind_at": remind_at,
            "status": "actif",
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        return jsonify({"succes": True, "id": doc_ref.id}), 200

    except Exception as e:
        current_app.logger.error(f"Reminder create error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/reminders", methods=["POST"])
def get_reminders():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        docs = get_db().collection("reminders").where("phone", "==", phone).stream()
        reminders = []
        for doc in docs:
            d = doc.to_dict()
            d["id"] = doc.id
            ts = d.get("created_at")
            d["created_at"] = ts.isoformat() if hasattr(ts, "isoformat") else str(ts)
            reminders.append(d)
        reminders.sort(key=lambda x: x.get("remind_at", ""), reverse=True)

        return jsonify({"succes": True, "reminders": reminders}), 200

    except Exception as e:
        current_app.logger.error(f"Reminders list error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
