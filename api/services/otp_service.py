import os
import random
import json
import redis
from datetime import datetime, timedelta
from config import Config
from services.sms_service import SmsService

REDIS_OTP_PREFIX = "otp:"
OTP_TTL = 300  # 5 minutes
OTP_LENGTH = 6


class OtpService:

    def __init__(self):
        self.sms = SmsService()
        self._redis = None

    @property
    def redis(self):
        if self._redis is None:
            self._redis = redis.Redis(
                host=Config.REDIS_HOST,
                port=Config.REDIS_PORT,
                decode_responses=True,
            )
        return self._redis

    def _generate_code(self):
        return str(random.randint(10 ** (OTP_LENGTH - 1), 10**OTP_LENGTH - 1))

    def send_otp(self, phone):
        code = self._generate_code()
        key = f"{REDIS_OTP_PREFIX}{phone}"
        self.redis.setex(key, OTP_TTL, code)
        message = f"MamaGuard: Votre code de verification est {code}. Valable 5 minutes."
        result = self.sms.send(phone, message)
        result["code"] = code
        return result

    def verify_otp(self, phone, code):
        key = f"{REDIS_OTP_PREFIX}{phone}"
        stored = self.redis.get(key)
        if stored is None:
            return {"succes": False, "erreur": "Code expiré ou inexistant"}
        if stored != code:
            return {"succes": False, "erreur": "Code incorrect"}
        self.redis.delete(key)
        return {"succes": True, "phone": phone}
