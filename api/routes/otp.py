from flask import Blueprint, request, jsonify, current_app
from services.otp_service import OtpService

otp_bp = Blueprint("otp", __name__)
service = OtpService()


@otp_bp.route("/otp/send", methods=["POST"])
def send_otp():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "Champ requis: 'phone'"}), 400
        result = service.send_otp(phone)
        # Toujours retourner 200 même si Twilio rate-limité
        # (l'OTP est stocké en Redis, vérifiable)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"succes": False, "erreur": str(e)}), 500


@otp_bp.route("/otp/verify", methods=["POST"])
def verify_otp():
    try:
        data = request.get_json()
        current_app.logger.info(f"Verify OTP received data: {data}")
        phone = data.get("phone")
        code = data.get("code")
        current_app.logger.info(f"phone='{phone}', code='{code}'")
        if not phone or not code:
            return jsonify({"succes": False, "erreur": "Champs requis: 'phone' et 'code'"}), 400
        result = service.verify_otp(phone, code)
        status = 200 if result.get("succes") else 401
        return jsonify(result), status
    except Exception as e:
        app.logger.error(f"Verify OTP error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
