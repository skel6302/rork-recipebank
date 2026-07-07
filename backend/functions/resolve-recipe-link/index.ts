import { requireAuth, AuthError } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

interface ResolveRequest {
  url?: string;
}

interface ResolvedPost {
  /** The platform we recognised the link as (tiktok, instagram, youtube, web). */
  platform: string;
  /** Best-effort post title (og:title / page <title>). */
  title: string;
  /** Author / uploader handle when available. */
  author: string;
  /** The caption / description text — the most valuable signal for the recipe. */
  caption: string;
  /** The final URL after following redirects (short links resolve here). */
  resolvedUrl: string;
}

// A desktop browser UA — social platforms gate their og: meta tags behind a
// "real browser" check, so a generic fetch UA often gets a stripped page.
const BROWSER_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36";

function decodeEntities(input: string): string {
  return input
    .replace(/&quot;/g, '"')
    .replace(/&#34;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_m, dec) => String.fromCodePoint(parseInt(dec, 10)));
}

/** Pulls the content of the first matching <meta> tag (property or name). */
function metaContent(html: string, keys: string[]): string {
  for (const key of keys) {
    const patterns = [
      new RegExp(`<meta[^>]+(?:property|name)=["']${key}["'][^>]+content=["']([^"']*)["']`, "i"),
      new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]+(?:property|name)=["']${key}["']`, "i"),
    ];
    for (const re of patterns) {
      const m = html.match(re);
      if (m && m[1] && m[1].trim().length > 0) return decodeEntities(m[1].trim());
    }
  }
  return "";
}

function platformFor(url: string): string {
  const h = url.toLowerCase();
  if (h.includes("tiktok.")) return "tiktok";
  if (h.includes("instagram.")) return "instagram";
  if (h.includes("youtube.") || h.includes("youtu.be")) return "youtube";
  if (h.includes("pinterest.") || h.includes("pin.it")) return "pinterest";
  if (h.includes("facebook.") || h.includes("fb.watch")) return "facebook";
  return "web";
}

/**
 * Extracts a schema.org Recipe from JSON-LD blocks. Most recipe websites
 * embed the full ingredient list and instructions here — far richer than the
 * one-line og:description meta tag.
 */
function extractJsonLdRecipe(html: string): { title: string; text: string; author: string } | null {
  const blocks = html.matchAll(
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  for (const block of blocks) {
    let data: unknown;
    try {
      data = JSON.parse(block[1]);
    } catch {
      continue;
    }
    const recipe = findRecipeNode(data);
    if (!recipe) continue;

    const name = typeof recipe.name === "string" ? recipe.name : "";
    const description = typeof recipe.description === "string" ? recipe.description : "";
    const ingredients = toStringArray(recipe.recipeIngredient ?? recipe.ingredients);
    const steps = extractInstructions(recipe.recipeInstructions);
    if (ingredients.length === 0 && steps.length === 0) continue;

    const parts: string[] = [];
    if (description) parts.push(description);
    if (recipe.recipeYield) parts.push(`Servings: ${flattenYield(recipe.recipeYield)}`);
    if (typeof recipe.totalTime === "string") parts.push(`Total time: ${recipe.totalTime}`);
    if (ingredients.length > 0) {
      parts.push("INGREDIENTS:\n" + ingredients.map((i) => `- ${i}`).join("\n"));
    }
    if (steps.length > 0) {
      parts.push("INSTRUCTIONS:\n" + steps.map((s, i) => `${i + 1}. ${s}`).join("\n"));
    }

    let author = "";
    const a = recipe.author;
    if (typeof a === "string") author = a;
    else if (a && typeof a === "object") {
      const first = Array.isArray(a) ? a[0] : a;
      if (first && typeof first.name === "string") author = first.name;
    }

    return { title: name, text: parts.join("\n\n"), author };
  }
  return null;
}

// deno-lint-ignore no-explicit-any
function findRecipeNode(node: unknown): Record<string, any> | null {
  if (!node || typeof node !== "object") return null;
  if (Array.isArray(node)) {
    for (const item of node) {
      const found = findRecipeNode(item);
      if (found) return found;
    }
    return null;
  }
  // deno-lint-ignore no-explicit-any
  const obj = node as Record<string, any>;
  const type = obj["@type"];
  const types = Array.isArray(type) ? type : [type];
  if (types.includes("Recipe")) return obj;
  if (obj["@graph"]) return findRecipeNode(obj["@graph"]);
  return null;
}

function toStringArray(value: unknown): string[] {
  if (typeof value === "string") return [decodeEntities(value.trim())].filter(Boolean);
  if (!Array.isArray(value)) return [];
  return value
    .map((v) => (typeof v === "string" ? decodeEntities(v.trim()) : ""))
    .filter(Boolean);
}

/** recipeInstructions may be a string, string[], HowToStep[], or HowToSection[]. */
function extractInstructions(value: unknown): string[] {
  const out: string[] = [];
  const walk = (v: unknown) => {
    if (!v) return;
    if (typeof v === "string") {
      const cleaned = decodeEntities(v.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim());
      if (cleaned) out.push(cleaned);
      return;
    }
    if (Array.isArray(v)) {
      v.forEach(walk);
      return;
    }
    if (typeof v === "object") {
      // deno-lint-ignore no-explicit-any
      const obj = v as Record<string, any>;
      if (typeof obj.text === "string") walk(obj.text);
      else if (obj.itemListElement) walk(obj.itemListElement);
      else if (typeof obj.name === "string") walk(obj.name);
    }
  };
  walk(value);
  return out;
}

function flattenYield(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  if (Array.isArray(value)) return value.map(flattenYield).filter(Boolean).join(" / ");
  return "";
}

/**
 * Strips a web page down to its readable text so the AI parser can find the
 * recipe even when the site has no structured data. Prefers <article>/<main>
 * content and caps the size to keep the AI prompt sane.
 */
function extractPageText(html: string, maxChars = 15000): string {
  let scoped = html;
  const article = html.match(/<article[\s\S]*?<\/article>/i);
  const main = html.match(/<main[\s\S]*?<\/main>/i);
  if (article && article[0].length > 1500) scoped = article[0];
  else if (main && main[0].length > 1500) scoped = main[0];

  const text = scoped
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<svg[\s\S]*?<\/svg>/gi, " ")
    .replace(/<(?:nav|header|footer)[\s\S]*?<\/(?:nav|header|footer)>/gi, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(?:p|li|h1|h2|h3|h4|div|tr)>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .split("\n")
    .map((line) => decodeEntities(line).replace(/[ \t]+/g, " ").trim())
    .filter((line) => line.length > 0)
    .join("\n");

  return text.length > maxChars ? text.slice(0, maxChars) : text;
}

/** Tries the platform oEmbed endpoint, which returns clean JSON metadata. */
async function tryOEmbed(url: string, platform: string): Promise<Partial<ResolvedPost> | null> {
  let endpoint: string | null = null;
  if (platform === "tiktok") {
    endpoint = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
  } else if (platform === "youtube") {
    endpoint = `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`;
  }
  if (!endpoint) return null;

  try {
    const resp = await fetch(endpoint, { headers: { "User-Agent": BROWSER_UA } });
    if (!resp.ok) return null;
    const data = await resp.json();
    // On TikTok/YouTube the oEmbed `title` field holds the full post caption
    // (the most valuable signal for the recipe), so surface it as the caption too.
    const oTitle = typeof data.title === "string" ? data.title : "";
    return {
      title: oTitle,
      caption: oTitle,
      author: typeof data.author_name === "string" ? data.author_name : "",
    };
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    await requireAuth(req);

    const body = (await req.json()) as ResolveRequest;
    const raw = (body.url ?? "").trim();
    if (!raw) {
      return new Response(JSON.stringify({ error: "no_url" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let target = raw;
    if (!/^https?:\/\//i.test(target)) target = `https://${target}`;

    let parsed: URL;
    try {
      parsed = new URL(target);
    } catch {
      return new Response(JSON.stringify({ error: "invalid_url" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the page, following redirects (short links like vm.tiktok.com resolve here).
    let html = "";
    let resolvedUrl = parsed.toString();
    try {
      const resp = await fetch(parsed.toString(), {
        headers: {
          "User-Agent": BROWSER_UA,
          "Accept-Language": "en-US,en;q=0.9",
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
        redirect: "follow",
      });
      resolvedUrl = resp.url || resolvedUrl;
      html = await resp.text();
    } catch (e) {
      console.error("fetch failed", e);
    }

    const platform = platformFor(resolvedUrl);

    let title = metaContent(html, ["og:title", "twitter:title"]);
    let caption = metaContent(html, [
      "og:description",
      "twitter:description",
      "description",
    ]);
    let author = metaContent(html, ["author", "og:site_name"]);

    if (!title) {
      const m = html.match(/<title[^>]*>([^<]*)<\/title>/i);
      if (m) title = decodeEntities(m[1].trim());
    }

    // Web pages: og:description is usually a one-line marketing blurb with no
    // ingredients or steps. Pull the real recipe from schema.org JSON-LD when
    // present, otherwise fall back to the readable article text.
    if (platform === "web" || platform === "pinterest" || platform === "facebook") {
      const jsonLd = extractJsonLdRecipe(html);
      if (jsonLd) {
        if (jsonLd.title) title = jsonLd.title;
        if (jsonLd.author) author = jsonLd.author;
        caption = jsonLd.text;
      } else if (html.length > 0) {
        const pageText = extractPageText(html);
        if (pageText.length > caption.length) {
          caption = caption ? `${caption}\n\nPAGE TEXT:\n${pageText}` : pageText;
        }
      }
    }

    // Fill gaps via oEmbed. Social platforms (esp. TikTok) routinely strip og:
    // meta tags for datacenter fetches, but their oEmbed JSON still returns the
    // full caption — which is exactly the recipe text we need.
    if (!caption || !title || !author) {
      const oembed = await tryOEmbed(resolvedUrl, platform);
      if (oembed) {
        if (!title && oembed.title) title = oembed.title;
        if (!author && oembed.author) author = oembed.author;
        // Prefer the oEmbed caption when the page gave us little or nothing —
        // it's usually far richer than a truncated og:description.
        if (oembed.caption && oembed.caption.length > caption.length) {
          caption = oembed.caption;
        }
      }
    }

    const result: ResolvedPost = {
      platform,
      title: title ?? "",
      author: author ?? "",
      caption: caption ?? "",
      resolvedUrl,
    };

    // If we couldn't extract anything useful, surface that so the client can
    // tell the user to paste the caption manually.
    if (!result.title && !result.caption) {
      return new Response(
        JSON.stringify({ error: "no_content", ...result }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(JSON.stringify(result), {
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
