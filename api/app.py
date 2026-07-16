from flask import Flask, request, jsonify
import pickle
import pandas as pd
from datetime import datetime

app = Flask(__name__)

# ===================================
# CHARGER LE MODELE ET L'ENCODER
# ===================================
with open('model_mamaguard.pkl', 'rb') as f:
    model = pickle.load(f)

with open('label_encoder.pkl', 'rb') as f:
    le = pickle.load(f)

with open('feature_names.pkl', 'rb') as f:
    feature_names = pickle.load(f)

print("Modele MamaGuard charge ✅")


# ===================================
# FONCTION ANALYSE DETAILLEE
# ===================================
def analyser_parametres(bpm, temperature, spo2,
                         tension_s, tension_d,
                         contractions, semaine):
    details  = []
    alertes  = []
    analyse  = []

    # BPM
    if bpm >= 120:
        details.append({
            "parametre" : "Frequence cardiaque",
            "valeur"    : f"{bpm} BPM",
            "statut"    : "CRITIQUE",
            "message"   : "Frequence cardiaque tres elevee"
        })
        alertes.append("Tachycardie severe")
        analyse.append(
            f"Frequence cardiaque de {bpm} BPM "
            f"superieure au seuil critique de 120 BPM"
        )
    elif bpm >= 100:
        details.append({
            "parametre" : "Frequence cardiaque",
            "valeur"    : f"{bpm} BPM",
            "statut"    : "ATTENTION",
            "message"   : "Frequence cardiaque elevee"
        })
        analyse.append(
            f"Frequence cardiaque de {bpm} BPM "
            f"superieure au seuil normal de 100 BPM"
        )
    else:
        details.append({
            "parametre" : "Frequence cardiaque",
            "valeur"    : f"{bpm} BPM",
            "statut"    : "NORMAL",
            "message"   : "Frequence cardiaque normale"
        })

    # TENSION — correction vocabulaire médical
    if tension_s >= 140 or tension_d >= 90:
        details.append({
            "parametre" : "Tension arterielle",
            "valeur"    : f"{tension_s}/{tension_d} mmHg",
            "statut"    : "CRITIQUE",
            "message"   : (
                "Hypertension severe detectee — "
                "compatible avec une preeclampsie. "
                "Une evaluation medicale est necessaire."
            )
        })
        alertes.append("Hypertension severe")
        analyse.append(
            f"Tension arterielle de {tension_s}/{tension_d} mmHg "
            f"superieure au seuil critique de 140/90 mmHg"
        )
    elif tension_s >= 130 or tension_d >= 85:
        details.append({
            "parametre" : "Tension arterielle",
            "valeur"    : f"{tension_s}/{tension_d} mmHg",
            "statut"    : "ATTENTION",
            "message"   : "Hypertension moderee detectee"
        })
        analyse.append(
            f"Tension arterielle de {tension_s}/{tension_d} mmHg "
            f"superieure au seuil d'alerte de 130/85 mmHg"
        )
    else:
        details.append({
            "parametre" : "Tension arterielle",
            "valeur"    : f"{tension_s}/{tension_d} mmHg",
            "statut"    : "NORMAL",
            "message"   : "Tension arterielle normale"
        })

    # TEMPERATURE
    if temperature >= 38.5:
        details.append({
            "parametre" : "Temperature corporelle",
            "valeur"    : f"{temperature} C",
            "statut"    : "CRITIQUE",
            "message"   : (
                "Temperature tres elevee — "
                "risque d'infection grave"
            )
        })
        alertes.append("Hyperthermie severe")
        analyse.append(
            f"Temperature de {temperature}C "
            f"superieure au seuil critique de 38.5C"
        )
    elif temperature >= 37.6:
        details.append({
            "parametre" : "Temperature corporelle",
            "valeur"    : f"{temperature} C",
            "statut"    : "ATTENTION",
            "message"   : "Fievre legere — surveillance recommandee"
        })
        analyse.append(
            f"Temperature de {temperature}C "
            f"superieure au seuil normal de 37.6C"
        )
    else:
        details.append({
            "parametre" : "Temperature corporelle",
            "valeur"    : f"{temperature} C",
            "statut"    : "NORMAL",
            "message"   : "Temperature normale"
        })

    # SPO2 — correction vocabulaire médical
    if spo2 < 92:
        details.append({
            "parametre" : "Saturation en oxygene",
            "valeur"    : f"{spo2}%",
            "statut"    : "CRITIQUE",
            "message"   : (
                "Hypoxemie severe — "
                "saturation en oxygene anormalement basse"
            )
        })
        alertes.append("Hypoxemie severe")
        analyse.append(
            f"Saturation en oxygene de {spo2}% "
            f"inferieure au seuil critique de 92%"
        )
    elif spo2 < 95:
        details.append({
            "parametre" : "Saturation en oxygene",
            "valeur"    : f"{spo2}%",
            "statut"    : "ATTENTION",
            "message"   : "Saturation en oxygene basse"
        })
        analyse.append(
            f"Saturation en oxygene de {spo2}% "
            f"inferieure au seuil normal de 95%"
        )
    else:
        details.append({
            "parametre" : "Saturation en oxygene",
            "valeur"    : f"{spo2}%",
            "statut"    : "NORMAL",
            "message"   : "Saturation en oxygene normale"
        })

    # CONTRACTIONS
    if semaine < 37:
        if contractions >= 4:
            details.append({
                "parametre" : "Contractions uterines",
                "valeur"    : f"{contractions}/10min",
                "statut"    : "CRITIQUE",
                "message"   : (
                    "Contractions frequentes avant terme — "
                    "risque d'accouchement premature"
                )
            })
            alertes.append("Contractions prematurees")
            analyse.append(
                f"{contractions} contractions/10min "
                f"detectees avant 37 semaines de grossesse"
            )
        elif contractions >= 2:
            details.append({
                "parametre" : "Contractions uterines",
                "valeur"    : f"{contractions}/10min",
                "statut"    : "ATTENTION",
                "message"   : "Contractions preoccupantes avant terme"
            })
        else:
            details.append({
                "parametre" : "Contractions uterines",
                "valeur"    : f"{contractions}/10min",
                "statut"    : "NORMAL",
                "message"   : "Contractions normales"
            })
    else:
        details.append({
            "parametre" : "Contractions uterines",
            "valeur"    : f"{contractions}/10min",
            "statut"    : "INFO",
            "message"   : f"Grossesse a terme ({semaine} semaines)"
        })

    return details, alertes, analyse


# ===================================
# ROUTE PRINCIPALE — PREDICTION
# ===================================
@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()

        bpm          = data['bpm']
        temperature  = data['temperature']
        spo2         = data['spo2']
        tension_s    = data['tension_systolique']
        tension_d    = data['tension_diastolique']
        contractions = data['contractions_par_10min']
        semaine      = data['semaine_grossesse']

        # Feature Engineering
        pulse_pressure = tension_s - tension_d
        indice_tension = round(tension_s / tension_d, 2)
        fievre         = 1 if temperature >= 37.6 else 0
        spo2_basse     = 1 if spo2 < 95 else 0
        trimestre      = (1 if semaine <= 12 else
                         2 if semaine <= 26 else 3)

        input_data = pd.DataFrame([{
            'bpm'                    : bpm,
            'temperature'            : temperature,
            'spo2'                   : spo2,
            'tension_systolique'     : tension_s,
            'tension_diastolique'    : tension_d,
            'contractions_par_10min' : contractions,
            'semaine_grossesse'      : semaine,
            'pulse_pressure'         : pulse_pressure,
            'indice_tension'         : indice_tension,
            'fievre'                 : fievre,
            'spo2_basse'             : spo2_basse,
            'trimestre'              : trimestre
        }])

        # Prediction
        prediction   = model.predict(input_data)
        score_risque = le.inverse_transform(prediction)[0]

        # Probabilités
        probabilities = model.predict_proba(input_data)[0]
        classes       = le.classes_
        proba_dict    = {
            classes[i]: round(float(probabilities[i]) * 100, 1)
            for i in range(len(classes))
        }
        confiance = round(max(probabilities) * 100, 1)

        # Analyse détaillée
        details, alertes, analyse = analyser_parametres(
            bpm, temperature, spo2,
            tension_s, tension_d,
            contractions, semaine
        )

        # Niveau urgence et recommandation corrigés
        if score_risque == 'Eleve':
            niveau_urgence = "CRITIQUE"
            urgence        = "IMMEDIATE"
            recommandation = (
                "Consultez immediatement un professionnel "
                "de sante ou rendez-vous dans le centre "
                "de sante le plus proche."
            )
            resume = (
                "Plusieurs parametres vitaux sont hors des "
                "seuils cliniques recommandes. Une consultation "
                "medicale urgente est fortement conseillee."
            )
            couleur = "rouge"
            emoji   = "ROUGE"

        elif score_risque == 'Modere':
            niveau_urgence = "SURVEILLANCE"
            urgence        = "RAPPROCHEE"
            recommandation = (
                "Contactez votre sage-femme ou votre medecin "
                "dans les 24 heures."
            )
            resume = (
                "Certains parametres vitaux necessitent "
                "une attention particuliere. Une surveillance "
                "medicale rapprochee est recommandee."
            )
            couleur = "orange"
            emoji   = "ORANGE"

        else:
            niveau_urgence = "NORMAL"
            urgence        = "AUCUNE"
            recommandation = (
                "Continuez votre suivi prenatal habituel. "
                "Portez MamaGuard demain matin comme d'habitude."
            )
            resume = (
                "Tous les parametres vitaux sont dans les "
                "limites normales. La grossesse se deroule "
                "bien. Continuez le suivi regulier."
            )
            couleur = "vert"
            emoji   = "VERT"

        # Horodatage
        maintenant = datetime.now()

        return jsonify({
            "succes"          : True,
            "timestamp"       : maintenant.strftime(
                                "%Y-%m-%dT%H:%M:%S"),
            "date"            : maintenant.strftime("%Y-%m-%d"),
            "heure"           : maintenant.strftime("%H:%M"),
            "score"           : score_risque,
            "confiance"       : f"{confiance}%",
            "niveau_urgence"  : niveau_urgence,
            "urgence"         : urgence,
            "couleur"         : couleur,
            "emoji"           : emoji,
            "resume"          : resume,
            "analyse"         : analyse,
            "details"         : details,
            "alertes"         : alertes,
            "recommandation"  : recommandation,
            "probabilites"    : proba_dict,
            "parametres_recus": {
                "bpm"          : bpm,
                "temperature"  : temperature,
                "spo2"         : spo2,
                "tension"      : f"{tension_s}/{tension_d} mmHg",
                "contractions" : f"{contractions}/10min",
                "semaine"      : semaine
            }
        })

    except Exception as e:
        return jsonify({
            "succes" : False,
            "erreur" : str(e)
        }), 400


# ===================================
# ROUTE TEST
# ===================================
@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "message" : "API MamaGuard operationnelle",
        "version" : "2.0",
        "routes"  : {
            "GET  /"        : "Verifier que l'API fonctionne",
            "POST /predict" : "Prediction du risque prenatal"
        }
    })


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)