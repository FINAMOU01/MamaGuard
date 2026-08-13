import os
from twilio.rest import Client
from utils.sms_formatter import format_sms


class SmsService:

    def __init__(self):
        self.account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        self.auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        self.from_number = os.getenv("TWILIO_PHONE_NUMBER")
        self.enabled = os.getenv("SMS_ENABLED", "true").lower() in ("1", "true", "yes", "on")
        self._client = None

    @property
    def client(self):
        if self._client is None and self.account_sid and self.auth_token:
            self._client = Client(self.account_sid, self.auth_token)
        return self._client

    @property
    def is_configured(self):
        return all([self.account_sid, self.auth_token, self.from_number])

    def send(self, to, message, add_timestamp=False):
        if not self.enabled:
            return {
                "succes": False,
                "erreur": "SMS desactive (SMS_ENABLED=false) - aucun SMS envoye pour proteger le compte Twilio",
                "to": to,
            }
        if not self.is_configured:
            return {
                "succes": False,
                "erreur": "Twilio non configure (verifier TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER)"
            }
        try:
            body = format_sms(message, add_timestamp=add_timestamp)
            sms = self.client.messages.create(
                body=body,
                from_=self.from_number,
                to=to
            )
            return {
                "succes": True,
                "sid": sms.sid,
                "status": sms.status,
                "to": to,
                "message": body
            }
        except Exception as e:
            return {
                "succes": False,
                "erreur": str(e),
                "to": to
            }
