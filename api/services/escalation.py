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
        if patient_info.get("platform_doctor_token"):
            actions.append({
                "type": "push",
                "to": "medecin_plateforme",
                "phone": patient_info.get("platform_doctor_phone"),
                "etapes": ["T+0", "T+10", "T+20"],
            })

        # Pas de SMS à la patiente : elle voit l'alerte dans l'application.
        for r in patient_info.get("sms_recipients", []):
            actions.append({
                "type": "sms",
                "to": r.get("label", r.get("role")),
                "phone": r.get("phone"),
                "message": messages["doctor"] if r.get("role") == "doctor" else messages["emergency_contact"],
                "etapes": ["T+0", "T+10", "T+20"],
            })

        return {
            "succes": True,
            "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            "escalation_level": escalation_level,
            "urgence": urgence,
            "actions": actions
        }
