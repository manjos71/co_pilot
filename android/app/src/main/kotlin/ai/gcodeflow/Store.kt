package ai.gcodeflow

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class SemaforoThresholds(
    val kmRuim: Double = 1.90,
    val kmBom: Double = 2.00,
    val horaRuim: Double = 43.0,
    val horaBom: Double = 48.0,
    val notaRuim: Double = 4.80,
    val notaBom: Double = 4.90,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "kmRuim" to kmRuim,
        "kmBom" to kmBom,
        "horaRuim" to horaRuim,
        "horaBom" to horaBom,
        "notaRuim" to notaRuim,
        "notaBom" to notaBom,
    )

    fun toJson(): JSONObject = JSONObject(toMap())

    companion object {
        fun fromMap(m: Map<*, *>?): SemaforoThresholds {
            if (m == null) return SemaforoThresholds()
            return SemaforoThresholds(
                kmRuim = (m["kmRuim"] as? Number)?.toDouble() ?: 1.90,
                kmBom = (m["kmBom"] as? Number)?.toDouble() ?: 2.00,
                horaRuim = (m["horaRuim"] as? Number)?.toDouble() ?: 43.0,
                horaBom = (m["horaBom"] as? Number)?.toDouble() ?: 48.0,
                notaRuim = (m["notaRuim"] as? Number)?.toDouble() ?: 4.80,
                notaBom = (m["notaBom"] as? Number)?.toDouble() ?: 4.90,
            )
        }

        fun fromJson(o: JSONObject?): SemaforoThresholds {
            if (o == null) return SemaforoThresholds()
            return SemaforoThresholds(
                kmRuim = o.optDouble("kmRuim", 1.90),
                kmBom = o.optDouble("kmBom", 2.00),
                horaRuim = o.optDouble("horaRuim", 43.0),
                horaBom = o.optDouble("horaBom", 48.0),
                notaRuim = o.optDouble("notaRuim", 4.80),
                notaBom = o.optDouble("notaBom", 4.90),
            )
        }
    }
}

data class Settings(
    val overlayEnabled: Boolean = true,
    val global: SemaforoThresholds = SemaforoThresholds(),
    val uber: SemaforoThresholds? = null,
    val app99: SemaforoThresholds? = null,
    val inDrive: SemaforoThresholds? = null,
    val uberEnabled: Boolean = true,
    val app99Enabled: Boolean = true,
    val inDriveEnabled: Boolean = true,
) {
    fun getThresholdsFor(source: String): SemaforoThresholds {
        return when (source.lowercase().trim()) {
            "uber" -> if (uberEnabled) (uber ?: global) else global
            "99" -> if (app99Enabled) (app99 ?: global) else global
            "indrive" -> if (inDriveEnabled) (inDrive ?: global) else global
            else -> global
        }
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "overlayEnabled" to overlayEnabled,
        "global" to global.toMap(),
        "uber" to uber?.toMap(),
        "app99" to app99?.toMap(),
        "inDrive" to inDrive?.toMap(),
        "uberEnabled" to uberEnabled,
        "app99Enabled" to app99Enabled,
        "inDriveEnabled" to inDriveEnabled,
        // Retrocompatibilidade
        "minPerKm" to global.kmBom,
        "minPerHour" to global.horaBom,
        "mode" to "semaforo",
    )

    fun toJson(): String {
        val o = JSONObject()
            .put("overlayEnabled", overlayEnabled)
            .put("global", global.toJson())
            .put("uber", uber?.toJson() ?: JSONObject.NULL)
            .put("app99", app99?.toJson() ?: JSONObject.NULL)
            .put("inDrive", inDrive?.toJson() ?: JSONObject.NULL)
            .put("uberEnabled", uberEnabled)
            .put("app99Enabled", app99Enabled)
            .put("inDriveEnabled", inDriveEnabled)
        return o.toString()
    }

    companion object {
        fun fromMap(m: Map<*, *>?): Settings {
            if (m == null) return Settings()
            return Settings(
                overlayEnabled = (m["overlayEnabled"] as? Boolean) ?: true,
                global = SemaforoThresholds.fromMap(m["global"] as? Map<*, *>),
                uber = (m["uber"] as? Map<*, *>)?.let { SemaforoThresholds.fromMap(it) },
                app99 = (m["app99"] as? Map<*, *>)?.let { SemaforoThresholds.fromMap(it) },
                inDrive = (m["inDrive"] as? Map<*, *>)?.let { SemaforoThresholds.fromMap(it) },
                uberEnabled = (m["uberEnabled"] as? Boolean) ?: true,
                app99Enabled = (m["app99Enabled"] as? Boolean) ?: true,
                inDriveEnabled = (m["inDriveEnabled"] as? Boolean) ?: true,
            )
        }

        fun fromJson(jsonStr: String?): Settings {
            if (jsonStr.isNullOrEmpty()) return Settings()
            return try {
                val o = JSONObject(jsonStr)
                Settings(
                    overlayEnabled = o.optBoolean("overlayEnabled", true),
                    global = SemaforoThresholds.fromJson(o.optJSONObject("global")),
                    uber = if (o.isNull("uber")) null else SemaforoThresholds.fromJson(o.optJSONObject("uber")),
                    app99 = if (o.isNull("app99")) null else SemaforoThresholds.fromJson(o.optJSONObject("app99")),
                    inDrive = if (o.isNull("inDrive")) null else SemaforoThresholds.fromJson(o.optJSONObject("inDrive")),
                    uberEnabled = o.optBoolean("uberEnabled", true),
                    app99Enabled = o.optBoolean("app99Enabled", true),
                    inDriveEnabled = o.optBoolean("inDriveEnabled", true),
                )
            } catch (_: Exception) {
                Settings()
            }
        }
    }
}

/** Armazenamento local (SharedPreferences). Nada sai do aparelho. */
class Store(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("copilot", Context.MODE_PRIVATE)

    fun settings(): Settings {
        val json = prefs.getString("settings_v2", null)
        if (json != null) {
            return Settings.fromJson(json)
        }
        // Migração suave das configurações antigas, se houverem
        val legacyKm = prefs.getFloat("minPerKm", -1f)
        val legacyHour = prefs.getFloat("minPerHour", -1f)
        val overlay = prefs.getBoolean("overlayEnabled", true)
        if (legacyKm > 0 || legacyHour > 0) {
            val defaults = SemaforoThresholds(
                kmRuim = if (legacyKm > 0) (legacyKm * 0.9).coerceAtLeast(1.0) else 1.90,
                kmBom = if (legacyKm > 0) legacyKm.toDouble() else 2.00,
                horaRuim = if (legacyHour > 0) (legacyHour * 0.9).coerceAtLeast(20.0) else 43.0,
                horaBom = if (legacyHour > 0) legacyHour.toDouble() else 48.0,
            )
            val s = Settings(overlayEnabled = overlay, global = defaults)
            save(s)
            return s
        }
        return Settings()
    }

    fun save(s: Settings) {
        prefs.edit()
            .putString("settings_v2", s.toJson())
            // Mantém chaves antigas sincronizadas por segurança
            .putFloat("minPerKm", s.global.kmBom.toFloat())
            .putFloat("minPerHour", s.global.horaBom.toFloat())
            .putBoolean("overlayEnabled", s.overlayEnabled)
            .apply()
    }

    @Synchronized
    fun addHistory(offer: Offer, e: Evaluation) {
        if (offer.price < 4.0 || e.totalKm <= 0.1 || e.totalMin <= 0) return // Ignora ofertas com preço zero ou inválidas
        val arr = JSONArray(prefs.getString("history", "[]"))

        // Evita gravar duplicatas da mesma oferta no histórico se ela reapareceu nos últimos 30 segundos
        if (arr.length() > 0) {
            val last = arr.getJSONObject(0)
            val lastTime = last.optLong("time", 0L)
            val lastSource = last.optString("source", "")
            val lastPrice = last.optDouble("price", 0.0)
            val lastKm = last.optDouble("totalKm", 0.0)
            if (System.currentTimeMillis() - lastTime < 30_000L &&
                lastSource.equals(offer.source, ignoreCase = true) &&
                kotlin.math.abs(lastPrice - offer.price) < 0.1 &&
                kotlin.math.abs(lastKm - e.totalKm) < 0.1
            ) {
                return
            }
        }

        val item = JSONObject()
            .put("time", System.currentTimeMillis())
            .put("source", offer.source)
            .put("price", offer.price)
            .put("pickupKm", offer.pickupKm)
            .put("pickupMin", offer.pickupMin)
            .put("tripKm", offer.tripKm)
            .put("tripMin", offer.tripMin)
            .put("totalKm", e.totalKm)
            .put("totalMin", e.totalMin)
            .put("rating", offer.rating ?: JSONObject.NULL)
            .put("perKm", e.perKm)
            .put("perHour", e.perHour)
            .put("score", e.score)
            .put("verdict", e.verdict.name)
            .put("overallStatus", e.overallStatus.name)
            .put("kmStatus", e.kmStatus.name)
            .put("hourStatus", e.hourStatus.name)
            .put("ratingStatus", e.ratingStatus.name)

        // Mais recente primeiro, limitado a 200 itens.
        val out = JSONArray().put(item)
        for (i in 0 until minOf(arr.length(), MAX_HISTORY - 1)) out.put(arr.get(i))
        prefs.edit().putString("history", out.toString()).apply()
    }

    @Synchronized
    fun history(): List<Map<String, Any?>> {
        val arr = JSONArray(prefs.getString("history", "[]"))
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            mapOf(
                "time" to o.getLong("time"),
                "source" to o.getString("source"),
                "price" to o.getDouble("price"),
                "pickupKm" to o.getDouble("pickupKm"),
                "pickupMin" to o.getInt("pickupMin"),
                "tripKm" to o.getDouble("tripKm"),
                "tripMin" to o.getInt("tripMin"),
                "totalKm" to o.optDouble("totalKm", o.getDouble("pickupKm") + o.getDouble("tripKm")),
                "totalMin" to o.optInt("totalMin", o.getInt("pickupMin") + o.getInt("tripMin")),
                "rating" to if (o.isNull("rating")) null else o.getDouble("rating"),
                "perKm" to o.getDouble("perKm"),
                "perHour" to o.getDouble("perHour"),
                "score" to o.optInt("score", 50),
                "verdict" to o.optString("verdict", "MAYBE"),
                "overallStatus" to o.optString("overallStatus", "REGULAR"),
                "kmStatus" to o.optString("kmStatus", "REGULAR"),
                "hourStatus" to o.optString("hourStatus", "REGULAR"),
                "ratingStatus" to o.optString("ratingStatus", "REGULAR"),
            )
        }
    }

    fun clearHistory() {
        prefs.edit().remove("history").apply()
    }

    private companion object {
        const val MAX_HISTORY = 200
    }
}
