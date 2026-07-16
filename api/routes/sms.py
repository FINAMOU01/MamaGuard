from flask import Blueprint, request, jsonify
from services.sms_service import SmsService
from utils.sms_formatter import preview

sms_bp = Blueprint("sms", __name__)
service = SmsService()


@sms_bp.route("/sms", methods=["POST"])
def send_sms():
    try:
        data = request.get_json()

        to = data.get("to")
        message = data.get("message")
        add_timestamp = request.args.get("timestamp", "0") == "1"

        if not to or not message:
            return jsonify({
                "succes": False,
                "erreur": "Champs requis: 'to' et 'message'"
            }), 400

        result = service.send(to, message, add_timestamp=add_timestamp)
        status = 200 if result["succes"] else 500
        return jsonify(result), status

    except Exception as e:
        return jsonify({
            "succes": False,
            "erreur": str(e)
        }), 400


@sms_bp.route("/sms/status", methods=["GET"])
def status():
    return jsonify({
        "twilio_configured": service.is_configured
    })


@sms_bp.route("/sms/format", methods=["POST"])
def format_preview():
    try:
        data = request.get_json()
        text = data.get("message", "")
        return jsonify(preview(text))
    except Exception as e:
        return jsonify({"erreur": str(e)}), 400
