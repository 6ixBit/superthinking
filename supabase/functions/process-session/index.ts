// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

type Analysis = {
  summary_before: string;
  summary_after: string;
  problem_focus_percentage: number;
  solution_focus_percentage: number;
  shift_percentage: number;
  thinking_style_today: string;
  thinking_patterns: Record<string, number>;
  best_ideas: string[];
  strength_highlight: string;
  positive_quotes: string[];
  resources_mentioned: string[];
  session_duration_minutes: number;
  actions: Array<{
    description: string;
    category?: string;
    priority?: "low" | "medium" | "high";
    source: "user_stated" | "ai_suggested";
  }>;
};

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) return new Response("Unauthorized", { status: 401 });

    const { sessionId } = await req.json();
    if (!sessionId) return new Response("Missing sessionId", { status: 400 });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    // Fetch session (RLS enforced by user JWT)
    const { data: sessionRow, error: sessErr } = await supabase
      .from("sessions")
      .select("id, user_id, audio_url, duration_seconds, processing_status")
      .eq("id", sessionId)
      .maybeSingle();

    if (sessErr || !sessionRow) {
      return new Response("Session not found", { status: 404 });
    }

    const audioUrl: string | null = sessionRow.audio_url;
    if (!audioUrl)
      return new Response("No audio_url on session", { status: 400 });

    const audioResp = await fetch(audioUrl);
    if (!audioResp.ok)
      return new Response("Failed to fetch audio", { status: 502 });
    const audioBlob = await audioResp.blob();

    // Whisper transcription (gpt-4o-transcribe)
    const form = new FormData();
    form.append(
      "file",
      new File([audioBlob], "audio.m4a", { type: "audio/m4a" })
    );
    form.append("model", "gpt-4o-transcribe");

    const transcribeResp = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
        body: form,
      }
    );
    if (!transcribeResp.ok) {
      const tErr = await transcribeResp.text();
      console.error("Transcribe error:", tErr);
      await markFailed(supabase, sessionId);
      return new Response("Transcription failed", { status: 502 });
    }
    const transcribed = await transcribeResp.json();
    const transcript: string = transcribed.text ?? "";

    // GPT-5 Responses analysis with JSON schema
    const schema = {
      name: "SessionAnalysis",
      schema: {
        type: "object",
        properties: {
          summary_before: { type: "string" },
          summary_after: { type: "string" },
          problem_focus_percentage: { type: "number" },
          solution_focus_percentage: { type: "number" },
          shift_percentage: { type: "number" },
          thinking_style_today: { type: "string" },
          thinking_patterns: {
            type: "object",
            additionalProperties: { type: "number" },
          },
          best_ideas: { type: "array", items: { type: "string" }, maxItems: 5 },
          strength_highlight: { type: "string" },
          positive_quotes: {
            type: "array",
            items: { type: "string" },
            maxItems: 3,
          },
          resources_mentioned: {
            type: "array",
            items: { type: "string" },
            maxItems: 10,
          },
          session_duration_minutes: { type: "number" },
          actions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                description: { type: "string" },
                category: { type: "string" },
                priority: { type: "string", enum: ["low", "medium", "high"] },
                source: {
                  type: "string",
                  enum: ["user_stated", "ai_suggested"],
                },
              },
              required: ["description", "source"],
              additionalProperties: false,
            },
            maxItems: 10,
          },
        },
        required: [
          "summary_before",
          "summary_after",
          "problem_focus_percentage",
          "solution_focus_percentage",
          "shift_percentage",
          "thinking_style_today",
          "best_ideas",
          "strength_highlight",
          "positive_quotes",
          "resources_mentioned",
          "session_duration_minutes",
          "actions",
        ],
        additionalProperties: true,
      },
      strict: true,
    };

    const prompt = [
      {
        role: "system",
        content:
          "You analyze a user’s thinking session and return strictly the JSON that fits the provided schema. Be concise, faithful to the user's words, and produce practical actions.",
      },
      {
        role: "user",
        content: `Transcript:\n${transcript}\n\nReturn JSON only. Estimate session_duration_minutes if missing.`,
      },
    ];

    const resp = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-5",
        input: prompt,
        response_format: { type: "json_schema", json_schema: schema },
        reasoning: { effort: "medium" },
        temperature: 0.2,
      }),
    });

    if (!resp.ok) {
      const aErr = await resp.text();
      console.error("Analysis error:", aErr);
      await markFailed(supabase, sessionId);
      return new Response("Analysis failed", { status: 502 });
    }

    const analysisPayload = await resp.json();
    const parsed: Analysis = parseResponsesJson(analysisPayload);

    // Write results
    const { error: sessUpdErr } = await supabase
      .from("sessions")
      .update({ raw_transcript: transcript, processing_status: "completed" })
      .eq("id", sessionId);
    if (sessUpdErr) {
      console.error("sessions update err", sessUpdErr);
      await markFailed(supabase, sessionId);
      return new Response("DB update failed", { status: 500 });
    }

    const analysisRow = {
      session_id: sessionId,
      summary_before: parsed.summary_before,
      summary_after: parsed.summary_after,
      problem_focus_percentage: parsed.problem_focus_percentage,
      solution_focus_percentage: parsed.solution_focus_percentage,
      shift_percentage: parsed.shift_percentage,
      thinking_style_today: parsed.thinking_style_today,
      thinking_patterns: parsed.thinking_patterns ?? {},
      best_ideas: parsed.best_ideas ?? [],
      strength_highlight: parsed.strength_highlight,
      positive_quotes: parsed.positive_quotes ?? [],
      resources_mentioned: parsed.resources_mentioned ?? [],
      session_duration_minutes:
        parsed.session_duration_minutes ??
        (sessionRow.duration_seconds ?? 0) / 60,
    };

    const { error: upsertErr } = await supabase
      .from("session_analysis")
      .upsert(analysisRow, { onConflict: "session_id" });
    if (upsertErr) {
      console.error("analysis upsert err", upsertErr);
      await markFailed(supabase, sessionId);
      return new Response("DB upsert failed", { status: 500 });
    }

    const actions = Array.isArray(parsed.actions) ? parsed.actions : [];
    if (actions.length) {
      const rows = actions.map((a) => ({
        session_id: sessionId,
        description: a.description,
        category: a.category ?? null,
        priority: a.priority ?? "medium",
        source: a.source ?? "ai_suggested",
        status: "pending",
      }));
      const { error: actErr } = await supabase
        .from("action_items")
        .insert(rows);
      if (actErr) {
        console.error("action_items insert err", actErr);
      }
    }

    return new Response(JSON.stringify({ status: "ok" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});

function parseResponsesJson(payload: any): any {
  try {
    const out = payload?.output?.[0]?.content?.[0];
    if (out?.type === "output_text" && typeof out?.text === "string") {
      return JSON.parse(out.text);
    }
    if (typeof payload?.output_text === "string") {
      return JSON.parse(payload.output_text);
    }
  } catch (_) {}
  return {};
}

async function markFailed(
  supabase: ReturnType<typeof createClient>,
  sessionId: string
) {
  await supabase
    .from("sessions")
    .update({ processing_status: "failed" })
    .eq("id", sessionId);
}
