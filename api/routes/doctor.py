from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db, get_messaging
import uuid

doctor_bp = Blueprint("doctor", __name__)


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

        stored_code = d.get("liaison_code", "")
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

        link_ref = get_db().collection("patient_links").document()
        link_ref.set({
            "patient_phone": phone,
            "doctor_id": doctor.id,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "doctor_phone": doctor_data.get("phone", ""),
            "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
            "liaison_code": code,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        # Notification for doctor
        patient_name = data.get("patient_name", "Une patiente")
        try:
            notif_ref = get_db().collection("doctors").document(doctor_data.get("phone", "")).collection("notifications").document()
            notif_ref.set({
                "type": "nouvelle_patiente",
                "title": "Nouvelle patiente liée",
                "message": f"{patient_name} s'est connectée à vous via le code de liaison.",
                "patient_phone": phone,
                "lu": False,
                "created_at": firestore.SERVER_TIMESTAMP,
            })
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

        docs = get_db().collection("patient_links").where("patient_phone", "==", phone).limit(1).stream()
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

            latest_couleur = "normal"
            latest_score = "Normal"
            latest_date = ""
            latest_bpm = 0
            latest_spo2 = 0

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

            patients.append({
                "phone": patient_phone,
                "name": user_data.get("name", "Patiente"),
                "pregnancy_week": user_data.get("pregnancy_week", 0),
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

        measures = []
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
                "score": m.get("score", ""),
                "couleur": m.get("couleur", ""),
                "timestamp": ts.isoformat() if hasattr(ts, "isoformat") else str(ts),
            })

        alerts = []
        alert_docs = db.collection("alertes").where("phone", "==", phone).order_by("vuAt", direction=firestore.Query.DESCENDING).limit(20).get() if False else []
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
                "pregnancy_week": user_data.get("pregnancy_week", 0),
                "hospital": user_data.get("hospital", ""),
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

        # Create reminder for 1 day before
        try:
            from datetime import datetime, timedelta
            appt_dt = datetime.fromisoformat(appointment_date)
            remind_dt = appt_dt - timedelta(days=1)
            remind_at = remind_dt.isoformat()

            rem_ref = db.collection("reminders").document()
            rem_ref.set({
                "phone": patient_phone,
                "title": f"Rappel: Consultation {doctor_name}",
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
                                sound="default",
                                click_action="FLUTTER_NOTIFICATION_CLICK",
                            ),
                        ),
                        apns=messaging.APNSConfig(
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(
                                    sound="default",
                                    badge=1,
                                    alert={"title": "MamaGuard - Téléconsultation", "body": f"Votre médecin {doctor_name} vous a envoyé une invitation."},
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
        docs = list(db.collection("doctors").where("phone", "==", phone).limit(1).stream())
        if not docs:
            return jsonify({"succes": False, "erreur": "Médecin non trouvé"}), 404

        doc = docs[0]
        d = doc.to_dict()

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
