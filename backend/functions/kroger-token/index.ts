import { requireAuth, AuthError } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const KROGER_BASE = Deno.env.get("KROGER_API_BASE") ?? "https://api.kroger.com";

interface TokenRequest {
  /** "authorization_code" or "refresh_token". */
  grantType: "authorization_code" | "refresh_token";
  /** Authorization code from the OAuth redirect (authorization_code grant). */
  code?: string;
  /** The exact redirect URI registered with Kroger (authorization_code grant). */
  redirectUri?: string;
  /** Stored refresh token (refresh_token grant). */
  refreshToken?: string;
  /** Public Kroger client id — sent from the app, paired with the server-side secret. */
  clientId?: string;
}

interface KrogerTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
  scope?: string;
}

/**
 * Exchanges a Kroger OAuth authorization code (or refresh token) for customer
 * access tokens. The client secret never leaves the server.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    await requireAuth(req);

    const clientSecret = Deno.env.get("KROGER_CLIENT_SECRET");
    const envClientId = Deno.env.get("KROGER_CLIENT_ID");
    if (!clientSecret) {
      return new Response(JSON.stringify({ error: "not_configured" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json()) as TokenRequest;
    const clientId = envClientId ?? body.clientId;
    if (!clientId) {
      return new Response(JSON.stringify({ error: "missing_client_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const form = new URLSearchParams();
    if (body.grantType === "authorization_code") {
      if (!body.code || !body.redirectUri) {
        return new Response(JSON.stringify({ error: "missing_params" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      form.set("grant_type", "authorization_code");
      form.set("code", body.code);
      form.set("redirect_uri", body.redirectUri);
    } else if (body.grantType === "refresh_token") {
      if (!body.refreshToken) {
        return new Response(JSON.stringify({ error: "missing_refresh_token" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      form.set("grant_type", "refresh_token");
      form.set("refresh_token", body.refreshToken);
    } else {
      return new Response(JSON.stringify({ error: "invalid_grant_type" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const basic = btoa(`${clientId}:${clientSecret}`);
    const resp = await fetch(`${KROGER_BASE}/v1/connect/oauth2/token`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error("Kroger token error", resp.status, text);
      return new Response(JSON.stringify({ error: "kroger_token_failed", status: resp.status }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const data = (await resp.json()) as KrogerTokenResponse;
    return new Response(
      JSON.stringify({
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        expiresIn: data.expires_in,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    if (err instanceof AuthError) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    console.error(err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
