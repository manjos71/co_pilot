package ai.gcodeflow

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Overlay flutuante ("Tarja / Semáforo") exibido no topo da tela sobre os apps de corrida.
 * Usa TYPE_ACCESSIBILITY_OVERLAY (contexto do AccessibilityService).
 * Baseado no layout da tarja do Zeca com suporte ao Semáforo (Vermelho, Amarelo, Verde).
 */
class OverlayController(private val context: Context) {
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private val hideRunnable = Runnable { hide() }
    private var dismissCallback: (() -> Unit)? = null

    fun isShowing(): Boolean = view != null

    fun show(offer: Offer, e: Evaluation, onDismiss: (() -> Unit)? = null) {
        handler.post {
            dismissCallback = onDismiss
            hideNow()

            // Cor de fundo dinâmica do Semáforo (Vermelho / Amarelo / Verde)
            val bgColor = when (e.overallStatus) {
                SemaforoStatus.BAD -> Color.parseColor("#991B1B")     // Vermelho intenso e sóbrio (como na imagem 3)
                SemaforoStatus.REGULAR -> Color.parseColor("#B45309") // Amarelo/Laranja queimado (atenção)
                SemaforoStatus.GOOD -> Color.parseColor("#15803D")    // Verde floresta (bom)
            }

            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14), dp(10), dp(14), dp(10))
                background = GradientDrawable().apply {
                    setColor(bgColor)
                    cornerRadius = dp(14).toFloat()
                    setStroke(dp(1), Color.parseColor("#44FFFFFF"))
                }
                elevation = dp(10).toFloat()
                // Garante que o leitor de acessibilidade NUNCA inspecione a própria tarja (evita loop infinito / tarja biruta)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
                // Ao tocar na tarja, fecha imediatamente e notifica callback
                setOnClickListener {
                    dismissCallback?.invoke()
                    hideNow()
                }
            }

            // --- 1. Linha Superior (Header): [Logo] [Distância - Tempo] [Nota ★] ---
            val headerRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    bottomMargin = dp(8)
                }
            }

            // Badge do Aplicativo (inDrive, 99, Uber)
            val appBadge = createAppBadge(offer.source)
            headerRow.addView(appBadge)

            // Distância Total e Tempo Estimado: "10.2km - 23min"
            val infoText = TextView(context).apply {
                val kmStr = if (e.totalKm >= 10) "%.1f".format(e.totalKm) else "%.1f".format(e.totalKm)
                text = "${kmStr}km - ${e.totalMin}min"
                setTextColor(Color.WHITE)
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f,
                ).apply {
                    marginStart = dp(8)
                }
            }
            headerRow.addView(infoText)

            // Badge da Nota do Passageiro (se detectada)
            if (offer.rating != null) {
                val ratingBadge = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(8), dp(3), dp(8), dp(3))
                    background = GradientDrawable().apply {
                        val ratingColor = when (e.ratingStatus) {
                            SemaforoStatus.BAD -> Color.parseColor("#7F1D1D")
                            SemaforoStatus.REGULAR -> Color.parseColor("#78350F")
                            SemaforoStatus.GOOD -> Color.parseColor("#14532D")
                        }
                        setColor(ratingColor)
                        cornerRadius = dp(8).toFloat()
                        setStroke(dp(1), Color.parseColor("#55FFFFFF"))
                    }
                }
                val ratingText = TextView(context).apply {
                    text = "★ ${"%.1f".format(offer.rating)}"
                    setTextColor(Color.WHITE)
                    textSize = 13f
                    typeface = Typeface.DEFAULT_BOLD
                }
                ratingBadge.addView(ratingText)
                headerRow.addView(ratingBadge)
            }

            card.addView(headerRow)

            // --- 2. Linha Inferior: Caixas de Métricas lado a lado ($/Km e $/Hora) ---
            val metricsRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            }

            // Coluna 1: $/Km
            val kmBox = createMetricBox(
                label = "$/Km",
                value = "%.2f".format(e.perKm).replace(',', '.'),
                weight = 1f,
                marginEndDp = 6,
            )
            metricsRow.addView(kmBox)

            // Coluna 2: $/Hora
            val hourBox = createMetricBox(
                label = "$/Hora",
                value = "%.2f".format(e.perHour).replace(',', '.'),
                weight = 1f,
                marginStartDp = 6,
            )
            metricsRow.addView(hourBox)

            card.addView(metricsRow)

            // Configuração da janela do Overlay
            val displayMetrics = context.resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val bannerWidth = (screenWidth - dp(24)).coerceAtLeast(dp(280))

            val params = WindowManager.LayoutParams(
                bannerWidth,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dp(28) // Posicionamento limpo no topo
            }

            try {
                wm.addView(card, params)
                view = card
                handler.postDelayed(hideRunnable, DISPLAY_MS)
                android.util.Log.i("CoPilot", "Tarja flutuante exibida com sucesso via TYPE_ACCESSIBILITY_OVERLAY!")
            } catch (e1: Exception) {
                android.util.Log.w("CoPilot", "Falha com TYPE_ACCESSIBILITY_OVERLAY: ${e1.message}, tentando TYPE_APPLICATION_OVERLAY...")
                try {
                    params.type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    wm.addView(card, params)
                    view = card
                    handler.postDelayed(hideRunnable, DISPLAY_MS)
                    android.util.Log.i("CoPilot", "Tarja flutuante exibida com sucesso via TYPE_APPLICATION_OVERLAY!")
                } catch (e2: Exception) {
                    android.util.Log.e("CoPilot", "Falha fatal ao exibir tarja: ${e2.message}", e2)
                    view = null
                }
            }
        }
    }

    fun hide() {
        handler.post { hideNow() }
    }

    private fun hideNow() {
        handler.removeCallbacks(hideRunnable)
        view?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {
            }
        }
        view = null
    }

    /**
     * Cria a caixa com contorno branco e valor em destaque (como na imagem 3).
     */
    private fun createMetricBox(
        label: String,
        value: String,
        weight: Float,
        marginStartDp: Int = 0,
        marginEndDp: Int = 0,
    ): LinearLayout {
        val col = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, weight).apply {
                marginStart = dp(marginStartDp)
                marginEnd = dp(marginEndDp)
            }
        }

        // Rótulo: "$/Km" ou "$/Hora"
        val labelTv = TextView(context).apply {
            text = label
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = dp(3)
            }
        }
        col.addView(labelTv)

        // Caixa retangular arredondada com borda branca
        val box = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(6), dp(8), dp(6))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1FFFFFFF"))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1.8f), Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        // Valor numérico grande em negrito: "1.67" ou "44.35"
        val valueTv = TextView(context).apply {
            text = value
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        box.addView(valueTv)
        col.addView(box)

        return col
    }

    /**
     * Cria o ícone/badge do app (inDrive, 99 ou Uber).
     */
    private fun createAppBadge(source: String): View {
        return TextView(context).apply {
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(dp(26), dp(26))
            when (source.lowercase()) {
                "indrive" -> {
                    text = "D"
                    textSize = 15f
                    setTextColor(Color.parseColor("#2E6800"))
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#76BC21"))
                        cornerRadius = dp(6).toFloat()
                    }
                }
                "99" -> {
                    text = "99"
                    textSize = 12f
                    setTextColor(Color.parseColor("#801500"))
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#FFC800"))
                        cornerRadius = dp(6).toFloat()
                    }
                }
                "uber" -> {
                    text = "U"
                    textSize = 14f
                    setTextColor(Color.WHITE)
                    background = GradientDrawable().apply {
                        setColor(Color.BLACK)
                        cornerRadius = dp(6).toFloat()
                        setStroke(dp(1), Color.WHITE)
                    }
                }
                else -> {
                    text = source.take(1).uppercase()
                    textSize = 13f
                    setTextColor(Color.WHITE)
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#333333"))
                        cornerRadius = dp(6).toFloat()
                    }
                }
            }
        }
    }

    private fun dp(v: Float): Int = (v * context.resources.displayMetrics.density).toInt()
    private fun dp(v: Int): Int = (v * context.resources.displayMetrics.density).toInt()

    private companion object {
        const val DISPLAY_MS = 10_000L
    }
}
