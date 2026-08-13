"""Script to create the first admin user in Firestore.
Run: python scripts/create_first_admin.py
"""
import sys
import hashlib
sys.path.insert(0, "api")

from firebase_admin import firestore
from services.firebase_service import get_db

db = get_db()
if not db:
    print("Firebase n'est pas configure. Verifie FIREBASE_SERVICE_ACCOUNT.")
    sys.exit(1)

existing = list(db.collection("admins").limit(1).stream())
if existing:
    print("Des administrateurs existent deja dans la base :")
    for doc in existing:
        d = doc.to_dict()
        actif = "actif" if d.get("actif") else "revoque"
        print(f"  - {d.get('email')} ({d.get('name')}) - {actif}")
    sys.exit(0)

email = "admin@mamaguard.com"
password = "admin123"
name = "Super Admin"
phone = "+237600000000"

pw_hash = hashlib.sha256(password.encode()).hexdigest()

db.collection("admins").document().set({
    "name": name,
    "email": email,
    "phone": phone,
    "password_hash": pw_hash,
    "actif": True,
    "created_at": firestore.SERVER_TIMESTAMP,
    "created_by": "system",
})

print("Premier admin cree avec succes !")
print(f"  Email       : {email}")
print(f"  Mot de passe: {password}")
print("Connecte-toi sur http://localhost:5000/admin/login")
