// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
      });
    }
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt)
      return new Response("Unauthorized", {
        status: 401,
      });
    const { sessionId } = await req.json();
    if (!sessionId)
      return new Response("Missing sessionId", {
        status: 400,
      });
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    console.log("[ProcessSession] Starting processing for session:", sessionId);

    // Fetch session (RLS enforced by user JWT)
    const { data: sessionRow, error: sessErr } = await supabase
      .from("sessions")
      .select("id, user_id, audio_url, duration_seconds, processing_status")
      .eq("id", sessionId)
      .maybeSingle();

    if (sessErr || !sessionRow) {
      console.error("[ProcessSession] Session not found:", sessErr);
      return new Response("Session not found", {
        status: 404,
      });
    }

    const audioUrl = sessionRow.audio_url;
    if (!audioUrl) {
      console.error("[ProcessSession] No audio URL found");
      return new Response("No audio_url on session", {
        status: 400,
      });
    }

    console.log("[ProcessSession] Fetching audio from:", audioUrl);
    const audioResp = await fetch(audioUrl);
    if (!audioResp.ok) {
      console.error(
        "[ProcessSession] Failed to fetch audio, status:",
        audioResp.status
      );
      return new Response("Failed to fetch audio", {
        status: 502,
      });
    }
    const audioBlob = await audioResp.blob();
    console.log("[ProcessSession] Audio blob size:", audioBlob.size, "bytes");

    // Whisper transcription
    console.log("[ProcessSession] Starting transcription...");
    const form = new FormData();
    form.append(
      "file",
      new File([audioBlob], "audio.m4a", {
        type: "audio/m4a",
      })
    );
    form.append("model", "gpt-4o-mini-transcribe");

    const transcribeResp = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: form,
      }
    );

    if (!transcribeResp.ok) {
      const tErr = await transcribeResp.text();
      console.error("[ProcessSession] Transcribe error:", tErr);
      await markFailed(supabase, sessionId);
      return new Response("Transcription failed", {
        status: 502,
      });
    }

    const transcribed = await transcribeResp.json();
    const transcript = transcribed.text ?? "";
    console.log(
      "[ProcessSession] Transcription completed, length:",
      transcript.length
    );

    // Generate session title
    console.log("[ProcessSession] Generating session title...");
    const titlePrompt = [
      {
        role: "system",
        content:
          "You generate insightful, contextual titles for SuperThinking sessions - guided thinking sessions where people work through challenges, overthinking, and problems. Create titles that capture the core topic, challenge, or breakthrough moment. Use 3-6 words that feel human and relatable. Examples: 'Overcoming Career Uncertainty', 'Managing Team Conflict', 'Finding Work-Life Balance', 'Processing Recent Breakup', 'Planning Major Life Change', 'Dealing with Imposter Syndrome'. Focus on the actual life situation or challenge, not generic terms.",
      },
      {
        role: "user",
        content: `Based on this thinking session transcript, generate a contextual title (3-6 words) that captures the main life challenge, topic, or breakthrough:\n\n${transcript}\n\nTitle:`,
      },
    ];

    const titleResp = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-5",
          messages: titlePrompt,
          max_completion_tokens: 20,
        }),
      }
    );

    let sessionTitle = "Thinking Session"; // fallback
    if (titleResp.ok) {
      const titlePayload = await titleResp.json();
      const generatedTitle =
        titlePayload.choices?.[0]?.message?.content?.trim();
      if (generatedTitle && generatedTitle.length > 0) {
        sessionTitle = generatedTitle.replace(/^["']|["']$/g, ""); // Remove quotes if present
        console.log("[ProcessSession] Generated title:", sessionTitle);
      }
    } else {
      console.warn("[ProcessSession] Title generation failed, using fallback");
    }

    // Analyze session with improved system prompt
    console.log("[ProcessSession] Starting session analysis...");
    const prompt = `Analyze this thinking session transcript and return JSON with the following structure:

ANALYSIS INSTRUCTIONS:
- problem_focus_percentage: Calculate percentage of time spent on problems, worries, obstacles (0-100)
- solution_focus_percentage: Calculate percentage of time spent on solutions, actions, possibilities (0-100) 
- shift_percentage: How much did thinking shift from problem to solution during session (0-100)
- thinking_style_today: Identify dominant thinking pattern from: "Vision Mapper" (future-focused, "what if"), "Strategic Connector" (logical, step-by-step), "Creative Explorer" (innovative, unconventional), "Reflective Processor" (deep, contemplative)
- actions: ALWAYS include 1-3 specific, concise next steps. Each must have description, category, priority (low|medium|high), source (user_stated|ai_suggested).

{
  "summary_before": "Brief summary of initial thoughts/problems",
  "summary_after": "Brief summary of insights/solutions found", 
  "problem_focus_percentage": 0,
  "solution_focus_percentage": 0,
  "shift_percentage": 0,
  "thinking_style_today": "Vision Mapper|Strategic Connector|Creative Explorer|Reflective Processor",
  "thinking_patterns": {"overthinking": 0, "solution_focused": 0, "future_thinking": 0},
  "best_ideas": ["insight 1", "insight 2"],
  "strength_highlight": "key strength shown",
  "positive_quotes": ["motivating quote from transcript"],
  "resources_mentioned": ["resource 1", "resource 2"],
  "session_duration_minutes": ${Math.round(
    (sessionRow.duration_seconds ?? 0) / 60
  )},
  "actions": [
    {
      "description": "specific action to take",
      "category": "next_step",
      "priority": "high",
      "source": "user_stated"
    }
  ]
}

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
        model: "gpt-5",
        messages: [
          {
            role: "system",
            content:
              "You are an expert at analyzing SuperThinking sessions - guided thinking sessions designed to help people transform overwhelm and overthinking into clarity and actionable insights. These sessions help users shift from problem-focused thinking to solution-focused thinking, identify their strengths, and create concrete next steps. Your analysis should be encouraging, insightful, and focused on the user's growth and positive transformation. Return only valid JSON that matches the requested structure.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
      }),
    });

    if (!resp.ok) {
      const aErr = await resp.text();
      console.error("[ProcessSession] Analysis error:", aErr);
      await markFailed(supabase, sessionId);
      return new Response("Analysis failed", {
        status: 502,
      });
    }

    const analysisPayload = await resp.json();
    const content = analysisPayload.choices?.[0]?.message?.content;

    if (!content) {
      console.error("[ProcessSession] No content in analysis response");
      await markFailed(supabase, sessionId);
      return new Response("Analysis failed", {
        status: 502,
      });
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error("[ProcessSession] Failed to parse analysis JSON:", e);
      console.error("[ProcessSession] Raw content:", content);
      await markFailed(supabase, sessionId);
      return new Response("Analysis parsing failed", {
        status: 502,
      });
    }

    console.log("[ProcessSession] Analysis completed successfully");

    // Write results to sessions table (including title)
    const { error: sessUpdErr } = await supabase
      .from("sessions")
      .update({
        raw_transcript: transcript,
        processing_status: "completed",
        title: sessionTitle,
      })
      .eq("id", sessionId);

    if (sessUpdErr) {
      console.error("[ProcessSession] Sessions update error:", sessUpdErr);
      await markFailed(supabase, sessionId);
      return new Response("DB update failed", {
        status: 500,
      });
    }

    // Insert session analysis
    const analysisRow = {
      session_id: sessionId,
      summary_before: parsed.summary_before || "",
      summary_after: parsed.summary_after || "",
      problem_focus_percentage: parsed.problem_focus_percentage || 50,
      solution_focus_percentage: parsed.solution_focus_percentage || 50,
      shift_percentage: parsed.shift_percentage || 0,
      thinking_style_today: parsed.thinking_style_today || "reflective",
      thinking_patterns: parsed.thinking_patterns || {},
      best_ideas: parsed.best_ideas || [],
      strength_highlight: parsed.strength_highlight || "",
      positive_quotes: parsed.positive_quotes || [],
      resources_mentioned: parsed.resources_mentioned || [],
      session_duration_minutes:
        parsed.session_duration_minutes ||
        Math.round((sessionRow.duration_seconds ?? 0) / 60),
    };

    const { error: upsertErr } = await supabase
      .from("session_analysis")
      .upsert(analysisRow, {
        onConflict: "session_id",
      });

    if (upsertErr) {
      console.error("[ProcessSession] Analysis upsert error:", upsertErr);
      await markFailed(supabase, sessionId);
      return new Response("DB upsert failed", {
        status: 500,
      });
    }

    // Insert action items
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
        console.error("[ProcessSession] Action items insert error:", actErr);
      } else {
        console.log(
          "[ProcessSession] Inserted",
          actions.length,
          "action items"
        );
      }
    }

    console.log(
      "[ProcessSession] Processing completed successfully for session:",
      sessionId
    );
    return new Response(
      JSON.stringify({
        status: "ok",
      }),
      {
        headers: {
          "Content-Type": "application/json",
        },
      }
    );
  } catch (e) {
    console.error("[ProcessSession] Unexpected error:", e);
    return new Response("Internal error", {
      status: 500,
    });
  }
});

async function markFailed(supabase: any, sessionId: string) {
  await supabase
    .from("sessions")
    .update({
      processing_status: "failed",
    })
    .eq("id", sessionId);
}
