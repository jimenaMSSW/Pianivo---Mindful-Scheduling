# Pianivo

Appointment management system with a SwiftUI app and Django backend.

## Deployment Setup

1. Install backend dependencies:

```bash
pip install -r requirements.txt
```

2. Copy `.env.example` into your deployment provider's environment variables.

3. Configure Firebase:

- Keep `Resources/GoogleService-Info.plist` in the Swift app for client Firebase initialization.
- Create a Firebase service account JSON in Firebase Console.
- Store that JSON outside the repo and set `FIREBASE_CREDENTIALS` to its server path.
- Check `/firebase/health/` after deployment.

4. Configure Stripe payments:

- Set `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, and `STRIPE_WEBHOOK_SECRET`.
- In the Stripe Dashboard, enable `Card` and `Klarna` payment methods.
- Add a webhook endpoint pointing to `/payments/stripe/webhook/`.
- Send at least `payment_intent.succeeded`, `payment_intent.payment_failed`, `payment_intent.processing`, and `payment_intent.canceled`.

5. Prepare the database:

```bash
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py check --deploy
```

For production, use `DATABASE_URL` with a managed PostgreSQL database. Local development falls back to `db.sqlite3` when `DATABASE_URL` is not set.
