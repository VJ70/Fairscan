import firebase_admin
from firebase_admin import credentials, firestore, storage
from app.core.config import settings
import os

_app = None


def get_firebase_app():
    global _app
    if _app is None:
        if settings.FIREBASE_SERVICE_ACCOUNT and os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT):
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT)
        else:
            # Use Application Default Credentials (works on Cloud Run automatically)
            cred = credentials.ApplicationDefault()
        _app = firebase_admin.initialize_app(cred, {
            "storageBucket": f"{settings.GCP_PROJECT}.appspot.com"
        })
    return _app


def get_firestore():
    get_firebase_app()
    return firestore.client()


def get_storage():
    get_firebase_app()
    return storage.bucket()
