import pickle
import pandas as pd
from datetime import datetime
from config import Config


class PredictorService:

    def __init__(self):
        model_path = f"{Config.MODEL_DIR}/model_mamaguard.pkl"
        encoder_path = f"{Config.MODEL_DIR}/label_encoder.pkl"
        features_path = f"{Config.MODEL_DIR}/feature_names.pkl"

        with open(model_path, "rb") as f:
            self.model = pickle.load(f)
        with open(encoder_path, "rb") as f:
            self.le = pickle.load(f)
        with open(features_path, "rb") as f:
            self.feature_names = pickle.load(f)

    def _engineer_features(self, bpm, temperature, spo2, tension_s, tension_d, contractions, semaine):
        pulse_pressure = tension_s - tension_d
        indice_tension = round(tension_s / tension_d, 2)
        fievre = 1 if temperature >= 37.6 else 0
        spo2_basse = 1 if spo2 < 95 else 0
        trimestre = 1 if semaine <= 12 else 2 if semaine <= 26 else 3

        return pd.DataFrame([{
            "bpm": bpm,
            "temperature": temperature,
            "spo2": spo2,
            "tension_systolique": tension_s,
            "tension_diastolique": tension_d,
            "contractions_par_10min": contractions,
            "semaine_grossesse": semaine,
            "pulse_pressure": pulse_pressure,
            "indice_tension": indice_tension,
            "fievre": fievre,
            "spo2_basse": spo2_basse,
            "trimestre": trimestre
        }])

    def predict(self, bpm, temperature, spo2, tension_s, tension_d, contractions, semaine):
        input_data = self._engineer_features(bpm, temperature, spo2, tension_s, tension_d, contractions, semaine)

        prediction = self.model.predict(input_data)
        score_risque = self.le.inverse_transform(prediction)[0]

        probabilities = self.model.predict_proba(input_data)[0]
        classes = self.le.classes_
        proba_dict = {
            classes[i]: round(float(probabilities[i]) * 100, 1)
            for i in range(len(classes))
        }
        confiance = round(max(probabilities) * 100, 1)

        maintenant = datetime.now()

        return {
            "succes": True,
            "timestamp": maintenant.strftime("%Y-%m-%dT%H:%M:%S"),
            "date": maintenant.strftime("%Y-%m-%d"),
            "heure": maintenant.strftime("%H:%M"),
            "score": score_risque,
            "confiance": f"{confiance}%",
        }, proba_dict

    def build_alert(self, score_risque):
        if score_risque == "Eleve":
            return {
                "niveau_urgence": "CRITIQUE",
                "urgence": "IMMEDIATE",
                "recommandation": "Consultez immediatement un professionnel de sante ou rendez-vous dans le centre de sante le plus proche.",
                "resume": "Plusieurs parametres vitaux sont hors des seuils cliniques recommandes. Une consultation medicale urgente est fortement conseillee.",
                "couleur": "rouge",
                "emoji": "ROUGE"
            }
        elif score_risque == "Modere":
            return {
                "niveau_urgence": "SURVEILLANCE",
                "urgence": "RAPPROCHEE",
                "recommandation": "Contactez votre sage-femme ou votre medecin dans les 24 heures.",
                "resume": "Certains parametres vitaux necessitent une attention particuliere. Une surveillance medicale rapprochee est recommandee.",
                "couleur": "orange",
                "emoji": "ORANGE"
            }
        else:
            return {
                "niveau_urgence": "NORMAL",
                "urgence": "AUCUNE",
                "recommandation": "Continuez votre suivi prenatal habituel. Portez MamaGuard demain matin comme d'habitude.",
                "resume": "Tous les parametres vitaux sont dans les limites normales. La grossesse se deroule bien. Continuez le suivi regulier.",
                "couleur": "vert",
                "emoji": "VERT"
            }
