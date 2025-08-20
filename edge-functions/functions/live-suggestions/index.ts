import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

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

    const { transcript } = await req.json();
    if (typeof transcript !== "string" || transcript.trim().length === 0) {
      return new Response(JSON.stringify({ suggestions: [] }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Focus on a recent window to keep responses timely and specific
    const _trimmed = transcript.trim();
    const recent = _trimmed.length > 1000 ? _trimmed.slice(-1000) : _trimmed;

    const system = `You are a warm, neutral, non-judgmental thinking partner in a SuperThinking session.
Your job is to provide gentle, context-aware nudges that help users reflect, clarify, and move forward.

Make the prompts feel personal and grounded in what the user actually said:
- Quote or paraphrase exact phrases when helpful: “you said ‘…’”.
- Name concrete nouns from their context (people, docs, dates): “Sam”, “Q3 report”, “Friday”.
- Prefer short, time-boxed steps: “10 minutes”, “today”, “this week”.
- One idea per prompt; neutral, curious, and non-judgmental.
- Avoid therapy language, diagnoses, or moralizing. Avoid generic advice.

Format rules:
- Each suggestion must be 12–80 characters.
- Return ONLY JSON of the form {"suggestions": ["...", "..."]} with 1–3 items.`;

    const user = `Recent transcript window (may be messy):\n\n${recent}\n\nGenerate 1–3 subtle, personal prompts following the rules.`;

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        max_tokens: 90,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "live_suggestions",
            strict: true,
            schema: {
              type: "object",
              properties: {
                suggestions: {
                  type: "array",
                  minItems: 1,
                  maxItems: 2,
                  items: { type: "string", minLength: 12, maxLength: 80 },
                },
              },
              required: ["suggestions"],
              additionalProperties: false,
            },
          },
        },
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error("[live-suggestions] OpenAI error:", text);
      return new Response(JSON.stringify({ suggestions: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload = await resp.json();

    // If model already returns JSON (response_format), use it directly
    let suggestions: string[] = [];
    const maybeList =
      payload?.choices?.[0]?.message?.parsed ??
      payload?.choices?.[0]?.message?.content;

    if (Array.isArray(maybeList?.suggestions)) {
      suggestions = maybeList.suggestions
        .map((s: unknown) => String(s || "").trim())
        .filter((s: string) => s.length > 0);
    } else if (typeof maybeList === "string") {
      // Fallback: try to parse JSON string or salvage lines
      try {
        const parsed = JSON.parse(maybeList);
        if (Array.isArray(parsed?.suggestions)) {
          suggestions = parsed.suggestions
            .map((s: unknown) => String(s || "").trim())
            .filter((s: string) => s.length > 0);
        }
      } catch {
        const lines = maybeList
          .split("\n")
          .map((l: string) => l.trim())
          .filter((l: string) => l.length > 0 && !l.startsWith("{"));
        suggestions = lines.slice(0, 3);
      }
    }

    // Final fallback: synthesize a single compact prompt if still empty
    if (!suggestions.length) {
      const lastSentence = (
        recent.split(/(?<=[.!?])\s+/).pop() || recent
      ).trim();
      const compact =
        lastSentence.length > 80
          ? lastSentence.slice(0, 77) + "…"
          : lastSentence;
      suggestions = compact
        ? [
            compact.endsWith("?")
              ? compact
              : `You said: “${compact}” — what feels like the next 10‑min step?`,
          ]
        : ["What feels like the next 10‑min step?"];
    }

    return new Response(JSON.stringify({ suggestions }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[live-suggestions] Unexpected error:", e);
    return new Response(JSON.stringify({ suggestions: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
