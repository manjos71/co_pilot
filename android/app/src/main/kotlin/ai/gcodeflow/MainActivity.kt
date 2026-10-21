package ai.gcodeflow

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings as AndroidSettings
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var store: Store

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = Store(this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_IMAGE) {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                pendingResult?.success(mapOf("success" to false, "message" to "Nenhum print selecionado."))
                pendingResult = null
                return
            }
            processScreenshotUri(uri)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

                "openAccessibilitySettings" -> {
                    startActivity(
                        Intent(AndroidSettings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }

                "getSettings" -> {
                    val s = store.settings()
                    result.success(s.toMap())
                }

                "saveSettings" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val s = Settings.fromMap(args)
                        store.save(s)
                    }
                    result.success(null)
                }

                "testOverlay" -> {
                    val source = call.argument<String>("source") ?: "inDrive"
                    val price = call.argument<Double>("price") ?: 17.0
                    val totalKm = call.argument<Double>("totalKm") ?: 10.2
                    val totalMin = call.argument<Int>("totalMin") ?: 23
                    val rating = call.argument<Double>("rating") ?: 5.0

                    val offer = Offer(
                        source = source,
                        price = price,
                        pickupKm = 0.0,
                        pickupMin = 0,
                        tripKm = totalKm,
                        tripMin = totalMin,
                        rating = rating,
                    )

                    val settings = store.settings()
                    val evaluation = DecisionEngine.evaluate(offer, settings)

                    val service = OfferAccessibilityService.instance
                    if (service != null) {
                        service.showTestOverlay(offer, evaluation)
                        result.success(mapOf("shown" to true, "message" to "Tarja exibida no topo da tela!"))
                    } else {
                        result.success(mapOf("shown" to false, "message" to "Ative a Acessibilidade para ver a tarja flutuante."))
                    }
                }

                "analyzeScreenshot" -> {
                    pendingResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(intent, REQUEST_CODE_PICK_IMAGE)
                    } catch (e: Exception) {
                        pendingResult = null
                        result.success(mapOf("success" to false, "message" to "Não foi possível abrir a galeria: ${e.message}"))
                    }
                }

                "getHistory" -> result.success(store.history())

                "clearHistory" -> {
                    store.clearHistory()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun processScreenshotUri(uri: Uri) {
        val resultCallback = pendingResult
        pendingResult = null

        try {
            val image = InputImage.fromFilePath(this, uri)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val texts = ArrayList<String>()
                    for (block in visionText.textBlocks) {
                        for (line in block.lines) {
                            val txt = line.text.trim()
                            if (txt.isNotEmpty()) texts.add(txt)
                        }
                    }

                    if (texts.isEmpty()) {
                        resultCallback?.success(mapOf(
                            "success" to false,
                            "message" to "Nenhum texto legível foi encontrado neste print.",
                        ))
                        return@addOnSuccessListener
                    }

                    val joined = texts.joinToString(" ")
                    val source = when {
                        // 1. Uber: verifica primeiro os indicadores explícitos do Uber para evitar
                        // falso positivo quando a bolha flutuante da 99 estiver visível sobre a tela
                        joined.contains("uber", ignoreCase = true) ||
                        joined.contains("est. de r$", ignoreCase = true) ||
                        joined.contains("est de r$", ignoreCase = true) ||
                        joined.contains("fazer viagem", ignoreCase = true) -> "Uber"

                        // 2. inDrive: indicadores específicos de corrida no inDrive
                        joined.contains("indrive", ignoreCase = true) ||
                        joined.contains("sinet", ignoreCase = true) ||
                        joined.contains("aceitar por", ignoreCase = true) ||
                        joined.contains("passageiro oferece", ignoreCase = true) -> "inDrive"

                        // 3. 99: categorias da 99 ou identificador do app
                        joined.contains("99pop", ignoreCase = true) ||
                        joined.contains("99moto", ignoreCase = true) ||
                        joined.contains("99plus", ignoreCase = true) ||
                        joined.contains("99taxi", ignoreCase = true) ||
                        joined.contains("99negocia", ignoreCase = true) ||
                        joined.contains("99entrega", ignoreCase = true) ||
                        joined.contains("99 poupa", ignoreCase = true) ||
                        joined.contains("99", ignoreCase = true) ||
                        joined.contains("didi", ignoreCase = true) ||
                        joined.contains("recusar", ignoreCase = true) -> "99"

                        else -> "Uber"
                    }

                    val offer = OfferParser.parse(texts, source)
                    if (offer != null) {
                        val settings = store.settings()
                        val eval = DecisionEngine.evaluate(offer, settings)
                        store.addHistory(offer, eval)

                        // Tenta disparar a tarja na tela se a acessibilidade estiver ativa
                        OfferAccessibilityService.instance?.showTestOverlay(offer, eval)

                        resultCallback?.success(mapOf(
                            "success" to true,
                            "time" to System.currentTimeMillis(),
                            "source" to offer.source,
                            "price" to offer.price,
                            "pickupKm" to offer.pickupKm,
                            "pickupMin" to offer.pickupMin,
                            "tripKm" to offer.tripKm,
                            "tripMin" to offer.tripMin,
                            "totalKm" to eval.totalKm,
                            "totalMin" to eval.totalMin,
                            "rating" to (offer.rating ?: -1.0),
                            "perKm" to eval.perKm,
                            "perHour" to eval.perHour,
                            "score" to eval.score,
                            "verdict" to eval.verdict.name,
                            "overallStatus" to eval.overallStatus.name,
                            "kmStatus" to eval.kmStatus.name,
                            "hourStatus" to eval.hourStatus.name,
                            "ratingStatus" to eval.ratingStatus.name,
                        ))
                    } else {
                        resultCallback?.success(mapOf(
                            "success" to false,
                            "message" to "Não foi possível identificar dados da corrida (preço, distância ou tempo) neste print.",
                            "extractedText" to texts.take(15).joinToString("\n"),
                        ))
                    }
                }
                .addOnFailureListener { ex ->
                    resultCallback?.success(mapOf(
                        "success" to false,
                        "message" to "Falha no reconhecimento de imagem: ${ex.message}",
                    ))
                }
        } catch (e: Exception) {
            resultCallback?.success(mapOf(
                "success" to false,
                "message" to "Erro ao abrir imagem: ${e.message}",
            ))
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabled = AndroidSettings.Secure.getString(
            contentResolver,
            AndroidSettings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val id = "$packageName/${OfferAccessibilityService::class.java.name}"
        return enabled.split(':').any { it.equals(id, ignoreCase = true) }
    }

    private companion object {
        const val CHANNEL = "ai.gcodeflow/native"
        const val REQUEST_CODE_PICK_IMAGE = 1001
    }
}
