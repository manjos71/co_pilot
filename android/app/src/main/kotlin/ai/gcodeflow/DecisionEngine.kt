package ai.gcodeflow

enum class Verdict { ACCEPT, MAYBE, REJECT }

enum class SemaforoStatus {
    BAD,      // Ruim -> Vermelho
    REGULAR,  // Regular / Atenção -> Amarelo
    GOOD      // Bom -> Verde
}

data class Evaluation(
    val perKm: Double,
    val perHour: Double,
    val totalKm: Double,
    val totalMin: Int,
    val score: Int,
    val verdict: Verdict,
    val kmStatus: SemaforoStatus,
    val hourStatus: SemaforoStatus,
    val ratingStatus: SemaforoStatus,
    val overallStatus: SemaforoStatus,
)

object DecisionEngine {
    fun evaluate(offer: Offer, settings: Settings): Evaluation {
        val cfg = settings.getThresholdsFor(offer.source)

        val totalKm = (offer.pickupKm + offer.tripKm).coerceAtLeast(0.1)
        val totalMin = (offer.pickupMin + offer.tripMin).coerceAtLeast(1)

        val perKm = offer.price / totalKm
        val perHour = offer.price / (totalMin / 60.0)

        // 1. Semáforo $/Km
        val kmStatus = when {
            perKm < cfg.kmRuim -> SemaforoStatus.BAD
            perKm >= cfg.kmBom -> SemaforoStatus.GOOD
            else -> SemaforoStatus.REGULAR
        }

        // 2. Semáforo $/Hora
        val hourStatus = when {
            perHour < cfg.horaRuim -> SemaforoStatus.BAD
            perHour >= cfg.horaBom -> SemaforoStatus.GOOD
            else -> SemaforoStatus.REGULAR
        }

        // 3. Semáforo Nota do Passageiro
        val ratingStatus = if (offer.rating != null) {
            when {
                offer.rating < cfg.notaRuim -> SemaforoStatus.BAD
                offer.rating >= cfg.notaBom -> SemaforoStatus.GOOD
                else -> SemaforoStatus.REGULAR
            }
        } else {
            SemaforoStatus.REGULAR
        }

        // 4. Status Geral da Tarja (Semáforo Principal)
        // Se $/Km ou $/Hora ou a Nota estiverem em patamar RUIM, a tarja é VERMELHA.
        // Se $/Km e $/Hora forem BONS e a Nota não for RUIM, a tarja é VERDE.
        // Caso intermediário, a tarja é AMARELA.
        val overallStatus = when {
            kmStatus == SemaforoStatus.BAD || hourStatus == SemaforoStatus.BAD || ratingStatus == SemaforoStatus.BAD ->
                SemaforoStatus.BAD

            kmStatus == SemaforoStatus.GOOD && hourStatus == SemaforoStatus.GOOD ->
                SemaforoStatus.GOOD

            else ->
                SemaforoStatus.REGULAR
        }

        val verdict = when (overallStatus) {
            SemaforoStatus.GOOD -> Verdict.ACCEPT
            SemaforoStatus.REGULAR -> Verdict.MAYBE
            SemaforoStatus.BAD -> Verdict.REJECT
        }

        val sKm = (perKm / cfg.kmBom * 60.0).coerceIn(0.0, 100.0)
        val sHour = (perHour / cfg.horaBom * 60.0).coerceIn(0.0, 100.0)
        val score = (0.5 * sKm + 0.5 * sHour).toInt().coerceIn(0, 100)

        return Evaluation(
            perKm = perKm,
            perHour = perHour,
            totalKm = totalKm,
            totalMin = totalMin,
            score = score,
            verdict = verdict,
            kmStatus = kmStatus,
            hourStatus = hourStatus,
            ratingStatus = ratingStatus,
            overallStatus = overallStatus,
        )
    }
}
