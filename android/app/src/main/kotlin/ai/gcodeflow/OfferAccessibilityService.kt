package ai.gcodeflow

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Lê os textos visíveis dos apps de corrida (Uber, 99, inDrive), extrai a oferta,
 * avalia com o Semáforo configurado e exibe a tarja de recomendação.
 * Não toca na tela nem aceita corridas automaticamente.
 */
class OfferAccessibilityService : AccessibilityService() {
    private lateinit var store: Store
    private lateinit var overlay: OverlayController

    private var lastScanAt = 0L
    private var lastSignature: String? = null
    private var lastSignatureAt = 0L
    private var dismissedSignature: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = Store(this)
        overlay = OverlayController(this)
        instance = this

        // Configuração dinâmica para habilitar leitura de janelas interativas (popups, diálogos do Uber e 99)
        try {
            val info = serviceInfo ?: AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.flags = info.flags or
                    AccessibilityServiceInfo.DEFAULT or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            info.notificationTimeout = 100
            serviceInfo = info
            android.util.Log.i("CoPilot", "Serviço de Acessibilidade do Co-Pilot conectado com sucesso!")
        } catch (_: Exception) {}
    }

    fun showTestOverlay(offer: Offer, e: Evaluation) {
        if (::overlay.isInitialized) {
            overlay.show(offer, e)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: ""
        // Ignora IMEDIATAMENTE eventos do nosso próprio aplicativo ou da nossa tarja (evita loop infinito / biruta)
        if (pkg == packageName || pkg == "ai.gcodeflow") return

        val now = System.currentTimeMillis()
        if (now - lastScanAt < SCAN_INTERVAL_MS) return

        val source = resolveSource(pkg) ?: return

        val texts = ArrayList<String>(128)
        val collectedRoots = HashSet<Int>()

        // 1. Coleta os nós da janela principal (se não for nosso app)
        val activeRoot = rootInActiveWindow
        if (activeRoot != null) {
            val rootPkg = activeRoot.packageName?.toString() ?: ""
            if (rootPkg != packageName && rootPkg != "ai.gcodeflow") {
                collectedRoots.add(activeRoot.hashCode())
                collect(activeRoot, texts, 0)
            }
        }

        // 2. Coleta de todas as janelas interativas (popups do Uber e 99, mas NUNCA a nossa própria tarja)
        try {
            for (window in windows) {
                val root = window.root ?: continue
                val rootPkg = root.packageName?.toString() ?: ""
                if (rootPkg == packageName || rootPkg == "ai.gcodeflow") continue // NUNCA ler a própria tarja!
                if (!collectedRoots.add(root.hashCode())) continue // Evita duplicar a mesma janela
                collect(root, texts, 0)
            }
        } catch (_: Exception) {}

        if (texts.isEmpty()) return

        val offer = OfferParser.parse(texts, source)
        if (offer == null) {
            // Se estiver no inDrive e não houver corrida selecionada (ex: está na lista ou voltou da seleção),
            // esconde a tarja imediatamente para não ficar exibindo valores da tela anterior!
            if (source.equals("inDrive", ignoreCase = true) && overlay.isShowing()) {
                overlay.hide()
                lastSignature = null
            }
            return
        }

        val sig = offer.signature()

        // Se o usuário dispensou essa oferta tocando nela, não reabre enquanto for a mesma
        if (sig == dismissedSignature) return

        // Se a mesma oferta já estiver na tela, não recria a janela para não ficar piscando ("biruta")
        if (sig == lastSignature && overlay.isShowing()) return

        lastSignature = sig
        lastSignatureAt = now
        lastScanAt = now
        dismissedSignature = null

        val settings = store.settings()
        val evaluation = DecisionEngine.evaluate(offer, settings)
        store.addHistory(offer, evaluation)
        if (settings.overlayEnabled) {
            overlay.show(offer, evaluation) {
                dismissedSignature = sig
            }
        }
    }

    private fun resolveSource(pkg: String): String? {
        val p = pkg.lowercase()
        if (p.contains("ubercab") || p.contains("uber")) return "Uber"
        if (p.contains("app99") || p.contains("taxis99") || p.contains("didi")) return "99"
        if (p.contains("indriver") || p.contains("indrive") || p.contains("sinet")) return "inDrive"

        // Se o evento veio de um serviço do sistema ou diálogo, inspeciona as janelas em primeiro plano
        try {
            for (w in windows) {
                val wp = w.root?.packageName?.toString()?.lowercase() ?: ""
                if (wp == packageName || wp == "ai.gcodeflow") continue
                if (wp.contains("ubercab") || wp.contains("uber")) return "Uber"
                if (wp.contains("app99") || wp.contains("taxis99") || wp.contains("didi")) return "99"
                if (wp.contains("indriver") || wp.contains("indrive") || wp.contains("sinet")) return "inDrive"
            }
        } catch (_: Exception) {}

        return null
    }

    private fun collect(node: AccessibilityNodeInfo?, out: MutableList<String>, depth: Int) {
        if (node == null || depth > MAX_DEPTH || out.size >= MAX_TEXTS) return
        val nodePkg = node.packageName?.toString() ?: ""
        if (nodePkg == packageName || nodePkg == "ai.gcodeflow") return // NUNCA coleta texto do nosso próprio app/overlay

        val txt = node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val desc = node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        if (txt != null) {
            out.add(txt)
        }
        if (desc != null && desc != txt) {
            out.add(desc)
        }
        for (i in 0 until node.childCount) {
            collect(node.getChild(i), out, depth + 1)
        }
    }

    override fun onInterrupt() {
        if (::overlay.isInitialized) overlay.hide()
    }

    override fun onDestroy() {
        if (::overlay.isInitialized) overlay.hide()
        if (instance === this) instance = null
        super.onDestroy()
    }

    companion object {
        @Volatile
        var instance: OfferAccessibilityService? = null

        private const val SCAN_INTERVAL_MS = 250L
        private const val DEDUP_MS = 3_000L
        private const val MAX_DEPTH = 35
        private const val MAX_TEXTS = 400
    }
}
