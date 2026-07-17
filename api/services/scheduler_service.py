from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler

scheduler = BackgroundScheduler()
scheduler.start()


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
