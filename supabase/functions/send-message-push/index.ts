// Supabase Edge Function: send-message-push
// Receives NEW message payload (via DB trigger/webhook) and sends FCM push
// to all room participants except sender.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

type MessageRecord = {
  id: string;
  room_id: string;
  user_id: string;
  content: string | null;
};

type WebhookPayload = {
  type?: string;
  table?: string;
  record?: MessageRecord;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PUSH_WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const FIREBASE_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

async function getGoogleAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON) as {
    client_email: string;
    private_key: string;
    token_uri?: string;
  };

  const now = Math.floor(Date.now() / 1000);
  const jwtHeaderAlg = "RS256";
  const scope = "https://www.googleapis.com/auth/firebase.messaging";

  const privateKey = await importPKCS8(serviceAccount.private_key, jwtHeaderAlg);
  const assertion = await new SignJWT({ scope })
    .setProtectedHeader({ alg: jwtHeaderAlg, typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience(serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Failed to get Google access token: ${resp.status} ${text}`);
  }

  const data = (await resp.json()) as { access_token: string };
  return data.access_token;
}

async function sendFcmMessage(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: "high" },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      }),
    },
  );

  if (resp.ok) return { ok: true as const };

  const errText = await resp.text();
  const unregistered =
    errText.includes("UNREGISTERED") || errText.includes("registration-token-not-registered");

  return { ok: false as const, unregistered, error: errText };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, { status: 405 });
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: "Missing Supabase env vars" }, { status: 500 });
    }
    if (!FIREBASE_SERVICE_ACCOUNT_JSON || !FCM_PROJECT_ID) {
      return json({ error: "Missing Firebase env vars" }, { status: 500 });
    }

    const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
    if (!PUSH_WEBHOOK_SECRET || incomingSecret !== PUSH_WEBHOOK_SECRET) {
      return json({ error: "Unauthorized" }, { status: 401 });
    }

    const payload = (await req.json()) as WebhookPayload;
    const message = payload.record;
    if (!message?.id || !message.room_id || !message.user_id) {
      return json({ error: "Invalid payload" }, { status: 400 });
    }

    const [participantsRes, senderRes] = await Promise.all([
      supabase
        .from("chat_room_participants")
        .select("user_id")
        .eq("room_id", message.room_id)
        .neq("user_id", message.user_id),
      supabase
        .from("profiles")
        .select("full_name, username")
        .eq("id", message.user_id)
        .maybeSingle(),
    ]);

    if (participantsRes.error) throw participantsRes.error;
    if (senderRes.error) throw senderRes.error;

    const recipientIds = (participantsRes.data ?? [])
      .map((r) => r.user_id as string)
      .filter(Boolean);
    if (recipientIds.length === 0) {
      return json({ ok: true, sent: 0, skipped: "no recipients" });
    }

    const { data: tokensData, error: tokensError } = await supabase
      .from("push_tokens")
      .select("id, token, user_id")
      .in("user_id", recipientIds);
    if (tokensError) throw tokensError;

    const tokens = (tokensData ?? [])
      .map((t) => ({ id: t.id as number, token: t.token as string }))
      .filter((t) => t.token && t.token.length > 0);
    if (tokens.length == 0) {
      return json({ ok: true, sent: 0, skipped: "no tokens" });
    }

    const senderName =
      senderRes.data?.full_name?.toString().trim() ||
      senderRes.data?.username?.toString().trim() ||
      "Новое сообщение";
    const body = (message.content ?? "").trim().isEmpty
      ? "Отправил(а) вложение"
      : message.content!.trim().slice(0, 120);

    const accessToken = await getGoogleAccessToken();

    let sent = 0;
    const invalidTokenIds: number[] = [];
    for (const t of tokens) {
      const result = await sendFcmMessage(accessToken, t.token, senderName, body, {
        room_id: message.room_id,
        message_id: message.id,
        sender_id: message.user_id,
      });
      if (result.ok) {
        sent += 1;
      } else if (result.unregistered) {
        invalidTokenIds.push(t.id);
      }
    }

    if (invalidTokenIds.length > 0) {
      await supabase.from("push_tokens").delete().in("id", invalidTokenIds);
    }

    return json({ ok: true, sent, invalid_tokens_removed: invalidTokenIds.length });
  } catch (error) {
    return json(
      { ok: false, error: error instanceof Error ? error.message : String(error) },
      { status: 500 },
    );
  }
});
