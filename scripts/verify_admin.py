"""Verify admin credentials directly from Firestore."""
import sys
import hashlib
sys.path.insert(0, "api")

from services.firebase_service import get_db

db = get_db()
if not db:
    print("Firebase non disponible")
    sys.exit(1)

docs = list(db.collection("admins").where("email", "==", "admin@mamaguard.com").limit(1).stream())
if not docs:
    print("Admin introuvable dans Firestore. Relance le script de creation.")
    sys.exit(1)

d = docs[0].to_dict()
stored_hash = d.get("password_hash")
input_pw = "admin123"
input_hash = hashlib.sha256(input_pw.encode()).hexdigest()

print("Admin trouve dans Firestore:")
print(f"  Email: {d.get('email')}")
print(f"  Nom: {d.get('name')}")
print(f"  Actif: {d.get('actif')}")
print(f"  Hash stocke: {stored_hash}")
print(f"  Hash calcule: {input_hash}")
print(f"  Correspondent: {stored_hash == input_hash}")
print()
if stored_hash == input_hash:
    print("OK - Identifiants corrects !")
    print()
    print("Pour te connecter :")
    print("  1. Lance le serveur : python api/app.py")
    print("  2. Ouvre http://localhost:5000/admin/login")
    print("  3. Email    : admin@mamaguard.com")
    print("  4. Mot passe: admin123")
else:
    print("ERREUR - Les mots de passe ne correspondent pas.")
    print("Relance : python scripts/create_first_admin.py")
