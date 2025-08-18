// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  type: "task_reminder" | "personalized_prompt" | "daily_prompt";
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();

    if (!jwt) {
      return new Response("Unauthorized", { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    const payload: NotificationPayload = await req.json();

    if (!payload.userId || !payload.title || !payload.body || !payload.type) {
      return new Response("Missing required fields", { status: 400 });
    }

    console.log(
      `[SendNotification] Sending ${payload.type} notification to user ${payload.userId}`
    );

    // Store notification in database for tracking
    const { error: dbError } = await supabase
      .from("user_notifications")
      .insert({
        user_id: payload.userId,
        title: payload.title,
        body: payload.body,
        type: payload.type,
        data: payload.data || {},
        sent_at: new Date().toISOString(),
      });

    if (dbError) {
      console.error("[SendNotification] Database error:", dbError);
      return new Response("Failed to store notification", { status: 500 });
    }

    // For now, we'll just log the notification
    // In a real implementation, you would integrate with a push notification service
    // like Firebase Cloud Messaging, OneSignal, or similar
    console.log(`[SendNotification] Notification sent:`, {
      userId: payload.userId,
      title: payload.title,
      body: payload.body,
      type: payload.type,
      data: payload.data,
    });

    return new Response(
      JSON.stringify({
        status: "ok",
        message: "Notification sent successfully",
      }),
      {
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("[SendNotification] Unexpected error:", e);
    return new Response("Internal error", { status: 500 });
  }
});
