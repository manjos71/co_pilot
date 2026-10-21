package ai.gcodeflow

import kotlin.math.abs
import kotlin.math.roundToInt

data class Offer(
    val source: String,
    val price: Double,
    val pickupKm: Double,
    val pickupMin: Int,
    val tripKm: Double,
    val tripMin: Int,
    val rating: Double?,
) {
    /** Assinatura usada para ignorar a mesma oferta lida repetidas vezes seguidas. */
    fun signature(): String = "$source|$price|$pickupKm|$pickupMin|$tripKm|$tripMin|${rating ?: 0.0}"
}

/**
 * Parser de texto especializado para extração de ofertas nos apps:
 * - inDrive (detalhes da corrida selecionada e pins do mapa)
 * - Uber Driver
 * - 99 Motorista
 */
object OfferParser {
    // 1. Padrões de Preço:
    // Captura R$ seguido do valor, aceitando separadores como espaço ou pipe entre o símbolo e o número
    // Ex: "R$ 15,20", "R$ | 15,20", "R$ 10", "R$ 28", "R$10.50"
    private val rawPricePattern = Regex(
        """R\$\s*(?:[-–•·|/\\,\s]*)\s*(\d{1,3}(?:\.\d{3})*|\d+)(?:[.,](\d{1,2}))?(\s*/\s*km|\s*por\s*km)?""",
        RegexOption.IGNORE_CASE,
    )

    // Preço específico no inDrive quando a corrida é selecionada (botão "Aceitar por R$ 28")
    private val inDriveSelectedPriceRe = Regex(
        """aceitar\s+por\s*[-–•·|/\\,\s]*\s*R\$\s*(\d{1,3}(?:\.\d{3})*|\d+)(?:[.,](\d{1,2}))?""",
        RegexOption.IGNORE_CASE,
    )

    // Tarifa por km exibida no card do inDrive: "R$ 1,3/km" ou "R$ 2.8 por km"
    private val inDriveRateRe = Regex(
        """R\$\s*(\d+(?:[.,]\d+)?)\s*(?:/|por)\s*km""",
        RegexOption.IGNORE_CASE,
    )

    // 2. Distância e Tempo Combinados (dual-order, baseado na engenharia reversa do Zeca):
    // Formato A: Minutos primeiro, depois km (ex: inDrive pins "17 min | 4,9 km", "17 min | A | 4,9 km", "19 min | B | 17,4 km")
    private val minThenKmRe = Regex(
        """\b(\d+)\s*(?:min|minutos?)\b[^\d\n]{1,30}~?\s*(\d+(?:[.,]\d+)?)\s*km\b""",
        RegexOption.IGNORE_CASE,
    )

    // Formato B: Km primeiro, depois minutos (ex: "2,1 km • 5 min", "17,4 km | B | 19 min", "4,9 km | A | 17 min")
    private val kmThenMinRe = Regex(
        """~?\s*(\d+(?:[.,]\d+)?)\s*km\b[^\d\n]{1,30}\b(\d+)\s*(?:min|minutos?)\b""",
        RegexOption.IGNORE_CASE,
    )

    // Padrões avulsos para captura de distâncias e minutos
    private val kmRe = Regex("""~?\s*(\d+(?:[.,]\d+)?)\s*km\b""", RegexOption.IGNORE_CASE)
    private val minRe = Regex("""\b(\d+)\s*(?:min|minutos?)\b""", RegexOption.IGNORE_CASE)

    // Formato de espera do passageiro no inDrive (ex: "★ 4.76 (42) | 2 min." ou "5.0 (36) | 5 min.")
    // Deve ser desconsiderado do cálculo de duração da viagem para não distorcer o tempo real.
    // NUNCA deve casar se houver distância associada (ex: "1 min (0.1 km)")
    private val passengerWaitTimerRe = Regex(
        """(?:[★⭐]\s*[345][.,]\d{1,2}(?:\s*[-–•·|/\\,\s]*\(\d+\))?|[345][.,]\d{1,2}\s*\(\d+\))\s*[-–•·|/\\,\s]{1,15}(\d{1,2})\s*min\.?(?!\s*[\(\[~]?\s*\d)""",
        RegexOption.IGNORE_CASE,
    )

    // Formatos de avaliação do passageiro: "4.76 (42)", "★ 4.95", "4.95 ★", "4.95"
    private val ratingWithCountRe = Regex("""\b([345][.,]\d{1,2})\s*\(\d+\)""")
    private val ratingWithStarRe = Regex("""(?:★|⭐)\s*([345][.,]\d{1,2})|([345][.,]\d{1,2})\s*(?:★|⭐)""")

    fun parse(texts: List<String>, source: String): Offer? {
        if (texts.isEmpty()) return null
        val joined = texts.joinToString(" | ")

        // 1. REGRA ESPECÍFICA DO INDRIVE:
        // Na lista geral do inDrive aparecem dezenas de corridas juntas.
        // Só devemos analisar e exibir a tarja quando o motorista TOCAR / SELECIONAR uma corrida
        // (a tela de detalhes da corrida selecionada SEMPRE tem o botão "Aceitar por R$ XX").
        if (source.equals("inDrive", ignoreCase = true)) {
            val isSelectedRide = joined.contains("Aceitar por", ignoreCase = true)
            if (!isSelectedRide) {
                // Está na lista geral de ofertas: não exibe a tarja
                return null
            }
        }

        // 2. Extração do Preço da Corrida
        val price = parsePrice(joined, source) ?: return null
        if (price < 4.0) return null

        // 3. Extração da Nota do Passageiro
        val rating = parseRating(joined)

        // 4. Extração de Distância e Tempo (considerando pinos, trechos e fallback do inDrive)
        val dt = parseDistanceAndTime(joined, source, price) ?: return null
        val totalKm = dt.pickupKm + dt.tripKm
        val totalMin = dt.pickupMin + dt.tripMin
        if (totalKm <= 0.1 || totalMin <= 0) return null

        return Offer(
            source = source,
            price = price,
            pickupKm = dt.pickupKm,
            pickupMin = dt.pickupMin,
            tripKm = dt.tripKm,
            tripMin = dt.tripMin,
            rating = rating,
        )
    }

    private fun parsePrice(text: String, source: String): Double? {
        // Se for inDrive, exige o preço do botão de aceitação da corrida selecionada ("Aceitar por R$ 28")
        if (source.equals("inDrive", ignoreCase = true)) {
            inDriveSelectedPriceRe.find(text)?.let { m ->
                val intPart = m.groupValues[1].replace(".", "")
                val cents = m.groupValues[2].padEnd(2, '0').ifEmpty { "00" }
                val p = "$intPart.$cents".toDoubleOrNull()
                if (p != null && p >= 4.0) return p
            }
            // No inDrive, se não tiver o botão "Aceitar por R$ ...", descarta para não pegar preços soltos da lista
            return null
        }

        // Busca todos os R$ válidos que NÃO sejam "/km" ou "por km"
        for (m in rawPricePattern.findAll(text)) {
            val fullMatch = m.value.lowercase()
            // Ignora se for valor por km (ex: "R$ 1,3/km")
            if (fullMatch.contains("/km") || fullMatch.contains("por km")) {
                continue
            }
            val intPart = m.groupValues[1].replace(".", "")
            val cents = m.groupValues[2].padEnd(2, '0').ifEmpty { "00" }
            val price = "$intPart.$cents".toDoubleOrNull()
            if (price != null && price >= 4.0) {
                return price
            }
        }

        return null
    }

    private fun parseDistanceAndTime(text: String, source: String, price: Double): DistanceTimeResult? {
        // Mascara o timer de espera do passageiro EXCLUSIVAMENTE no inDrive (ex: "★ 4.76 (42) | 2 min.")
        // para não poluir o tempo de viagem, preservando tempos legítimos de embarque da Uber e 99
        val sanitizedText = if (source.equals("inDrive", ignoreCase = true)) {
            passengerWaitTimerRe.replace(text) { m ->
                val full = m.value
                val timerPart = m.groupValues[1]
                full.replace("$timerPart min", "passenger_wait")
            }
        } else {
            text
        }

        val legs = ArrayList<Pair<Double, Int>>()

        // Passo 1: Busca trechos combinados com "min" seguido de "km" (inDrive pins, Uber, 99)
        // ex: "17 min | 4,9 km", "17 min | A | 4,9 km", "19 min | B | 17,4 km", "31 min | 17,4 km"
        for (m in minThenKmRe.findAll(sanitizedText)) {
            val minVal = m.groupValues[1].toIntOrNull() ?: continue
            val kmVal = toDouble(m.groupValues[2]) ?: continue
            legs.add(Pair(kmVal, minVal))
        }

        // Passo 2: Se não encontrou formato min-km suficiente, busca formato km-min
        // ex: "2,1 km • 5 min", "17,4 km | B | 19 min"
        if (legs.size < 2) {
            val kmFirstLegs = ArrayList<Pair<Double, Int>>()
            for (m in kmThenMinRe.findAll(sanitizedText)) {
                val kmVal = toDouble(m.groupValues[1]) ?: continue
                val minVal = m.groupValues[2].toIntOrNull() ?: continue
                kmFirstLegs.add(Pair(kmVal, minVal))
            }
            if (kmFirstLegs.size > legs.size) {
                legs.clear()
                legs.addAll(kmFirstLegs)
            }
        }

        // Filtra trechos idênticos duplicados pela árvore de acessibilidade
        val distinctLegs = ArrayList<Pair<Double, Int>>()
        for (leg in legs) {
            if (distinctLegs.none { abs(it.first - leg.first) < 0.05 && it.second == leg.second }) {
                distinctLegs.add(leg)
            }
        }

        // Caso de 2 ou mais trechos combinados encontrados diretamente (Embarque + Viagem):
        if (distinctLegs.size >= 2) {
            val pKm = distinctLegs[0].first
            val pMin = distinctLegs[0].second
            val tKm = distinctLegs[1].first
            val tMin = distinctLegs[1].second
            return DistanceTimeResult(pKm, pMin, tKm, tMin)
        }

        // Passo 3: Extrai todas as distâncias e tempos reais da tela (evitando que pinos com textos intermediários se percam)
        val validKms = ArrayList<Double>()
        for (m in kmRe.findAll(sanitizedText)) {
            val start = m.range.first
            val prefix = sanitizedText.substring(maxOf(0, start - 6), start).lowercase()
            if (prefix.contains("/") || prefix.contains("por")) {
                continue
            }
            toDouble(m.groupValues[1])?.let { validKms.add(it) }
        }

        val validMins = minRe.findAll(sanitizedText).mapNotNull { it.groupValues[1].toIntOrNull() }.toList()

        // Quando há pelo menos 2 distâncias e 2 minutagens na tela:
        if (validKms.size >= 2 && validMins.size >= 2) {
            val distinctKms = ArrayList<Double>()
            for (k in validKms) {
                if (distinctKms.none { abs(it - k) < 0.05 }) {
                    distinctKms.add(k)
                }
            }
            val distinctMins = ArrayList<Int>()
            for (m in validMins) {
                if (!distinctMins.contains(m)) {
                    distinctMins.add(m)
                }
            }

            val pKm = distinctKms[0]
            val tKm = if (distinctKms.size >= 2) distinctKms[1] else validKms[1]
            val pMin = validMins[0]
            val tMin = if (distinctMins.size >= 2 && validMins.size > 1 && validMins[1] == validMins[0]) {
                distinctMins[1]
            } else if (validMins.size >= 2) {
                validMins[1]
            } else {
                validMins[0]
            }
            return DistanceTimeResult(pKm, pMin, tKm, tMin)
        }

        // Caso de 1 trecho único identificado em apps fora o inDrive (Uber radar / viagem direta):
        if (legs.size == 1 && !source.equals("inDrive", ignoreCase = true)) {
            return DistanceTimeResult(0.0, 0, legs[0].first, legs[0].second)
        }

        if (validKms.size == 1 && validMins.size == 1 && !source.equals("inDrive", ignoreCase = true)) {
            return DistanceTimeResult(0.0, 0, validKms[0], validMins[0])
        }

        // Passo 4: Fallback exclusivo do inDrive quando os pinos do mapa NÃO são emitidos na árvore de acessibilidade
        if (source.equals("inDrive", ignoreCase = true)) {
            val rateMatch = inDriveRateRe.find(sanitizedText)
            if (rateMatch != null && price >= 4.0) {
                val rate = toDouble(rateMatch.groupValues[1]) ?: 0.0
                if (rate > 0.0) {
                    val rawTotalKm = price / rate
                    val totalKm = ((rawTotalKm * 2.0).roundToInt() / 2.0).coerceAtLeast(0.5)
                    val pickupKm = if (validKms.isNotEmpty()) validKms[0] else 0.0
                    val tripKm = (totalKm - pickupKm).coerceAtLeast(0.1)

                    // Se tempos reais foram lidos da tela, usa a soma real em vez de estimar:
                    val totalMin: Int
                    val pickupMin: Int
                    val tripMin: Int
                    if (validMins.isNotEmpty()) {
                        totalMin = validMins.sum()
                        pickupMin = if (validMins.size >= 2) validMins[0] else (totalMin / 2)
                        tripMin = (totalMin - pickupMin).coerceAtLeast(1)
                    } else {
                        totalMin = (totalKm * 4.0).roundToInt().coerceAtLeast(1)
                        pickupMin = if (pickupKm > 0) (pickupKm * 4.0).roundToInt().coerceAtLeast(1) else (totalMin / 2)
                        tripMin = (totalMin - pickupMin).coerceAtLeast(1)
                    }

                    return DistanceTimeResult(pickupKm, pickupMin, tripKm, tripMin)
                }
            }
        }

        if (validKms.isNotEmpty() && validMins.isNotEmpty()) {
            val pKm = if (validKms.size >= 2) validKms[0] else 0.0
            val tKm = if (validKms.size >= 2) validKms[1] else validKms[0]
            val pMin = if (validMins.size >= 2) validMins[0] else 0
            val tMin = if (validMins.size >= 2) validMins[1] else validMins[0]
            return DistanceTimeResult(pKm, pMin, tKm, tMin)
        }

        return null
    }

    private fun parseRating(text: String): Double? {
        // 1. "4.76 (42)" ou "5.0 (36)" comum no inDrive
        ratingWithCountRe.find(text)?.let { m ->
            toDouble(m.groupValues[1])?.takeIf { it in 3.0..5.0 }?.let { return it }
        }

        // 2. "★ 4.95" ou "4.95 ★" comum na Uber e 99
        ratingWithStarRe.find(text)?.let { m ->
            val v1 = m.groupValues[1]
            val v2 = m.groupValues[2]
            val str = if (v1.isNotEmpty()) v1 else v2
            toDouble(str)?.takeIf { it in 3.0..5.0 }?.let { return it }
        }

        return null
    }

    private fun toDouble(s: String): Double? = s.replace(',', '.').toDoubleOrNull()

    private data class DistanceTimeResult(
        val pickupKm: Double,
        val pickupMin: Int,
        val tripKm: Double,
        val tripMin: Int,
    )
}
