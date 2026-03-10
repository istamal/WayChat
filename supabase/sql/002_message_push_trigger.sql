-- Requires extension pg_net (available in Supabase).
create extension if not exists pg_net;

-- Configure these two values before running:
-- 1) replace EDGE_FUNCTION_URL with your project endpoint:
--    https://<project-ref>.supabase.co/functions/v1/send-message-push
-- 2) replace WEBHOOK_SECRET with a strong random secret.

create or replace function public.enqueue_push_for_new_message()
returns trigger
language plpgsql
security definer
as $$
declare
  edge_function_url text := 'https://rtlgrqbyuwepieykfxpx.supabase.co/functions/v1/send-message-push';
  webhook_secret text := 'MY_SECRET_LONG_HASH_FOR_PUSH_NOTIF_X4LKkjsdfsuupi4323';
begin
  perform net.http_post(
    edge_function_url,
    jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', row_to_json(new)
    ),
    jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_enqueue_push_for_new_message on public.messages;
create trigger trg_enqueue_push_for_new_message
after insert on public.messages
for each row
execute function public.enqueue_push_for_new_message();
