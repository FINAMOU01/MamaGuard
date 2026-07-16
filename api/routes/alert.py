from flask import Blueprint, request, jsonify
from services.escalation import EscalationService
from services.predictor import PredictorService
from utils.thresholds import analyze_parameters

alert_bp = Blueprint("alert", __name__)
escalation = EscalationService()
predictor = PredictorService()


@alert_bp.route("/alert", methods=["POST"])
def alert():
    try:
        data = request.get_json()

        patient_info = {
            "patient_id": data.get("patient_id"),
            "patient_name": data.get("patient_name"),
            "phone": data.get("phone"),
            "emergency_contacts": data.get("emergency_contacts", []),
            "doctor_phone": data.get("doctor_phone")
        }

        vitals = data.get("vitals")
        if vitals:
            result, _ = predictor.predict(
                vitals["bpm"], vitals["temperature"], vitals["spo2"],
                vitals["tension_systolique"], vitals["tension_diastolique"],
                vitals["contractions_par_10min"], vitals["semaine_grossesse"]
            )
            _, alertes, _ = analyze_parameters(
                vitals["bpm"], vitals["temperature"], vitals["spo2"],
                vitals["tension_systolique"], vitals["tension_diastolique"],
                vitals["contractions_par_10min"], vitals["semaine_grossesse"]
            )
            score_risque = result["score"]
        else:
            score_risque = data.get("score", "Inconnu")
            alertes = data.get("alertes", [])

        result = escalation.escalate(patient_info, score_risque, alertes)
        return jsonify(result)

    except Exception as e:
        return jsonify({
            "succes": False,
            "erreur": str(e)
        }), 400
