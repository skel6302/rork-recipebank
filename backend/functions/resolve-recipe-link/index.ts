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
    return {
      title: typeof data.title === "string" ? data.title : "",
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
    const caption = metaContent(html, [
      "og:description",
      "twitter:description",
      "description",
    ]);
    let author = metaContent(html, ["author", "og:site_name"]);

    if (!title) {
      const m = html.match(/<title[^>]*>([^<]*)<\/title>/i);
      if (m) title = decodeEntities(m[1].trim());
    }

    // Fill gaps via oEmbed (gives a clean title/author even when meta tags are stripped).
    if (!title || !author) {
      const oembed = await tryOEmbed(resolvedUrl, platform);
      if (oembed) {
        if (!title && oembed.title) title = oembed.title;
        if (!author && oembed.author) author = oembed.author;
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
