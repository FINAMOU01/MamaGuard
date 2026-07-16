from flask import Blueprint, request, jsonify
from services.reminder import ReminderService

remind_bp = Blueprint("remind", __name__)
service = ReminderService()


@remind_bp.route("/remind", methods=["POST"])
def remind():
    try:
        data = request.get_json()

        patient_name = data.get("patient_name")
        phone = data.get("phone")
        date = data.get("date")
        time = data.get("time")

        if not all([patient_name, phone, date, time]):
            return jsonify({
                "succes": False,
                "erreur": "Champs requis: 'patient_name', 'phone', 'date', 'time'"
            }), 400

        result = service.remind(
            patient_name=patient_name,
            phone=phone,
            date=date,
            time=time,
            doctor=data.get("doctor"),
            location=data.get("location"),
            notes=data.get("notes")
        )

        status = 200 if result["succes"] else 500
        return jsonify(result), status

    except Exception as e:
        return jsonify({
            "succes": False,
            "erreur": str(e)
        }), 400
