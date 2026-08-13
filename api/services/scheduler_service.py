from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from google.cloud import firestore

scheduler = BackgroundScheduler()
scheduler.start()


def _send_fcm_push(db, phone, body, msg_type, channel_id, sound="alarm"):
    """Send a high-priority FCM push notification so it rings even when app is closed."""
    try:
        from services.firebase_service import get_messaging
        user_doc = db.collection("users").document(phone).get()
        if not user_doc.exists:
            return
        fcm_token = user_doc.to_dict().get("fcm_token")
        if not fcm_token:
            return

        messaging = get_messaging()
        if not messaging:
            return

        message = messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(
                title="MamaGuard",
                body=body,
            ),
            data={"type": msg_type},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id=channel_id,
                    priority="high",
                    sound=sound,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                        alert=messaging.ApsAlert(title="MamaGuard", body=body),
                    ),
                ),
            ),
        )
        messaging.send(message)
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"FCM reminder push error: {e}")


def check_reminders():
    from services.firebase_service import get_db
    from services.sms_service import SmsService

    db = get_db()
    if not db:
        return

    sms = SmsService()
    now = datetime.now().isoformat()

    try:
        docs = db.collection("reminders").where("status", "==", "actif").stream()
        for doc in docs:
            d = doc.to_dict()
            remind_at = d.get("remind_at", "")
            if remind_at and remind_at <= now:
                phone = d.get("phone", "")
                title = d.get("title", "Rappel de consultation")
                appointment_date = d.get("appointment_date", "")
                appointment_id = d.get("appointment_id", "")

                if phone:
                    body = f"Rappel de consultation : {title}."
                    if appointment_date:
                        body = f"Rendez-vous prévu le {appointment_date}. Restez attentive à votre suivi."
                    sms.send(phone, f"MamaGuard: {title}. Rendez-vous le {appointment_date}." if appointment_date else f"MamaGuard: {title}.")
                    _send_fcm_push(db, phone, body, "rappel", "mamaguard_reminder")

                notif_ref = db.collection("users").document(phone).collection("notifications").document()
                notif_ref.set({
                    "type": "rappel",
                    "title": title,
                    "message": f"Rappel: {title}",
                    "appointment_id": appointment_id,
                    "appointment_date": appointment_date,
                    "lu": False,
                    "created_at": firestore.SERVER_TIMESTAMP,
                })

                doc.reference.update({"status": "envoye"})
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Reminder check error: {e}")


scheduler.add_job(check_reminders, "interval", minutes=1, id="check_reminders", replace_existing=True)


def schedule_step(alert_id, step_type, delay_minutes, patient_info, score, alertes):
    run_date = datetime.now() + timedelta(minutes=delay_minutes)

    scheduler.add_job(
        execute_escalation_step,
        "date",
        run_date=run_date,
        args=[alert_id, step_type, patient_info, score, alertes],
        id=f"{alert_id}_{step_type}",
        replace_existing=True,
    )


def execute_escalation_step(alert_id, step_type, patient_info, score, alertes):
    from services.sms_service import SmsService
    from services.firebase_service import get_db

    sms = SmsService()

    if step_type == "t10":
        for contact in patient_info.get("emergency_contacts", []):
            msg = (
                f"MamaGuard URGENT: {patient_info.get('patient_name')} "
                f"presente un risque {score}. {', '.join(alertes[:3])}. "
                f"Veuillez contacter votre proche ou les urgences."
            )
            sms.send(contact["phone"], msg)

    elif step_type == "t20":
        doctor_phone = patient_info.get("doctor_phone")
        if doctor_phone:
            msg = (
                f"MamaGuard ESCALADE: Patiente {patient_info.get('patient_name')} "
                f"- Risque {score}. {', '.join(alertes[:3])}. "
                f"Consultez le dossier patient."
            )
            sms.send(doctor_phone, msg)

    # Update Firestore
    from google.cloud.firestore import SERVER_TIMESTAMP
    db = get_db()
    if db:
        field = f"{step_type}Sent"
        db.collection("alertes").document(alert_id).update({
            field: True,
            f"{field}At": SERVER_TIMESTAMP,
        })


def cancel_pending_steps(alert_id):
    for step_type in ["t10", "t20"]:
        job_id = f"{alert_id}_{step_type}"
        if scheduler.get_job(job_id):
            scheduler.remove_job(job_id)
