import logging

from django.conf import settings

logger = logging.getLogger(__name__)


def firebase_status():
    if not settings.FIREBASE_ENABLED:
        return {
            "enabled": False,
            "configured": False,
            "project_id": settings.FIREBASE_PROJECT_ID,
            "message": "Set FIREBASE_ENABLED=true and FIREBASE_CREDENTIALS to enable Firebase Admin.",
        }

    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        return {
            "enabled": True,
            "configured": False,
            "project_id": settings.FIREBASE_PROJECT_ID,
            "message": "firebase-admin is not installed.",
        }

    try:
        if not firebase_admin._apps:
            if settings.FIREBASE_CREDENTIALS:
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
                firebase_admin.initialize_app(cred, {
                    "projectId": settings.FIREBASE_PROJECT_ID,
                })
            else:
                firebase_admin.initialize_app(options={
                    "projectId": settings.FIREBASE_PROJECT_ID,
                })
        return {
            "enabled": True,
            "configured": True,
            "project_id": settings.FIREBASE_PROJECT_ID,
            "message": "Firebase Admin initialized.",
        }
    except Exception as exc:
        logger.exception("Firebase Admin initialization failed")
        return {
            "enabled": True,
            "configured": False,
            "project_id": settings.FIREBASE_PROJECT_ID,
            "message": str(exc),
        }
