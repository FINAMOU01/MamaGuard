from services.firebase_service import get_messaging


class FcmService:

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
                        vibration_pattern=[1000, 1000, 1000],
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="alarm.caf",
                            badge=1,
                            alert={"title": "MamaGuard", "body": f"Risque {score}"},
                        ),
                    ),
                ),
            )
            response = messaging.send(message)
            return {"succes": True, "response": response}
        except Exception as e:
            return {"succes": False, "erreur": str(e)}
