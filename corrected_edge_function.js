// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: corsHeaders
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) {
      return new Response("Unauthorized", {
        status: 401,
        headers: corsHeaders
      });
    }

    const { sessionId, audioUrl, patternType, originalQuestion } = await req.json();
    console.log("[ProcessPatternExploration] Received parameters:", { sessionId, audioUrl, patternType, originalQuestion });

    if (!sessionId || !audioUrl) {
      return new Response("Missing sessionId or audioUrl", {
        status: 400,
        headers: corsHeaders
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`
        }
      }
    });

    console.log("[ProcessPatternExploration] Starting processing for session:", sessionId);

    // Fetch the audio file
    console.log("[ProcessPatternExploration] Fetching audio from:", audioUrl);
    const audioResp = await fetch(audioUrl);
    if (!audioResp.ok) {
      console.error("[ProcessPatternExploration] Failed to fetch audio, status:", audioResp.status);
      return new Response("Failed to fetch audio", {
        status: 502,
        headers: corsHeaders
      });
    }

    // Transcribe the exploration response
    console.log("[ProcessPatternExploration] Starting transcription...");
    const form = new FormData();
    const audioBlob = await audioResp.blob();
    form.append("file", new File([audioBlob], "exploration.m4a", { type: "audio/m4a" }));
    form.append("model", "whisper-1"); // Fixed: Use whisper-1, not gpt-4o-transcribe

    const transcribeResp = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`
      },
      body: form
    });

    if (!transcribeResp.ok) {
      const tErr = await transcribeResp.text();
      console.error("[ProcessPatternExploration] Transcribe error:", tErr);
      return new Response("Transcription failed", {
        status: 502,
        headers: corsHeaders
      });
    }

    const transcribed = await transcribeResp.json();
    const explorationTranscript = transcribed.text ?? "";
    console.log("[ProcessPatternExploration] Transcription completed, length:", explorationTranscript.length);

    // Analyze the deeper exploration response
    console.log("[ProcessPatternExploration] Analyzing exploration response...");
    const prompt = `You are analyzing a deeper exploration response about a ${patternType} pattern.

The person was asked: "${originalQuestion}"

Their response: "${explorationTranscript}"

Based on their deeper exploration, provide insights and actionable steps.

TONE: Write directly to them using "you". Be warm, empathetic, and encouraging.

Return JSON with this exact structure:
{
  "insight": "A thoughtful insight about what you discovered through their deeper exploration (2-3 sentences, personal tone)",
  "key_realization": "The main thing they seem to have realized or uncovered (1 sentence)",
  "suggested_actions": [
    {
      "description": "Specific, actionable step they could take based on their insights",
      "category": "next_step", 
      "priority": "high|medium|low"
    }
  ],
  "encouragement": "Brief encouraging message about their self-awareness or growth (1-2 sentences)"
}

Focus on what THEY specifically shared and make it feel personal to their unique situation.

Return only valid JSON:`;

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You are an empathetic coach analyzing deeper self-exploration. Provide personalized insights and actionable steps based on what they shared. Be warm and encouraging."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        response_format: {
          type: "json_object"
        },
        temperature: 0.4
      })
    });

    if (!resp.ok) {
      const aErr = await resp.text();
      console.error("[ProcessPatternExploration] Analysis error:", aErr);
      return new Response("Analysis failed", {
        status: 502,
        headers: corsHeaders
      });
    }

    const analysisPayload = await resp.json();
    const content = analysisPayload.choices?.[0]?.message?.content;

    if (!content) {
      console.error("[ProcessPatternExploration] No content in analysis response");
      return new Response("Analysis failed", {
        status: 502,
        headers: corsHeaders
      });
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error("[ProcessPatternExploration] Failed to parse analysis JSON:", e);
      console.error("[ProcessPatternExploration] Raw content:", content);
      return new Response("Analysis parsing failed", {
        status: 502,
        headers: corsHeaders
      });
    }

    // Store the pattern exploration insights - ACTUALLY INSERT INTO DATABASE
    const explorationData = {
      session_id: sessionId,
      pattern_type: patternType,
      original_question: originalQuestion,
      exploration_transcript: explorationTranscript,
      insight: parsed.insight,
      key_realization: parsed.key_realization,
      encouragement: parsed.encouragement,
      audio_url: audioUrl
    };

    console.log("[ProcessPatternExploration] About to insert exploration data:", JSON.stringify(explorationData, null, 2));

    // INSERT THE INSIGHTS - This was commented out in your version!
    const { data: insertedData, error: insightError } = await supabase
      .from("pattern_exploration_insights")
      .insert(explorationData)
      .select();

    if (insightError) {
      console.error("[ProcessPatternExploration] Failed to insert insights:", JSON.stringify(insightError, null, 2));
      return new Response("Database insertion failed", {
        status: 500,
        headers: corsHeaders
      });
    } else {
      console.log("[ProcessPatternExploration] Successfully stored pattern exploration insights");
      console.log("[ProcessPatternExploration] Inserted data:", JSON.stringify(insertedData, null, 2));
    }

    // Add the suggested actions as action items automatically
    const actions = Array.isArray(parsed.suggested_actions) ? parsed.suggested_actions : [];
    console.log("[ProcessPatternExploration] Parsed actions from LLM:", JSON.stringify(actions, null, 2));

    if (actions.length > 0) {
      const actionRows = actions.map((a) => ({
        session_id: sessionId,
        description: a.description,
        category: a.category ?? "next_step",
        priority: a.priority ?? "medium",
        source: "deeper_exploration",
        status: "pending"
      }));

      console.log("[ProcessPatternExploration] About to insert action items:", JSON.stringify(actionRows, null, 2));

      const { data: insertedActions, error: actionError } = await supabase
        .from("action_items")
        .insert(actionRows)
        .select();

      if (actionError) {
        console.error("[ProcessPatternExploration] Failed to insert action items:", JSON.stringify(actionError, null, 2));
      } else {
        console.log(`[ProcessPatternExploration] Successfully inserted ${actionRows.length} enhanced action items`);
        console.log("[ProcessPatternExploration] Inserted action items:", JSON.stringify(insertedActions, null, 2));
      }
    } else {
      console.log("[ProcessPatternExploration] No actions to insert");
    }

    console.log("[ProcessPatternExploration] Processing completed successfully");

    return new Response(JSON.stringify({
      status: "success",
      exploration_transcript: explorationTranscript,
      analysis: parsed
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders
      }
    });
  } catch (e) {
    console.error("[ProcessPatternExploration] Unexpected error:", e);
    return new Response("Internal error", {
      status: 500,
      headers: corsHeaders
    });
  }
}); 