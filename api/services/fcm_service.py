from services.firebase_service import get_messaging


class FcmService:

    def send_doctor_alert(self, doctor_phone, doctor_token, patient_name, score_risque):
        """Prévient le médecin d'un risque détecté chez sa patiente."""
        messaging = get_messaging()
        if not messaging or not doctor_token:
            return {"succes": False, "erreur": "FCM non configuré ou token médecin manquant"}

        try:
            message = messaging.Message(
                token=doctor_token,
                notification=messaging.Notification(
                    title="\u26a0\ufe0f MamaGuard - Alerte patiente",
                    body=f"Risque {score_risque} détecté chez la patiente {patient_name}. Consultez son dossier.",
                ),
                data={
                    "type": "risk_alert",
                    "score": score_risque,
                },
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="mamaguard_critical",
                        priority="max",
                        sound="alarm",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="alarm.caf",
                            badge=1,
                            alert=messaging.ApsAlert(title="MamaGuard - Alerte patiente", body=f"Risque {score_risque} détecté chez la patiente {patient_name}. Consultez son dossier."),
                        ),
                    ),
                ),
            )
            response = messaging.send(message)
            return {"succes": True, "response": response}
        except Exception as e:
            return {"succes": False, "erreur": str(e)}

    def send_alert(self, fcm_token, alert_id, score, alertes, patient_name):
        messaging = get_messaging()
        if not messaging or not fcm_token:
            return {"succes": False, "erreur": "FCM non configuré ou token manquant"}

        try:
            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title="\U0001f6a8 MamaGuard - Alerte sanitaire",
                    body=f"Risque {score}. {', '.join(alertes[:2])}",
                ),
                data={
                    "alertId": alert_id,
                    "score": score,
                    "type": "risk_alert",
                },
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="mamaguard_critical",
                        priority="max",
                        sound="alarm",
                        vibrate_timings_millis=[1000, 1000, 1000],
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="alarm.caf",
                            badge=1,
                            alert=messaging.ApsAlert(title="MamaGuard", body=f"Risque {score}"),
                        ),
                    ),
                ),
            )
            response = messaging.send(message)
            return {"succes": True, "response": response}
        except Exception as e:
            return {"succes": False, "erreur": str(e)}
