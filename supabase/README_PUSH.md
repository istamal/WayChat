## Push Setup (Supabase + FCM)

### 1) Run SQL
In Supabase SQL Editor run:

1. `supabase/sql/001_push_tokens.sql`
2. `supabase/sql/002_message_push_trigger.sql`

Before running `002_message_push_trigger.sql`, replace:
- `EDGE_FUNCTION_URL` -> `https://<project-ref>.supabase.co/functions/v1/send-message-push`
- `WEBHOOK_SECRET` -> long random secret

### 2) Deploy Edge Function
```bash
supabase functions deploy send-message-push
```

### 3) Set function secrets
```bash
supabase secrets set \
  PUSH_WEBHOOK_SECRET="same_secret_as_in_sql" \
  FCM_PROJECT_ID="your-firebase-project-id" \
  FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

Notes:
- `FIREBASE_SERVICE_ACCOUNT_JSON` must be a full JSON from Firebase service account.
- Keep it one-line JSON string or pass from a file in your CI.

### 4) Verify client writes tokens
Your Flutter app already upserts tokens into `public.push_tokens` via:
- `lib/services/push_notification_service.dart`

### 5) Test flow
1. User A and User B open app and allow notifications.
2. User A sends message to User B.
3. DB trigger posts message payload to Edge Function.
4. Function sends push to all recipient device tokens from `push_tokens`.

### Troubleshooting
- If no push arrives, check:
  - Function logs in Supabase dashboard.
  - Row exists in `push_tokens` for recipient user.
  - `PUSH_WEBHOOK_SECRET` value matches SQL trigger secret.
  - Firebase service account has `Firebase Cloud Messaging API Admin` access.
