// supabase/functions/geocode_city/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Body = {
  query?: string;
};

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { query } = (await req.json()) as Body;

    if (!query || query.trim().length === 0) {
      return new Response(JSON.stringify({ error: "query required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const mapboxToken = Deno.env.get("MAPBOX_TOKEN");
    
    if (!mapboxToken) {
      return new Response(
        JSON.stringify({ error: "Missing MAPBOX_TOKEN" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const url =
      `https://api.mapbox.com/geocoding/v5/mapbox.places/` +
      `${encodeURIComponent(query)}.json` +
      `?access_token=${mapboxToken}&limit=1`;

    const res = await fetch(url);
    const json = await res.json();

    if (!json.features || json.features.length === 0) {
      return new Response(JSON.stringify({ ok: true, found: false }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const [lng, lat] = json.features[0].center;

    return new Response(
      JSON.stringify({
        ok: true,
        found: true,
        lat,
        lng,
        name: json.features[0].place_name,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
