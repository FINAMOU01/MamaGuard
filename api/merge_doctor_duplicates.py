"""
Migration: merge duplicate doctor documents by phone.
Keeps the document with 'name' field, merges data from the phone-ID document, then deletes the phone-ID document.
Run: docker compose run --rm -w /app api python merge_doctor_duplicates.py
"""
import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import Config

def main():
    cred_data = Config.get_firebase_credentials()
    if not cred_data:
        print("ERROR: No Firebase credentials found")
        sys.exit(1)
    cred = credentials.Certificate(cred_data)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    phones = {}
    docs = db.collection("doctors").stream()
    for doc in docs:
        d = doc.to_dict()
        phone = d.get("phone")
        if phone:
            if phone not in phones:
                phones[phone] = []
            phones[phone].append({"id": doc.id, "data": d})

    merged_count = 0
    deleted_count = 0

    for phone, entries in phones.items():
        if len(entries) <= 1:
            continue

        print(f"\nPhone {phone}: {len(entries)} documents found")
        main_doc = None
        extra_docs = []

        for e in entries:
            if e["data"].get("name") or e["data"].get("specialty") or e["data"].get("hospital"):
                main_doc = e
            else:
                extra_docs.append(e)

        if not main_doc:
            main_doc = entries[0]
            extra_docs = [e for e in entries if e["id"] != main_doc["id"]]

        for extra in extra_docs:
            print(f"  Merging {extra['id']} into {main_doc['id']}...")
            merged_data = {}
            for k, v in extra["data"].items():
                if k not in main_doc["data"] or not main_doc["data"].get(k):
                    merged_data[k] = v
            if merged_data:
                db.collection("doctors").document(main_doc["id"]).set(merged_data, merge=True)
                print(f"    Merged keys: {list(merged_data.keys())}")
            db.collection("doctors").document(extra["id"]).delete()
            print(f"    Deleted {extra['id']}")
            deleted_count += 1
            merged_count += 1

    print(f"\nDone. Merged {merged_count} duplicates, deleted {deleted_count} extra docs.")
    print("Remaining doctors:")
    docs = db.collection("doctors").stream()
    for doc in docs:
        d = doc.to_dict()
        print(f"  {doc.id}: phone={d.get('phone')}, name={d.get('name')}, status={d.get('status')}, pin_hash={'yes' if d.get('pin_hash') else 'no'}")

if __name__ == "__main__":
    main()