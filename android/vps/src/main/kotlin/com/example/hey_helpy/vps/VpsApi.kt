package com.example.hey_helpy.vps

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Шаг 28: REST Supabase с JWT пользователя — всё под RLS (0025), без service-ключей.
 * Читает скан помещения и метки, ставит и удаляет метки.
 */
class VpsApi(
    private val baseUrl: String,
    private val anonKey: String,
    private val jwt: String,
) {
    class HttpError(val code: Int) : IOException("http $code")

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
        withContext(Dispatchers.IO) {
            val c = URL("${baseUrl.trimEnd('/')}/rest/v1/$path").openConnection() as HttpURLConnection
            try {
                c.requestMethod = method
                c.connectTimeout = 15_000
                c.readTimeout = 25_000
                c.setRequestProperty("apikey", anonKey)
                c.setRequestProperty("Authorization", "Bearer $jwt")
                c.setRequestProperty("Accept", "application/json")
                if (prefer != null) c.setRequestProperty("Prefer", prefer)
                if (body != null) {
                    c.doOutput = true
                    c.setRequestProperty("Content-Type", "application/json")
                    c.outputStream.use { it.write(body.toByteArray()) }
                }
                val code = c.responseCode
                if (code !in 200..299) throw HttpError(code)
                c.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }.ifBlank { "[]" }
            } finally {
                c.disconnect()
            }
        }
}
