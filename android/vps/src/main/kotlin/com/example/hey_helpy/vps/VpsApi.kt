package com.example.hey_helpy.vps

import com.example.hey_helpy.arcommon.Quat
import com.example.hey_helpy.arcommon.RigidPose
import com.example.hey_helpy.arcommon.SupabaseRest
import com.example.hey_helpy.arcommon.Vec3
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder

/**
 * Шаг 28: REST Supabase с JWT пользователя — всё под RLS (0025), без service-ключей.
 * Читает скан помещения и метки, ставит и удаляет метки.
 * Шаг 31: сами запросы — общий SupabaseRest (android/arcommon).
 */
class VpsApi(baseUrl: String, anonKey: String, jwt: String) {
    private val rest = SupabaseRest(baseUrl, anonKey, jwt)

    data class Site(val id: String, val name: String, val payload: String)

    data class Mark(val id: String, val assetId: String, val pose: RigidPose)

    suspend fun site(locationId: String): Site? {
        val rows = getArray(
            "vps_sites?select=id,name,anchor_payload&location_id=eq.${enc(locationId)}&limit=1",
        )
        if (rows.length() == 0) return null
        val o = rows.getJSONObject(0)
        return Site(o.getString("id"), o.optString("name"), o.getString("anchor_payload"))
    }

    suspend fun marks(siteId: String): List<Mark> {
        val rows = getArray(
            "vps_marks?select=id,asset_id,pos_x,pos_y,pos_z,rot_x,rot_y,rot_z,rot_w" +
                "&site_id=eq.${enc(siteId)}",
        )
        return (0 until rows.length()).map { parseMark(rows.getJSONObject(it)) }
    }

    /** Поставить (или переставить) метку оборудования в этом скане. */
    suspend fun saveMark(siteId: String, assetId: String, rel: RigidPose): Mark {
        val body = JSONObject()
            .put("site_id", siteId)
            .put("asset_id", assetId)
            .put("pos_x", rel.p.x).put("pos_y", rel.p.y).put("pos_z", rel.p.z)
            .put("rot_x", rel.q.x).put("rot_y", rel.q.y).put("rot_z", rel.q.z).put("rot_w", rel.q.w)
        val res = request(
            "POST",
            "vps_marks?on_conflict=site_id,asset_id",
            body.toString(),
            "resolution=merge-duplicates,return=representation",
        )
        return parseMark(JSONArray(res).getJSONObject(0))
    }

    suspend fun deleteMark(id: String) {
        request("DELETE", "vps_marks?id=eq.${enc(id)}", null, null)
    }

    private fun parseMark(o: JSONObject) = Mark(
        id = o.getString("id"),
        assetId = o.getString("asset_id"),
        pose = RigidPose(
            Vec3(o.getDouble("pos_x"), o.getDouble("pos_y"), o.getDouble("pos_z")),
            Quat(o.getDouble("rot_x"), o.getDouble("rot_y"), o.getDouble("rot_z"), o.getDouble("rot_w")),
        ),
    )

    private suspend fun getArray(path: String) = JSONArray(request("GET", path, null, null))

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")

    private suspend fun request(method: String, path: String, body: String?, prefer: String?): String =
        withContext(Dispatchers.IO) { rest.rest(method, path, body, prefer) }
}
