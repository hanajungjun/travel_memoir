// supabase/functions/delete_travel/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  travel_id?: string;
};

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { travel_id } = (await req.json()) as Body;

    if (!travel_id || travel_id.trim().isEmpty) {
      return new Response(JSON.stringify({ error: "travel_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Missing SUPABASE_URL or SERVICE_ROLE_KEY" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // 1) travel 조회 (user_id, travel_type 등 필요하면 여기서 더 씀)
    const { data: travel, error: travelErr } = await admin
      .from("travels")
      .select("id, user_id, travel_type, region_id")
      .eq("id", travel_id)
      .maybeSingle();

    if (travelErr) throw travelErr;
    if (!travel) {
      return new Response(JSON.stringify({ ok: true, deleted: false, reason: "travel not found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2) Storage 삭제 (travel_images 버킷)
    // - ai/{travelId}/... 전부
    // - user/{travelId}/... 전부
    const bucket = "travel_images";

    async function listAll(prefix: string) {
      const all: string[] = [];
      let offset = 0;
      const limit = 100;

      while (true) {
        const { data, error } = await admin.storage.from(bucket).list(prefix, {
          limit,
          offset,
          sortBy: { column: "name", order: "asc" },
        });

        if (error) throw error;
        if (!data || data.length === 0) break;

        // 파일만 골라서 경로 만들기
        for (const f of data) {
          // Supabase list는 폴더도 섞일 수 있어. name만 쓰되, id/metadata 없으면 폴더일 가능성 있음.
          // 대부분 파일은 name만으로 remove 가능.
          all.push(`${prefix}/${f.name}`);
        }

        if (data.length < limit) break;
        offset += limit;
      }
      return all;
    }

    async function removeAll(prefix: string) {
      const paths = await listAll(prefix);
      if (paths.length === 0) return 0;

      // remove는 한번에 많이 보내면 실패할 수 있어서 100개씩 끊어줌
      let removed = 0;
      for (let i = 0; i < paths.length; i += 100) {
        const chunk = paths.slice(i, i + 100);
        const { error } = await admin.storage.from(bucket).remove(chunk);
        if (error) throw error;
        removed += chunk.length;
      }
      return removed;
    }

    const removedAi = await removeAll(`ai/${travel_id}`);
    const removedUser = await removeAll(`user/${travel_id}`);

    // 3) DB 삭제 (순서 중요: 자식 → 부모)
    // travel_days FK가 travels에 걸려있으면 먼저 지워야 함.
    // (CASCADE면 안 지워도 되지만, 안전하게 직접 지움)
    const { error: dayErr } = await admin.from("travel_days").delete().eq("travel_id", travel_id);
    if (dayErr) throw dayErr;

    const { error: regionErr } = await admin
      .from("domestic_travel_regions")
      .delete()
      .eq("travel_id", travel_id);
    if (regionErr) throw regionErr;

    const { error: travelDelErr } = await admin.from("travels").delete().eq("id", travel_id);
    if (travelDelErr) throw travelDelErr;

    return new Response(
      JSON.stringify({
        ok: true,
        deleted: true,
        travel_id,
        storage_removed: { ai: removedAi, user: removedUser },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
