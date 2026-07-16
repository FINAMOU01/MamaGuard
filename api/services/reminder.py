from datetime import datetime
from services.sms_service import SmsService
from utils.sms_formatter import format_sms


class ReminderService:

    def __init__(self):
        self.sms = SmsService()

    def build_message(self, patient_name, date, time, doctor, location, notes=None):
        msg = (
            f"MamaGuard RAPPEL: {patient_name}, "
            f"vous avez un rendez-vous le {date} a {time}"
        )
        if doctor:
            msg += f" avec Dr. {doctor}"
        if location:
            msg += f" a {location}"
        if notes:
            msg += f". {notes}"
        msg += ". Merci de confirmer votre presence."
        return format_sms(msg)

    def remind(self, patient_name, phone, date, time, doctor=None, location=None, notes=None):
        message = self.build_message(patient_name, date, time, doctor, location, notes)
        result = self.sms.send(phone, message)

        return {
            "succes": result["succes"],
            "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            "type": "rappel_consultation",
            "patient": patient_name,
            "rendez_vous": {
                "date": date,
                "heure": time,
                "medecin": doctor,
                "lieu": location
            },
            "sms": {
                "to": phone,
                "message": message,
                "sid": result.get("sid"),
                "status": result.get("status", result.get("erreur"))
            }
        }
