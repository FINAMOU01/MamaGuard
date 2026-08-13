import random
from services.firebase_service import get_db

db = get_db()
if not db:
    print("Firebase non disponible")
    exit(1)

def gen_code():
    return str(random.randint(100000, 999999))

docs = db.collection("doctors").where("status", "==", "valide").stream()
for doc in docs:
    d = doc.to_dict()
    updates = {}
    if not d.get("activation_code"):
        updates["activation_code"] = d.get("liaison_code", gen_code())
    if not d.get("liaison_code") or d.get("liaison_code") == updates.get("activation_code", d.get("liaison_code")):
        new_code = gen_code()
        while new_code == updates.get("activation_code", d.get("liaison_code")):
            new_code = gen_code()
        updates["liaison_code"] = new_code

    if updates:
        db.collection("doctors").document(doc.id).update(updates)
        name = d.get("name", "?")
        ac = updates.get("activation_code", d.get("liaison_code"))
        lc = updates.get("liaison_code", d.get("liaison_code"))
        print(f"{name}: activation={ac} liaison={lc}")

print("Migration terminee")