// SafeMate Supabase Edge Function: Journey Copilot AI Gateway
// Universal Engineering Rule #11: Production AI credentials remain strictly server-side.
// Universal Engineering Rule #10: Privacy-first context validation and fail-closed security.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.8.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CopilotRequest {
  feature: string;
  system_prompt: string;
  user_prompt: string;
  context: Record<string, unknown>;
  max_tokens?: number;
  temperature?: number;
}

const DENYLIST = [
  "aadhaar",
  "government_id",
  "id_number",
  "passport",
  "phone",
  "phone_number",
  "email",
  "raw_address",
  "lat",
  "latitude",
  "lon",
  "longitude",
  "exact_coordinates",
  "auth_token",
  "password",
  "pin",
  "secret_code",
  "emergency_contact_phone",
  "risk_score",
];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Verify Authorization Header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized request" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Parse & Validate Payload
    const body: CopilotRequest = await req.json();

    // Check denylist on server side
    const contextKeys = Object.keys(body.context || {});
    for (const key of contextKeys) {
      if (DENYLIST.includes(key.toLowerCase())) {
        return new Response(
          JSON.stringify({ error: `Privacy violation: forbidden key '${key}' in context.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 3. Read Server-Side Gemini API Key
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      // In production, server configuration missing returns structured service unavailable
      return new Response(
        JSON.stringify({
          error: "AI provider service unavailable.",
          code: "unavailable",
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Call Google Gemini 1.5 Flash via REST endpoint
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`;

    const geminiResponse = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              {
                text: `${body.system_prompt}\n\nContext: ${JSON.stringify(body.context)}\n\nUser Question: ${body.user_prompt}`,
              },
            ],
          },
        ],
        generationConfig: {
          maxOutputTokens: body.max_tokens || 1024,
          temperature: body.temperature || 0.4,
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errData = await geminiResponse.text();
      console.error("[Gemini Error]", errData);
      return new Response(
        JSON.stringify({ error: "AI provider request failed", code: "provider_error" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiResponse.json();
    const candidateText =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ||
      "I am unable to generate a response at this time.";

    return new Response(
      JSON.stringify({
        content: candidateText,
        model: "gemini-1.5-flash",
        usage: {
          prompt_tokens: geminiData.usageMetadata?.promptTokenCount || 0,
          completion_tokens: geminiData.usageMetadata?.candidatesTokenCount || 0,
          total_tokens: geminiData.usageMetadata?.totalTokenCount || 0,
        },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    console.error("[Edge Function Exception]", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
