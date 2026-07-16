from datetime import datetime
from utils.sms_formatter import format_sms


class EscalationService:

    def determine_level(self, score_risque, alertes):
        if score_risque == "Eleve":
            return "CRITIQUE", "IMMEDIATE"
        elif score_risque == "Modere" or (score_risque == "Eleve" and len(alertes) >= 3):
            return "URGENTE", "RAPPROCHEE"
        return "SURVEILLANCE", "AUCUNE"

    def build_messages(self, patient_name, score_risque, alertes, escalation_level):
        alert_summary = ", ".join(alertes[:3]) if alertes else "parametres anormaux"

        patient_msg = (
            f"MamaGuard ALERTE: {patient_name}, votre score de risque est "
            f"'{score_risque}'. {alert_summary}. "
            f"Consultez un medecin immediatement."
        )

        contact_msg = (
            f"MamaGuard URGENT: {patient_name} presente un risque "
            f"{escalation_level}. {alert_summary}. "
            f"Veuillez contacter votre proche ou les urgences."
        )

        doctor_msg = (
            f"MamaGuard ESCALADE: Patiente {patient_name} - "
            f"Risque {score_risque} / {escalation_level}. "
            f"Alerte: {alert_summary}. Consultez le dossier patient."
        )

        return {
            "patient": format_sms(patient_msg),
            "emergency_contact": format_sms(contact_msg),
            "doctor": format_sms(doctor_msg)
        }

    def escalate(self, patient_info, score_risque, alertes):
        escalation_level, urgence = self.determine_level(score_risque, alertes)
        messages = self.build_messages(
            patient_info.get("patient_name", "Patiente"),
            score_risque, alertes, escalation_level
        )

        actions = []
        actions.append({
            "type": "sms",
            "to": "patient",
            "phone": patient_info.get("phone"),
            "message": messages["patient"],
            "status": "pret"
        })

        for contact in patient_info.get("emergency_contacts", []):
            actions.append({
                "type": "sms",
                "to": contact.get("relation", "contact"),
                "phone": contact.get("phone"),
                "message": messages["emergency_contact"],
                "status": "pret"
            })

        if patient_info.get("doctor_phone"):
            actions.append({
                "type": "sms",
                "to": "medecin",
                "phone": patient_info["doctor_phone"],
                "message": messages["doctor"],
                "status": "pret"
            })

        return {
            "succes": True,
            "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            "escalation_level": escalation_level,
            "urgence": urgence,
            "actions": actions
        }
