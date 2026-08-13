"""
Seed des patientes simulées pour tester le dashboard médecin.

Crée 3 patientes liées à Dr Nadege avec des niveaux de risque différents :
  - Aïcha : risque Eleve  (couleur rouge -> critique)
  - Fatou : risque Modere (couleur orange -> surveillance)
  - Sarah : risque Normal (couleur vert   -> normal)

Usage:
    python scripts\seed_patients.py
    python scripts\seed_patients.py --doctor-phone +237699300300
    python scripts\seed_patients.py --clean   # supprime les patientes simulées
"""

import argparse
import sys
import os
from datetime import datetime

from google.cloud import firestore

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "api"))

DOCTOR_PHONE = "+237699300300"  # Dr Nadege

PATIENTS = [
    {
        "phone": "+237600000001",
        "name": "Aïcha Njoya",
        "week": 30,
        "bpm": 122, "spo2": 89, "temperature": 38.8,
        "tension_s": 158, "tension_d": 98, "contractions": 5,
        "score": "Eleve", "couleur": "rouge",
    },
    {
        "phone": "+237600000002",
        "name": "Fatou Mbarga",
        "week": 24,
        "bpm": 108, "spo2": 93, "temperature": 37.9,
        "tension_s": 142, "tension_d": 92, "contractions": 3,
        "score": "Modere", "couleur": "orange",
    },
    {
        "phone": "+237600000003",
        "name": "Sarah Bello",
        "week": 20,
        "bpm": 74, "spo2": 98, "temperature": 36.8,
        "tension_s": 118, "tension_d": 78, "contractions": 1,
        "score": "Normale", "couleur": "vert",
    },
]


def find_doctor(db, phone):
    docs = list(db.collection("doctors").where("phone", "==", phone).limit(1).stream())
    if not docs:
        return None
    return docs[0]


def seed(db, doctor_phone):
    doctor = find_doctor(db, doctor_phone)
    if not doctor:
        print(f"ERREUR: médecin {doctor_phone} introuvable")
        sys.exit(1)
    doctor_data = doctor.to_dict()
    print(f"Medecin: {doctor_data.get('name')} ({doctor.id})")

    now = datetime.utcnow()

    for p in PATIENTS:
        phone = p["phone"]
        user_ref = db.collection("users").document(phone)
        user_ref.set({
            "name": p["name"],
            "phone": phone,
            "role": "patient",
            "doctor_phone": doctor_phone,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "hospital": doctor_data.get("hospital", ""),
        }, merge=True)

        # Lien patiente -> médecin
        links = list(db.collection("patient_links")
                     .where("patient_phone", "==", phone)
                     .limit(1).stream())
        if links:
            links[0].reference.update({
                "doctor_id": doctor.id,
                "doctor_phone": doctor_phone,
                "doctor_name": doctor_data.get("name", "Médecin"),
            })
        else:
            db.collection("patient_links").document().set({
                "patient_phone": phone,
                "doctor_id": doctor.id,
                "doctor_name": doctor_data.get("name", "Médecin"),
                "doctor_phone": doctor_phone,
                "doctor_specialty": doctor_data.get("specialty", "Gynécologue"),
                "liaison_code": doctor_data.get("liaison_code", ""),
                "created_at": firestore.SERVER_TIMESTAMP,
            })

        # Mesure legacy (affichée dans le dashboard)
        m_ref = user_ref.collection("measures").document()
        m_ref.set({
            "date": now.strftime("%Y-%m-%d"),
            "heure": now.strftime("%H:%M"),
            "bpm": p["bpm"],
            "spo2": p["spo2"],
            "temperature": p["temperature"],
            "tension_s": p["tension_s"],
            "tension_d": p["tension_d"],
            "contractions": p["contractions"],
            "semaine": p["week"],
            "score": p["score"],
            "couleur": p["couleur"],
            "timestamp": firestore.SERVER_TIMESTAMP,
        })

        print(f"[OK] {p['name']} ({phone}) -> risque {p['score']} / {p['couleur']}")


def clean(db):
    phones = [p["phone"] for p in PATIENTS]
    for phone in phones:
        user_ref = db.collection("users").document(phone)
        if user_ref.get().exists:
            for m in user_ref.collection("measures").stream():
                m.reference.delete()
            user_ref.delete()
        links = list(db.collection("patient_links").where("patient_phone", "==", phone).stream())
        for link in links:
            link.reference.delete()
        print(f"[CLEAN] patiente {phone} supprimée")


def main():
    parser = argparse.ArgumentParser(description="Seed patientes simulées")
    parser.add_argument("--doctor-phone", default=DOCTOR_PHONE, help="Téléphone du médecin")
    parser.add_argument("--clean", action="store_true", help="Supprime les patientes simulées")
    args = parser.parse_args()

    db = firestore.Client(project="mamaguard-1f712")
    if args.clean:
        clean(db)
    else:
        seed(db, args.doctor_phone)


if __name__ == "__main__":
    main()
