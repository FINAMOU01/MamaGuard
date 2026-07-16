def analyze_parameters(bpm, temperature, spo2, tension_s, tension_d, contractions, semaine):
    details = []
    alertes = []
    analyse = []

    if bpm >= 120:
        details.append({
            "parametre": "Frequence cardiaque",
            "valeur": f"{bpm} BPM",
            "statut": "CRITIQUE",
            "message": "Frequence cardiaque tres elevee"
        })
        alertes.append("Tachycardie severe")
        analyse.append(f"Frequence cardiaque de {bpm} BPM superieure au seuil critique de 120 BPM")
    elif bpm >= 100:
        details.append({
            "parametre": "Frequence cardiaque",
            "valeur": f"{bpm} BPM",
            "statut": "ATTENTION",
            "message": "Frequence cardiaque elevee"
        })
        analyse.append(f"Frequence cardiaque de {bpm} BPM superieure au seuil normal de 100 BPM")
    else:
        details.append({
            "parametre": "Frequence cardiaque",
            "valeur": f"{bpm} BPM",
            "statut": "NORMAL",
            "message": "Frequence cardiaque normale"
        })

    if tension_s >= 140 or tension_d >= 90:
        details.append({
            "parametre": "Tension arterielle",
            "valeur": f"{tension_s}/{tension_d} mmHg",
            "statut": "CRITIQUE",
            "message": "Hypertension severe detectee — compatible avec une preeclampsie. Une evaluation medicale est necessaire."
        })
        alertes.append("Hypertension severe")
        analyse.append(f"Tension arterielle de {tension_s}/{tension_d} mmHg superieure au seuil critique de 140/90 mmHg")
    elif tension_s >= 130 or tension_d >= 85:
        details.append({
            "parametre": "Tension arterielle",
            "valeur": f"{tension_s}/{tension_d} mmHg",
            "statut": "ATTENTION",
            "message": "Hypertension moderee detectee"
        })
        analyse.append(f"Tension arterielle de {tension_s}/{tension_d} mmHg superieure au seuil d'alerte de 130/85 mmHg")
    else:
        details.append({
            "parametre": "Tension arterielle",
            "valeur": f"{tension_s}/{tension_d} mmHg",
            "statut": "NORMAL",
            "message": "Tension arterielle normale"
        })

    if temperature >= 38.5:
        details.append({
            "parametre": "Temperature corporelle",
            "valeur": f"{temperature} C",
            "statut": "CRITIQUE",
            "message": "Temperature tres elevee — risque d'infection grave"
        })
        alertes.append("Hyperthermie severe")
        analyse.append(f"Temperature de {temperature}C superieure au seuil critique de 38.5C")
    elif temperature >= 37.6:
        details.append({
            "parametre": "Temperature corporelle",
            "valeur": f"{temperature} C",
            "statut": "ATTENTION",
            "message": "Fievre legere — surveillance recommandee"
        })
        analyse.append(f"Temperature de {temperature}C superieure au seuil normal de 37.6C")
    else:
        details.append({
            "parametre": "Temperature corporelle",
            "valeur": f"{temperature} C",
            "statut": "NORMAL",
            "message": "Temperature normale"
        })

    if spo2 < 92:
        details.append({
            "parametre": "Saturation en oxygene",
            "valeur": f"{spo2}%",
            "statut": "CRITIQUE",
            "message": "Hypoxemie severe — saturation en oxygene anormalement basse"
        })
        alertes.append("Hypoxemie severe")
        analyse.append(f"Saturation en oxygene de {spo2}% inferieure au seuil critique de 92%")
    elif spo2 < 95:
        details.append({
            "parametre": "Saturation en oxygene",
            "valeur": f"{spo2}%",
            "statut": "ATTENTION",
            "message": "Saturation en oxygene basse"
        })
        analyse.append(f"Saturation en oxygene de {spo2}% inferieure au seuil normal de 95%")
    else:
        details.append({
            "parametre": "Saturation en oxygene",
            "valeur": f"{spo2}%",
            "statut": "NORMAL",
            "message": "Saturation en oxygene normale"
        })

    if semaine < 37:
        if contractions >= 4:
            details.append({
                "parametre": "Contractions uterines",
                "valeur": f"{contractions}/10min",
                "statut": "CRITIQUE",
                "message": "Contractions frequentes avant terme — risque d'accouchement premature"
            })
            alertes.append("Contractions prematurees")
            analyse.append(f"{contractions} contractions/10min detectees avant 37 semaines de grossesse")
        elif contractions >= 2:
            details.append({
                "parametre": "Contractions uterines",
                "valeur": f"{contractions}/10min",
                "statut": "ATTENTION",
                "message": "Contractions preoccupantes avant terme"
            })
        else:
            details.append({
                "parametre": "Contractions uterines",
                "valeur": f"{contractions}/10min",
                "statut": "NORMAL",
                "message": "Contractions normales"
            })
    else:
        details.append({
            "parametre": "Contractions uterines",
            "valeur": f"{contractions}/10min",
            "statut": "INFO",
            "message": f"Grossesse a terme ({semaine} semaines)"
        })

    return details, alertes, analyse
