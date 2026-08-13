"""
Simulateur ESP32 MamaGuard.

Genere des valeurs realistes (BPM, SpO2, temperature, contractions, tension)
et les envoie a l'API Flask toutes les 5 secondes, comme le ferait la ceinture
de capteurs reelle. Il utilise le token FCM de la patiente (lu depuis Firestore)
pour que les notifications arrivent reellement sur son telephone.

Usage:
    python simulate_esp32.py
    python simulate_esp32.py --url http://10.11.12.160:5000
    python simulate_esp32.py --phone +237653844244
    python simulate_esp32.py --interval 5

Ctrl+C pour arreter.
"""

import argparse
import json
import os
import random
import sys
import time
import uuid

import requests
from google.cloud import firestore

# ---- Parametres de la patiente simulee ----
PATIENT_ID = "patient_esp32_sim"
PATIENT_NAME = "Marie Noëlle"
PHONE = "+237653844244"
EMERGENCY_CONTACTS = [{"phone": "+237600000000", "relation": "Mari"}]
DOCTOR_PHONE = "+237699300300"  # Dr Nadege
SEM_GROSSESSE = 6

# ---- Seuils pour simuler des episodes de risque ----
# Chaque valeur est (base, ecart_type, min, max)
BPM = (75.0, 5.0, 55.0, 130.0)
SPO2 = (98.0, 1.0, 88.0, 100.0)
TEMP = (37.0, 0.2, 35.5, 39.0)
CTX = (2.0, 1.0, 0.0, 12.0)
TENS_S = (118.0, 6.0, 90.0, 170.0)
TENS_D = (78.0, 4.0, 60.0, 110.0)


def read_patient_token(service_account_path):
    """Lit le fcm_token de la patiente depuis Firestore."""
    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or service_account_path
    if cred_path and os.path.exists(cred_path):
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = cred_path
    db = firestore.Client(project="mamaguard-1f712")
    doc = db.collection("users").document(PHONE).get()
    if doc.exists:
        return (doc.to_dict() or {}).get("fcm_token")
    return None


def random_vitals(risk_episode=False):
    """Genere des valeurs vitales realistes. En mode risque, pousse les valeurs hors seuils."""
    if risk_episode:
        bpm = random.uniform(105, 135)
        spo2 = random.uniform(88, 92)
        temp = random.uniform(38.0, 39.2)
        ctx = random.uniform(5, 8)
        tens_s = random.uniform(140, 175)
        tens_d = random.uniform(90, 110)
    else:
        bpm = random.gauss(BPM[0], BPM[1])
        spo2 = random.gauss(SPO2[0], SPO2[1])
        temp = random.gauss(TEMP[0], TEMP[1])
        ctx = random.gauss(CTX[0], CTX[1])
        tens_s = random.gauss(TENS_S[0], TENS_S[1])
        tens_d = random.gauss(TENS_D[0], TENS_D[1])

    def clamp(v, lo, hi):
        return max(lo, min(hi, v))

    return {
        "bpm": round(clamp(bpm, BPM[2], BPM[3]), 1),
        "spo2": round(clamp(spo2, SPO2[2], SPO2[3]), 1),
        "temperature": round(clamp(temp, TEMP[2], TEMP[3]), 1),
        "contractions_par_10min": round(clamp(ctx, CTX[2], CTX[3]), 1),
        "tension_systolique": round(clamp(tens_s, TENS_S[2], TENS_S[3]), 1),
        "tension_diastolique": round(clamp(tens_d, TENS_D[2], TENS_D[3]), 1),
        "semaine_grossesse": SEM_GROSSESSE,
    }


def build_payload(vitals, fcm_token):
    return {
        "patient_id": PATIENT_ID,
        "patient_name": PATIENT_NAME,
        "phone": PHONE,
        "emergency_contacts": EMERGENCY_CONTACTS,
        "doctor_phone": DOCTOR_PHONE,
        "fcm_token": fcm_token,
        "vitals": vitals,
    }


def main():
    global PHONE
    parser = argparse.ArgumentParser(description="Simulateur ESP32 MamaGuard")
    parser.add_argument("--url", default="http://10.11.12.160:5000",
                        help="URL de l'API Flask")
    parser.add_argument("--phone", default=PHONE)
    parser.add_argument("--interval", type=int, default=5,
                        help="Intervalle entre deux envois (secondes)")
    parser.add_argument("--risk-every", type=int, default=30,
                        help="Toutes les N mesures, simule un episode a risque (0 = jamais)")
    parser.add_argument("--fcm-token", default=None,
                        help="Token FCM (sinon lu automatiquement depuis Firestore)")
    args = parser.parse_args()

    PHONE = args.phone

    token = args.fcm_token
    if not token:
        token = read_patient_token("C:/Users/finamou/Desktop/MamaGuard/credentials/firebase-service-account.json")

    if token:
        print(f"[OK] Token FCM recupere (longueur {len(token)})")
    else:
        print("[!] Aucun token FCM — les notifications n'arriveront pas, mais /predict et /alert marchent quand meme.")

    live_url = args.url.rstrip("/") + "/patient/vitals/live"
    alert_url = args.url.rstrip("/") + "/alert"
    print(f"[*] Vitals live  -> {live_url} toutes les {args.interval}s pour {PHONE}")
    print(f"[*] Alerte       -> {alert_url} en cas d'episode a risque")
    print("[*] Ctrl+C pour arreter.\n")

    counter = 0
    try:
        while True:
            counter += 1
            risk_episode = args.risk_every > 0 and counter % args.risk_every == 0
            vitals = random_vitals(risk_episode=risk_episode)
            label = "RISQUE" if risk_episode else "normal"

            # 1) Envoi temps reel pour l'affichage Flutter + score IA
            try:
                r = requests.post(live_url, json={"phone": PHONE, "vitals": vitals}, timeout=10)
                try:
                    resp = r.json()
                except Exception:
                    resp = {}
                print(f"[{counter:>4}] {label:>6} | bpm={vitals['bpm']:>6} "
                      f"spo2={vitals['spo2']:>5} temp={vitals['temperature']:>4} "
                      f"TA={vitals['tension_systolique']:>5}/{vitals['tension_diastolique']:<5} "
                      f"ctx={vitals['contractions_par_10min']:>4} | HTTP {r.status_code} | score={resp.get('score', '?')}")
            except requests.RequestException as e:
                print(f"[{counter:>4}] ERREUR reseau (vitals) : {e}")

            # 2) Envoi alerte uniquement en cas de risque (declenche FCM, pas de SMS)
            if risk_episode:
                try:
                    r = requests.post(alert_url, json=build_payload(vitals, token), timeout=10)
                    print(f"[{counter:>4}] ALERTE envoyee -> HTTP {r.status_code}")
                except requests.RequestException as e:
                    print(f"[{counter:>4}] ERREUR reseau (alerte) : {e}")

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[*] Simulateur arrete.")


if __name__ == "__main__":
    main()
