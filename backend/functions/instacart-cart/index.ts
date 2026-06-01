import { requireAuth, AuthError } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

interface RequestItem {
  name: string;
  quantity?: string;
  display_text?: string;
}

interface CartRequest {
  title?: string;
  items: RequestItem[];
}

// Instacart Developer Platform. Defaults to production; override with INSTACART_API_BASE
// (e.g. https://connect.dev.instacart.tools while testing with a development key).
const API_BASE = Deno.env.get("INSTACART_API_BASE") ?? "https://connect.instacart.com";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    await requireAuth(req);

    const apiKey = Deno.env.get("INSTACART_API_KEY");
    if (!apiKey) {
      // Not configured yet — tell the client to fall back to the deep-link flow.
      return new Response(JSON.stringify({ error: "not_configured" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json()) as CartRequest;
    const items = Array.isArray(body.items) ? body.items : [];
    if (items.length === 0) {
      return new Response(JSON.stringify({ error: "no_items" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const lineItems = items
      .filter((i) => i.name && i.name.trim().length > 0)
      .map((i) => {
        const measurements = i.quantity && i.quantity.trim().length > 0
          ? [{ quantity: 1, unit: i.quantity.trim() }]
          : undefined;
        return {
          name: i.name.trim(),
          display_text: i.display_text?.trim() || i.name.trim(),
          ...(measurements ? { line_item_measurements: measurements } : {}),
        };
      });

    const payload = {
      title: body.title?.trim() || "My Shopping List",
      link_type: "shopping_list",
      line_items: lineItems,
      landing_page_configuration: {
        partner_linkback_url: "https://rork.app",
        enable_pantry_items: true,
      },
    };

    const resp = await fetch(`${API_BASE}/idp/v1/products/products_link`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error("Instacart API error", resp.status, text);
      return new Response(JSON.stringify({ error: "instacart_failed", status: resp.status }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const data = await resp.json();
    const url = data?.products_link_url as string | undefined;
    if (!url) {
      return new Response(JSON.stringify({ error: "no_url" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ url }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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
