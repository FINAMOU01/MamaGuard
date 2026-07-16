from flask import Blueprint, request, jsonify
from services.predictor import PredictorService
from utils.thresholds import analyze_parameters

prediction_bp = Blueprint("prediction", __name__)
service = PredictorService()


@prediction_bp.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.get_json()

        bpm = data["bpm"]
        temperature = data["temperature"]
        spo2 = data["spo2"]
        tension_s = data["tension_systolique"]
        tension_d = data["tension_diastolique"]
        contractions = data["contractions_par_10min"]
        semaine = data["semaine_grossesse"]

        result, proba_dict = service.predict(bpm, temperature, spo2, tension_s, tension_d, contractions, semaine)
        details, alertes, analyse = analyze_parameters(bpm, temperature, spo2, tension_s, tension_d, contractions, semaine)
        alert = service.build_alert(result["score"])

        return jsonify({
            **result,
            **alert,
            "analyse": analyse,
            "details": details,
            "alertes": alertes,
            "probabilites": proba_dict,
            "parametres_recus": {
                "bpm": bpm,
                "temperature": temperature,
                "spo2": spo2,
                "tension": f"{tension_s}/{tension_d} mmHg",
                "contractions": f"{contractions}/10min",
                "semaine": semaine
            }
        })

    except Exception as e:
        return jsonify({
            "succes": False,
            "erreur": str(e)
        }), 400


@prediction_bp.route("/", methods=["GET"])
def home():
    return jsonify({
        "message": "API MamaGuard operationnelle",
        "version": "2.0",
        "routes": {
            "GET  /": "Verifier que l'API fonctionne",
            "POST /predict": "Prediction du risque prenatal",
            "POST /alert": "Declenchement escalade urgence",
            "POST /sms": "Envoi SMS via Twilio",
            "GET /sms/status": "Statut configuration Twilio",
            "POST /remind": "Rappels de consultation",
            "POST /sms/format": "Preview formatage SMS 160 car."
        }
    })
