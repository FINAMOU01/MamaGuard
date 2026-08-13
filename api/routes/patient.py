import uuid
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.sms_service import SmsService
from services.predictor import PredictorService
from services.pregnancy_service import (
    get_active_pregnancy,
    get_active_or_legacy,
    create_pregnancy,
    compute_pregnancy_week,
)

_sms_svc = SmsService()
_predictor = PredictorService()

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
            hospital = data.get("hospital", "").strip()
            db.collection("users").document(phone).set({
                "name": name,
                "hospital": hospital,
            }, merge=True)

            preg_method = data.get("pregnancy_method")
            if preg_method:
                active_id, _ = get_active_pregnancy(db, phone)
                if active_id:
                    # Update existing pregnancy
                    preg_ref = db.collection("users").document(phone).collection("pregnancies").document(active_id)
                    preg_update = {
                        "pregnancy_method": preg_method,
                        "due_date": data.get("due_date", ""),
                    }
                    if preg_method == "lmp":
                        preg_update["lmp_date"] = data.get("lmp_date", "")
                        preg_update["manual_week"] = 0
                        preg_update["reference_date"] = ""
                        from datetime import datetime, timedelta, timezone
                        lmp_str = data.get("lmp_date", "")
                        if lmp_str:
                            try:
                                lmp_dt = datetime.strptime(lmp_str, "%Y-%m-%d")
                                due = lmp_dt + timedelta(days=280)
                                preg_update["due_date"] = due.strftime("%Y-%m-%d")
                                diff = (datetime.now(timezone.utc) - lmp_dt.replace(tzinfo=timezone.utc)).days
                                preg_update["manual_week"] = max(0, diff // 7)
                            except (ValueError, TypeError):
                                pass
                    elif preg_method == "manual":
                        preg_update["manual_week"] = int(data.get("manual_week", 0))
                        preg_update["reference_date"] = data.get("reference_date", "")
                        preg_update["lmp_date"] = ""
                    preg_ref.update(preg_update)
                else:
                    # Create new pregnancy
                    create_pregnancy(db, phone, {
                        "pregnancy_method": preg_method,
                        "lmp_date": data.get("lmp_date", ""),
                        "manual_week": data.get("manual_week", 0),
                        "reference_date": data.get("reference_date", ""),
                        "due_date": data.get("due_date", ""),
                    })

            return jsonify({"succes": True, "phone": phone}), 200

        # GET: return profile + active pregnancy data
        preg_id, preg_data, is_preg = get_active_or_legacy(db, phone)
        week = compute_pregnancy_week(preg_data) if preg_data else 0

        return jsonify({
            "succes": True,
            "profile": {
                "name": user_data.get("name", ""),
                "hospital": user_data.get("hospital", ""),
                "pregnancy_method": preg_data.get("pregnancy_method", "") if preg_data else "",
                "lmp_date": preg_data.get("lmp_date", "") if preg_data else "",
                "manual_week": week,
                "reference_date": preg_data.get("reference_date", "") if preg_data else "",
                "due_date": preg_data.get("due_date", "") if preg_data else "",
                "has_active_pregnancy": preg_id is not None,
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


def _get_measures_ref(db, phone):
    """Get the right measures subcollection ref (from active pregnancy or legacy)."""
    active_id, _ = get_active_pregnancy(db, phone)
    if active_id:
        return db.collection("users").document(phone).collection("pregnancies").document(active_id).collection("measures")
    return db.collection("users").document(phone).collection("measures")


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

        measures_ref = _get_measures_ref(db, phone)
        doc_ref = measures_ref.document()
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

        measures_ref = _get_measures_ref(db, phone)
        docs = (
            measures_ref
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


@patient_bp.route("/patient/vitals/live", methods=["POST"])
def live_vitals():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        vitals = data.get("vitals")

        # Écrire la mesure temps réel (mise à jour à chaque envoi du capteur)
        if vitals:
            live_doc = {
                "bpm": vitals.get("bpm", 0),
                "spo2": vitals.get("spo2", 0),
                "temperature": vitals.get("temperature", 0),
                "tension_systolique": vitals.get("tension_systolique", 0),
                "tension_diastolique": vitals.get("tension_diastolique", 0),
                "contractions_par_10min": vitals.get("contractions_par_10min", 0),
                "semaine_grossesse": vitals.get("semaine_grossesse", 0),
                "timestamp": firestore.SERVER_TIMESTAMP,
            }

            # Calcul du score IA
            score = ""
            couleur = "normal"
            try:
                result, _ = _predictor.predict(
                    vitals.get("bpm", 0), vitals.get("temperature", 0),
                    vitals.get("spo2", 0), vitals.get("tension_systolique", 0),
                    vitals.get("tension_diastolique", 0),
                    vitals.get("contractions_par_10min", 0),
                    vitals.get("semaine_grossesse", 0),
                )
                score = result.get("score", "")
                alert_info = _predictor.build_alert(score)
                couleur = alert_info.get("couleur", "normal")
                live_doc["score"] = score
                live_doc["couleur"] = couleur
            except Exception as e:
                current_app.logger.warning(f"Live vitals predict error: {e}")

            db.collection("users").document(phone).collection("live").document("current").set(live_doc)
            return jsonify({
                "succes": True,
                "score": score,
                "couleur": couleur,
            }), 200

        # Lecture de la dernière mesure temps réel
        current = db.collection("users").document(phone).collection("live").document("current").get()
        data_out = current.to_dict() if current.exists else {}
        ts = data_out.get("timestamp")
        data_out["timestamp"] = ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else ""
        return jsonify({"succes": True, "vitals": data_out}), 200

    except Exception as e:
        current_app.logger.error(f"Live vitals error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/manual-measure/save", methods=["POST"])
def save_manual_measure():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        db.collection("users").document(phone).set({
            "pending_manual": {
                "tension_s": data.get("tension_s", 0),
                "tension_d": data.get("tension_d", 0),
                "contractions": data.get("contractions", 0),
                "semaine": data.get("semaine", 0),
                "saved_at": firestore.SERVER_TIMESTAMP,
            }
        }, merge=True)
        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Save manual measure error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/manual-measure", methods=["POST"])
def get_manual_measure():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        doc = db.collection("users").document(phone).get()
        pending = (doc.to_dict() or {}).get("pending_manual") or {}
        return jsonify({
            "succes": True,
            "pending_manual": pending,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Get manual measure error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/manual-measure/clear", methods=["POST"])
def clear_manual_measure():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        db.collection("users").document(phone).update({"pending_manual": None})
        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Clear manual measure error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@patient_bp.route("/patient/fcm-token", methods=["POST"])
def save_fcm_token():
    try:
        data = request.get_json()
        phone = data.get("phone")
        fcm_token = data.get("fcm_token")
        if not phone or not fcm_token:
            return jsonify({"succes": False, "erreur": "phone et fcm_token requis"}), 400

        get_db().collection("users").document(phone).set({
            "fcm_token": fcm_token,
        }, merge=True)
        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"FCM token error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
