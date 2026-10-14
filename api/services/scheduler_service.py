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


def send_escalation_notifications(patient_info, score, alertes, step_label="T+0"):
    """Envoie une vague d'alerte : push au médecin de la plateforme + SMS aux contacts.

    Les destinataires SMS sont calculés une seule fois dans /alert
    (patient_info["sms_recipients"]) : contact médecin pour Modere/Eleve,
    autres contacts pour Eleve uniquement. Jamais de SMS à la patiente.
    """
    import logging
    from services.sms_service import SmsService
    from services.fcm_service import FcmService

    log = logging.getLogger(__name__)
    name = patient_info.get("patient_name") or "Patiente"
    summary = ", ".join((alertes or [])[:3]) or "parametres anormaux"
    rappel = "" if step_label == "T+0" else f" (rappel {step_label})"

    token = patient_info.get("platform_doctor_token")
    if token:
        try:
            FcmService().send_doctor_alert(
                patient_info.get("platform_doctor_phone"), token, name, score)
        except Exception as e:
            log.warning(f"Doctor push error ({step_label}): {e}")

    sms = SmsService()
    for r in patient_info.get("sms_recipients", []):
        if r.get("role") == "doctor":
            msg = (f"MamaGuard ALERTE{rappel}: patiente {name} - risque {score}. "
                   f"{summary}. Merci de la contacter rapidement.")
        else:
            msg = (f"MamaGuard URGENT{rappel}: {name} presente un risque {score}. "
                   f"{summary}. Contactez-la ou appelez les urgences.")
        try:
            sms.send(r["phone"], msg)
        except Exception as e:
            log.warning(f"SMS error to {r.get('phone')} ({step_label}): {e}")


def execute_escalation_step(alert_id, step_type, patient_info, score, alertes):
    from services.firebase_service import get_db
    from google.cloud.firestore import SERVER_TIMESTAMP

    db = get_db()

    # Sécurité : ne pas relancer si l'alerte a déjà été vue par le médecin
    if db:
        doc = db.collection("alertes").document(alert_id).get()
        if doc.exists and (doc.to_dict() or {}).get("vu"):
            return

    step_label = "T+10" if step_type == "t10" else "T+20"
    send_escalation_notifications(patient_info, score, alertes, step_label)

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
