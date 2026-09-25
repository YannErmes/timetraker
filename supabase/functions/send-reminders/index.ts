// Supabase Edge Function: send-reminders
// Sends due reminder emails via Resend (free tier). Triggered by the
// GitHub Actions cron in .github/workflows/send-reminders.yml every 15 min.
//
// Deploy once with the Supabase CLI:
//   supabase functions deploy send-reminders
// Secrets (Dashboard > Edge Functions > Secrets, or `supabase secrets set`):
//   CRON_SECRET            random string, also stored as GitHub secret
//   RESEND_API_KEY         from https://resend.com/api-keys (free tier)
//   FROM_EMAIL             verified sender, e.g. reminders@yourdomain.com
//                          (or Resend's onboarding address for testing)
//   SUPABASE_URL           your project URL (auto-provided in production)
//   SUPABASE_SERVICE_ROLE_KEY (auto-provided in production)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "";

serve(async (req: Request) => {
  if (req.headers.get("x-cron-secret") !== CRON_SECRET || CRON_SECRET === "") {
    return new Response("unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: due, error } = await supabase
    .from("reminders")
    .select("id,user_id,email,task_id,entry_date,fire_at,message")
    .eq("status", "pending")
    .lte("fire_at", new Date().toISOString())
    .order("fire_at", { ascending: true })
    .limit(100);

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  // Resolve task names for nicer subjects.
  const taskIds = [...new Set((due ?? []).map((r) => r.task_id))];
  let names: Record<string, string> = {};
  if (taskIds.length > 0) {
    const { data: tasks } = await supabase.from("tasks").select("id,name").in("id", taskIds);
    for (const t of tasks ?? []) names[t.id] = t.name?.trim() ? t.name : "4cus reminder";
  }

  let sent = 0;
  const failed: string[] = [];
  for (const r of due ?? []) {
    const to = (r.email ?? "").trim();
    if (!to.includes("@")) {
      await supabase.from("reminders").update({ status: "failed" }).eq("id", r.id);
      failed.push(r.id);
      continue;
    }
    const taskName = names[r.task_id] ?? "4cus reminder";
    const when = new Date(r.fire_at).toLocaleString();
    const body = (r.message ?? "").trim();
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: FROM_EMAIL,
          to: [to],
          subject: `⏰ ${taskName}`,
          html: `<div style="font-family:sans-serif;max-width:560px">
                   <h2 style="margin:0 0 8px">⏰ ${escapeHtml(taskName)}</h2>
                   <p style="color:#555;margin:0 0 12px">Scheduled for ${escapeHtml(when)}</p>
                   ${body ? `<p style="font-size:16px;line-height:1.6">${escapeHtml(body).replace(/\n/g, "<br>")}</p>` : ""}
                   <hr style="border:none;border-top:1px solid #eee;margin:16px 0">
                   <p style="color:#999;font-size:12px">Sent by 4cus — focus on what matters.</p>
                 </div>`,
        }),
      });
      if (!res.ok) throw new Error(`resend ${res.status}: ${await res.text()}`);
      await supabase.from("reminders").update({ status: "sent" }).eq("id", r.id);
      sent++;
    } catch (e) {
      await supabase.from("reminders").update({ status: "failed" }).eq("id", r.id);
      failed.push(r.id);
    }
  }
  return Response.json({ ok: true, sent, failed: failed.length });
});

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
