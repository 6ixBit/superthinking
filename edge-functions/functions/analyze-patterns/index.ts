// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: corsHeaders,
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) {
      return new Response("Unauthorized", {
        status: 401,
        headers: corsHeaders,
      });
    }

    const { sessionId } = await req.json();
    if (!sessionId) {
      return new Response("Missing sessionId", {
        status: 400,
        headers: corsHeaders,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    console.log(
      "[AnalyzePatterns] Starting pattern analysis for session:",
      sessionId
    );

    // Fetch session transcript (RLS enforced by user JWT)
    const { data: sessionRow, error: sessErr } = await supabase
      .from("sessions")
      .select("id, user_id, raw_transcript")
      .eq("id", sessionId)
      .maybeSingle();

    if (sessErr || !sessionRow) {
      console.error("[AnalyzePatterns] Session not found:", sessErr);
      return new Response("Session not found", {
        status: 404,
        headers: corsHeaders,
      });
    }

    const transcript = sessionRow.raw_transcript;
    if (!transcript || transcript.trim().length === 0) {
      console.error("[AnalyzePatterns] No transcript found");
      return new Response(JSON.stringify({ has_patterns: false }), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    console.log("[AnalyzePatterns] Analyzing transcript for patterns...");

    const prompt = `Analyze this thinking session transcript for psychological patterns and thinking styles that would benefit from deeper exploration.

Look for:
- Cognitive patterns (catastrophizing, all-or-nothing thinking, rumination, overthinking loops)
- Emotional patterns (anxiety spirals, self-doubt, imposter syndrome, avoidance)
- Behavioral patterns (procrastination triggers, decision paralysis, perfectionism)
- Language patterns (frequent use of "should/must", absolute terms, self-criticism)
- Thinking traps (people-pleasing, comparison, future worrying, past dwelling)

IMPORTANT: Only flag patterns that are:
1. Clear and evident in the transcript
2. Would genuinely benefit from deeper exploration
3. Not just normal human concerns

TONE: Write as if speaking directly to the person. Use "you" instead of "user" or "they". Be warm, empathetic, and conversational.

Return JSON with this exact structure:
{
  "has_patterns": true/false,
  "primary_pattern": {
    "type": "rumination|catastrophizing|perfectionism|avoidance|overthinking|self_doubt|people_pleasing|comparison|procrastination|decision_paralysis",
    "description": "Brief, empathetic description written directly to them (use 'you')",
    "evidence": "Direct quote from transcript that shows this pattern"
  },
  "follow_up_question": "One thoughtful, specific question addressed directly to them (under 20 words)",
  "insight_preview": "Brief preview of what exploring this could reveal for them (under 25 words)"
}

If no significant patterns detected, return has_patterns: false and omit other fields.

Transcript:
${transcript}

Return only valid JSON:`;

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are an expert psychologist analyzing thinking patterns in SuperThinking sessions. Be precise and only flag patterns that would genuinely benefit from deeper exploration. Return only valid JSON.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        response_format: {
          type: "json_object",
        },
        temperature: 0.3, // Lower temperature for more consistent pattern detection
      }),
    });

    if (!resp.ok) {
      const aErr = await resp.text();
      console.error("[AnalyzePatterns] Analysis error:", aErr);
      return new Response("Pattern analysis failed", {
        status: 502,
        headers: corsHeaders,
      });
    }

    const analysisPayload = await resp.json();
    const content = analysisPayload.choices?.[0]?.message?.content;

    if (!content) {
      console.error("[AnalyzePatterns] No content in analysis response");
      return new Response("Pattern analysis failed", {
        status: 502,
        headers: corsHeaders,
      });
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error("[AnalyzePatterns] Failed to parse analysis JSON:", e);
      console.error("[AnalyzePatterns] Raw content:", content);
      return new Response("Pattern analysis parsing failed", {
        status: 502,
        headers: corsHeaders,
      });
    }

    console.log("[AnalyzePatterns] Pattern analysis completed successfully");
    console.log("[AnalyzePatterns] Has patterns:", parsed.has_patterns);

    return new Response(JSON.stringify(parsed), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (e) {
    console.error("[AnalyzePatterns] Unexpected error:", e);
    return new Response("Internal error", {
      status: 500,
      headers: corsHeaders,
    });
  }
});
