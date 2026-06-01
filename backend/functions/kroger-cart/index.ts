import { requireAuth, AuthError } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const KROGER_BASE = Deno.env.get("KROGER_API_BASE") ?? "https://api.kroger.com";

interface CartItem {
  name: string;
  quantity?: number;
}

interface CartRequest {
  /** The customer's Kroger access token (cart.basic:write scope). */
  accessToken: string;
  /** Shopping-list items to add. */
  items: CartItem[];
  /** Optional Kroger store/location id to scope product search. */
  locationId?: string;
  /** "PICKUP" or "DELIVERY". Defaults to PICKUP. */
  modality?: string;
  /** Public Kroger client id, paired with the server-side secret. */
  clientId?: string;
}

interface KrogerProduct {
  upc?: string;
  description?: string;
}

interface KrogerProductResponse {
  data?: KrogerProduct[];
}

/** Fetches an app-level client-credentials token scoped for product search. */
async function getProductToken(clientId: string, clientSecret: string): Promise<string | null> {
  const form = new URLSearchParams();
  form.set("grant_type", "client_credentials");
  form.set("scope", "product.compact");

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
    console.error("Kroger product token error", resp.status, await resp.text());
    return null;
  }
  const data = await resp.json();
  return (data?.access_token as string | undefined) ?? null;
}

/** Searches Kroger products for a term and returns the first matching UPC. */
async function findUPC(
  term: string,
  token: string,
  locationId?: string,
): Promise<string | null> {
  const params = new URLSearchParams();
  params.set("filter.term", term);
  params.set("filter.limit", "1");
  if (locationId) params.set("filter.locationId", locationId);

  const resp = await fetch(`${KROGER_BASE}/v1/products?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
  });
  if (!resp.ok) {
    console.error("Kroger product search error", term, resp.status);
    return null;
  }
  const data = (await resp.json()) as KrogerProductResponse;
  return data.data?.[0]?.upc ?? null;
}

/**
 * Maps shopping-list item names to Kroger UPCs via product search, then adds
 * them to the authenticated customer's Kroger cart.
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

    const body = (await req.json()) as CartRequest;
    const clientId = envClientId ?? body.clientId;
    if (!clientId) {
      return new Response(JSON.stringify({ error: "missing_client_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!body.accessToken) {
      return new Response(JSON.stringify({ error: "missing_access_token" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const items = Array.isArray(body.items) ? body.items : [];
    if (items.length === 0) {
      return new Response(JSON.stringify({ error: "no_items" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const productToken = await getProductToken(clientId, clientSecret);
    if (!productToken) {
      return new Response(JSON.stringify({ error: "product_token_failed" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const modality = body.modality === "DELIVERY" ? "DELIVERY" : "PICKUP";
    const matched: { upc: string; quantity: number }[] = [];
    const unmatched: string[] = [];

    for (const item of items) {
      const term = item.name?.trim();
      if (!term) continue;
      const upc = await findUPC(term, productToken, body.locationId);
      if (upc) {
        matched.push({ upc, quantity: Math.max(1, Math.round(item.quantity ?? 1)) });
      } else {
        unmatched.push(term);
      }
    }

    if (matched.length === 0) {
      return new Response(JSON.stringify({ error: "no_matches", unmatched }), {
        status: 422,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cartResp = await fetch(`${KROGER_BASE}/v1/cart/add`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${body.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        items: matched.map((m) => ({ upc: m.upc, quantity: m.quantity, modality })),
      }),
    });

    if (cartResp.status === 401 || cartResp.status === 403) {
      return new Response(JSON.stringify({ error: "kroger_unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!cartResp.ok) {
      console.error("Kroger cart add error", cartResp.status, await cartResp.text());
      return new Response(JSON.stringify({ error: "cart_add_failed", status: cartResp.status }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ added: matched.length, total: items.length, unmatched }),
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
