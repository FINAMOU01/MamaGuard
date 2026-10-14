from datetime import datetime
from flask import Blueprint, request, jsonify
from google.cloud import firestore
from google.cloud.firestore import SERVER_TIMESTAMP
from services.escalation import EscalationService
from services.predictor import PredictorService
from services.sms_service import SmsService
from services.fcm_service import FcmService
from services.firebase_service import get_db
from services.scheduler_service import schedule_step, cancel_pending_steps, send_escalation_notifications
from utils.thresholds import analyze_parameters

alert_bp = Blueprint("alert", __name__)
escalation = EscalationService()
predictor = PredictorService()
sms_service = SmsService()
fcm_service = FcmService()


def _resolve_platform_doctor(db, patient_info):
    """Retourne (telephone, token FCM) du médecin de la plateforme lié à la patiente."""
    try:
        if not db:
            return None, None
        doctor_phone = patient_info.get("doctor_phone")
        if not doctor_phone and patient_info.get("phone"):
            links = list(db.collection("patient_links")
                         .where("patient_phone", "==", patient_info.get("phone"))
                         .limit(1).stream())
            if links:
                doctor_phone = links[0].to_dict().get("doctor_phone")
        if not doctor_phone:
            return None, None
        doctor_docs = list(db.collection("doctors").where("phone", "==", doctor_phone).limit(1).stream())
        if not doctor_docs:
            return doctor_phone, None
        return doctor_phone, doctor_docs[0].to_dict().get("fcm_token")
    except Exception:
        import logging
        logging.getLogger(__name__).warning("Doctor lookup failed", exc_info=True)
        return None, None


def _sms_recipients(contacts, score_risque):
    """Destinataires SMS selon le niveau de risque.

    - Contact 'doctor' (médecin traitant hors plateforme) : Modere et Eleve.
    - Autres contacts d'urgence (conjoint, personne de confiance...) : Eleve uniquement.
    - La patiente ne reçoit jamais de SMS (elle voit l'alerte dans l'application).
    """
    recipients = []
    for c in contacts or []:
        phone = (c.get("phone") or "").strip()
        if not phone:
            continue
        is_doctor = c.get("type") == "doctor"
        if is_doctor or score_risque == "Eleve":
            recipients.append({
                "phone": phone,
                "role": "doctor" if is_doctor else "contact",
                "label": c.get("label") or c.get("relation") or c.get("type") or "contact",
            })
    return recipients


@alert_bp.route("/alert", methods=["POST"])
def alert():
    try:
        data = request.get_json()

        patient_info = {
            "patient_id": data.get("patient_id"),
            "patient_name": data.get("patient_name"),
            "phone": data.get("phone"),
            "emergency_contacts": data.get("emergency_contacts", []),
            "doctor_phone": data.get("doctor_phone"),
        }
        fcm_token = data.get("fcm_token")
        vitals = data.get("vitals")

        if vitals:
            result, _ = predictor.predict(
                vitals["bpm"], vitals["temperature"], vitals["spo2"],
                vitals["tension_systolique"], vitals["tension_diastolique"],
                vitals["contractions_par_10min"], vitals["semaine_grossesse"]
            )
            _, alertes, _ = analyze_parameters(
                vitals["bpm"], vitals["temperature"], vitals["spo2"],
                vitals["tension_systolique"], vitals["tension_diastolique"],
                vitals["contractions_par_10min"], vitals["semaine_grossesse"]
            )
            score_risque = result["score"]
        else:
            score_risque = data.get("score", "Inconnu")
            alertes = data.get("alertes", [])

        is_high = score_risque in ("Eleve", "Modere")

        # Une alerte n'atteint le médecin que si le risque est Eleve ou Modere.
        # En risque faible, on ne crée aucune alerte et on n'escalade pas.
        if not is_high:
            return jsonify({
                "succes": True,
                "score": score_risque,
                "escalation_level": "SURVEILLANCE",
                "urgence": "AUCUNE",
                "message": "Risque faible, aucune alerte envoyée au médecin.",
                "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            })

        db = get_db()

        # Contacts, nom et token : pris dans Firestore si l'appelant ne les fournit pas (application)
        if db and patient_info.get("phone") and (
                not patient_info.get("emergency_contacts") or not patient_info.get("patient_name")
                or not fcm_token):
            user_doc = db.collection("users").document(patient_info["phone"]).get()
            user_data = user_doc.to_dict() if user_doc.exists else {}
            if not patient_info.get("emergency_contacts"):
                patient_info["emergency_contacts"] = user_data.get("emergency_contacts", [])
            if not patient_info.get("patient_name"):
                patient_info["patient_name"] = user_data.get("name") or "Patiente"
            if not fcm_token:
                fcm_token = user_data.get("fcm_token")

        doctor_phone, doctor_token = _resolve_platform_doctor(db, patient_info)
        patient_info["platform_doctor_phone"] = doctor_phone
        patient_info["platform_doctor_token"] = doctor_token
        sms_recipients = _sms_recipients(patient_info.get("emergency_contacts"), score_risque)
        patient_info["sms_recipients"] = sms_recipients

        # --- Écrire dans Firestore ---
        firestore_id = None
        if db:
            alert_doc = {
                "patientId": patient_info.get("patient_id"),
                "patientName": patient_info.get("patient_name"),
                "phone": patient_info.get("phone"),
                "score": score_risque,
                "alertes": alertes,
                "emergencyContacts": patient_info.get("emergency_contacts"),
                "smsRecipients": sms_recipients,
                "doctorPhone": doctor_phone,
                "fcmToken": fcm_token,
                "vu": False,
                "escalated": True,
                "status": "escalade_en_cours",
                "createdAt": SERVER_TIMESTAMP,
                "t0Sent": False,
                "t10Sent": False,
                "t20Sent": False,
            }
            doc_ref = db.collection("alertes").add(alert_doc)
            firestore_id = doc_ref[1].id

        # --- T+0 : push à la patiente (pas de SMS : elle voit l'alerte dans l'app) ---
        if fcm_token:
            fcm_service.send_alert(fcm_token, firestore_id, score_risque, alertes, patient_info.get("patient_name"))

        # --- T+0 : push au médecin de la plateforme + SMS aux contacts ---
        send_escalation_notifications(patient_info, score_risque, alertes)

        if db and firestore_id:
            db.collection("alertes").document(firestore_id).update({
                "t0Sent": True,
            })

        # --- Relances T+10 et T+20 (annulées si l'alerte est vue) ---
        if firestore_id and (doctor_token or sms_recipients):
            schedule_step(firestore_id, "t10", 10, patient_info, score_risque, alertes)
            schedule_step(firestore_id, "t20", 20, patient_info, score_risque, alertes)

        # --- Réponse ---
        result = escalation.escalate(patient_info, score_risque, alertes)
        result["firestore_id"] = firestore_id
        result["medecin_plateforme_notifie"] = bool(doctor_token)
        return jsonify(result)

    except Exception as e:
        return jsonify({
            "succes": False,
            "erreur": str(e)
        }), 400


@alert_bp.route("/patient/alerts", methods=["POST"])
def get_patient_alerts():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firestore non configuré"}), 500

        docs = (
            db.collection("alertes")
            .where("phone", "==", phone)
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(50)
            .get()
        )

        alerts = []
        for doc in docs:
            a = doc.to_dict()
            created = a.get("createdAt")
            vu_ts = a.get("vuAt")
            alerts.append({
                "id": doc.id,
                "score": a.get("score", ""),
                "alertes": a.get("alertes", []),
                "vu": a.get("vu", False),
                "status": a.get("status", ""),
                "createdAt": created.isoformat() if hasattr(created, "isoformat") else str(created) if created else "",
                "vuAt": vu_ts.isoformat() if hasattr(vu_ts, "isoformat") else str(vu_ts) if vu_ts else "",
            })

        return jsonify({"succes": True, "alerts": alerts}), 200

    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Patient alerts error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@alert_bp.route("/alert/<alert_id>/vu", methods=["POST"])
def mark_vu(alert_id):
    try:
        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firestore non configuré"}), 500

        alert_ref = db.collection("alertes").document(alert_id)
        doc = alert_ref.get()
        if not doc.exists:
            return jsonify({"succes": False, "erreur": "Alerte introuvable"}), 404

        alert_data = doc.to_dict()

        # Cancel pending steps
        cancel_pending_steps(alert_id)

        alert_ref.update({
            "vu": True,
            "vuAt": SERVER_TIMESTAMP,
            "status": "alerte_vue",
        })

        # Create notification for patient
        patient_phone = alert_data.get("phone")
        if patient_phone:
            notif_ref = db.collection("users").document(patient_phone).collection("notifications").document()
            notif_ref.set({
                "type": "alerte_vue",
                "title": "Alerte prise en compte",
                "message": "Votre médecin a bien vu votre alerte. Il vous contactera si nécessaire.",
                "alert_id": alert_id,
                "lu": False,
                "created_at": SERVER_TIMESTAMP,
            })

        return jsonify({"succes": True, "message": "Alerte marquée comme vue"})

    except Exception as e:
        return jsonify({"succes": False, "erreur": str(e)}), 400


@alert_bp.route("/alert/<alert_id>", methods=["GET"])
def get_alert(alert_id):
    try:
        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firestore non configuré"}), 500

        doc = db.collection("alertes").document(alert_id).get()
        if not doc.exists:
            return jsonify({"succes": False, "erreur": "Alerte introuvable"}), 404

        return jsonify({"succes": True, "alert": doc.to_dict(), "id": doc.id})

    except Exception as e:
        return jsonify({"succes": False, "erreur": str(e)}), 400
