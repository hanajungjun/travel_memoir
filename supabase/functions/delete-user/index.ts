// supabase/functions/delete-user/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // =========================
  // 0️⃣ 유저 식별
  // =========================
  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );

  if (error || !user) {
    return new Response("Invalid user", { status: 401 });
  }

  const userId = user.id;

  try {
    // =========================
    // 1️⃣ Storage 삭제 (users/{userId} 전체)
    // =========================
    const bucket = supabaseAdmin.storage.from("travel_images");

    const files: string[] = [];

    async function walk(path: string) {
      const { data, error } = await bucket.list(path);
      if (error || !data) return;

      for (const item of data) {
        const fullPath = `${path}/${item.name}`;
        if (item.metadata) {
          // 파일
          files.push(fullPath);
        } else {
          // 폴더
          await walk(fullPath);
        }
      }
    }

    await walk(`users/${userId}`);

    if (files.length > 0) {
      await bucket.remove(files);
    }

    // =========================
    // 2️⃣ DB 삭제 (정확한 순서)
    // =========================

    // 여행 id 먼저 조회
    const { data: travels } = await supabaseAdmin
      .from("travels")
      .select("id")
      .eq("user_id", userId);

    const travelIds = travels?.map((t) => t.id) ?? [];

    if (travelIds.length > 0) {
      await supabaseAdmin
        .from("travel_days")
        .delete()
        .in("travel_id", travelIds);
    }

    await supabaseAdmin
      .from("domestic_travel_regions")
      .delete()
      .eq("user_id", userId);

    await supabaseAdmin
      .from("travels")
      .delete()
      .eq("user_id", userId);

    await supabaseAdmin
      .from("users")
      .delete()
      .eq("auth_uid", userId);

    // =========================
    // 3️⃣ Auth 계정 삭제 (마지막)
    // =========================
    await supabaseAdmin.auth.admin.deleteUser(userId);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500 },
    );
  }
});
