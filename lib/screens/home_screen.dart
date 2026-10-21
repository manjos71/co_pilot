import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge.dart';
import '../theme.dart';
import '../widgets/semaforo_tarja.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.active});

  final bool active;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _accessibilityOn = false;
  AppSettings _settings = const AppSettings();
  List<OfferRecord> _history = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (widget.active) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        Native.isAccessibilityEnabled(),
        Native.getSettings(),
        Native.getHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _accessibilityOn = results[0] as bool;
        _settings = results[1] as AppSettings;
        _history = (results[2] as List<OfferRecord>).where((o) => o.price >= 4.0).toList();
      });
    } catch (_) {
      // Canal nativo indisponível fora do Android
    }
  }

  Future<void> _setOverlay(bool on) async {
    final next = _settings.copyWith(overlayEnabled: on);
    setState(() => _settings = next);
    await Native.saveSettings(next);
  }

  Future<void> _analyzeScreenshot() async {
    try {
      final res = await Native.analyzeScreenshot();
      if (!mounted) return;
      if (res['success'] == true) {
        await _refresh();
        final rec = OfferRecord.fromMap(res);
        _showAnalysisModal(rec);
      } else {
        final msg = res['message'] as String? ?? 'Não foi possível ler o print.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Neon.amber,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao analisar print: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showAnalysisModal(OfferRecord rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Neon.surfaceHi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cfg = _settings.getForApp(rec.source);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Neon.lime, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Print Lido com Sucesso (${rec.source})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SemaforoTarjaWidget(
                  source: rec.source,
                  totalKm: rec.totalKm,
                  totalMin: rec.totalMin,
                  price: rec.price,
                  rating: rec.rating,
                  config: cfg,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Neon.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _rowInfo('Valor da Corrida', 'R\$ ${rec.price.toStringAsFixed(2)}'),
                      _rowInfo('Distância Total', '${rec.totalKm.toStringAsFixed(1)} km (Emb: ${rec.pickupKm.toStringAsFixed(1)}km, Viag: ${rec.tripKm.toStringAsFixed(1)}km)'),
                      _rowInfo('Tempo Estimado', '${rec.totalMin} min (Emb: ${rec.pickupMin}min, Viag: ${rec.tripMin}min)'),
                      if (rec.rating != null)
                        _rowInfo('Nota Passageiro', '★ ${rec.rating!.toStringAsFixed(2)}'),
                      _rowInfo('Ganho / Km', 'R\$ ${rec.perKm.toStringAsFixed(2)}/km (${rec.kmStatus})'),
                      _rowInfo('Ganho / Hora', 'R\$ ${rec.perHour.toStringAsFixed(2)}/h (${rec.hourStatus})'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Neon.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rowInfo(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Neon.textDim, fontSize: 12)),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  List<OfferRecord> get _today {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return _history.where((o) => o.time >= start).toList();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final goodCount = today.where((o) => o.overallStatus == 'GOOD').length;
    final badCount = today.where((o) => o.overallStatus == 'BAD').length;

    return RefreshIndicator(
      color: Neon.cyan,
      backgroundColor: Neon.surface,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _Header(),
          const SizedBox(height: 18),

          // Status do Serviço de Acessibilidade
          _StatusCard(on: _accessibilityOn, onOpen: Native.openAccessibilitySettings),
          const SizedBox(height: 14),

          // Card do Copiloto / Tarja Flutuante
          NeonCard(
            color: Neon.cyan,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.picture_in_picture_alt, color: Neon.cyan, size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copiloto (Tarja na Tela)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        'Mostra \$/Km e \$/Hora sobre Uber, 99 e inDrive',
                        style: TextStyle(color: Neon.textDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(value: _settings.overlayEnabled, onChanged: _setOverlay),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card de Leitura de Prints via OCR
          _OcrScanCard(onAnalyze: _analyzeScreenshot),
          const SizedBox(height: 14),

          // Resumo dos Parâmetros do Semáforo
          _SemaforoSummaryCard(config: _settings.global),
          const SizedBox(height: 14),

          // Estatísticas do dia com cores do semáforo
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Lidas hoje',
                  value: '${today.length}',
                  color: Neon.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  label: 'Boas (Verde)',
                  value: '$goodCount',
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  label: 'Ruins (Vermelho)',
                  value: '$badCount',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Última Oferta Lida
          Row(
            children: [
              const Text(
                'ÚLTIMA CORRIDA LIDA',
                style: TextStyle(
                  color: Neon.textDim,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_history.isNotEmpty)
                Text(
                  _history.first.source,
                  style: const TextStyle(color: Neon.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_history.isEmpty)
            NeonCard(
              color: Neon.surfaceHi,
              child: Column(
                children: [
                  const Icon(Icons.radar, color: Neon.textDim, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Nenhuma oferta lida ainda.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ative o serviço de Acessibilidade e abra o app de corridas (Uber, 99 ou inDrive) para ver a tarja.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Neon.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Native.testOverlay(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Simular leitura de corrida'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Neon.cyan,
                      side: const BorderSide(color: Neon.cyan),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SemaforoTarjaWidget(
              source: _history.first.source,
              totalKm: _history.first.totalKm,
              totalMin: _history.first.totalMin,
              price: _history.first.price,
              rating: _history.first.rating,
              config: _settings.getForApp(_history.first.source),
            ),
            const SizedBox(height: 12),
            OfferTile(offer: _history.first, big: false),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Neon.cyan, width: 2),
            boxShadow: Neon.glow(Neon.cyan),
          ),
          child: const Icon(Icons.navigation, color: Neon.cyan),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CO PILOT',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Neon.cyan,
                  shadows: [Shadow(color: Neon.cyan, blurRadius: 12)],
                ),
              ),
              Text('Semáforo inteligente para motoristas', style: TextStyle(color: Neon.textDim, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.on, required this.onOpen});

  final bool on;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = on ? Neon.lime : Neon.red;
    return NeonCard(
      color: color,
      glowing: true,
      child: Row(
        children: [
          Icon(on ? Icons.check_circle : Icons.error_outline, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on ? 'Leitura ativa (Semáforo ON)' : 'Leitura desligada',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  on
                      ? 'Lendo ofertas em segundo plano sobre os apps.'
                      : 'Ative o Co Pilot em Acessibilidade para ler as corridas.',
                  style: const TextStyle(color: Neon.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!on)
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: Neon.lime),
              child: const Text('ATIVAR'),
            ),
        ],
      ),
    );
  }
}

class _SemaforoSummaryCard extends StatelessWidget {
  const _SemaforoSummaryCard({required this.config});

  final SemaforoConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Neon.surfaceHi,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.traffic, color: Neon.amber, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PARÂMETROS ATIVOS DO SEMÁFORO',
                    style: TextStyle(
                      color: Neon.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _thresholdPill(
                  title: 'Ganhos / Km',
                  ruim: 'R\$ ${config.kmRuim.toStringAsFixed(2)}',
                  bom: 'R\$ ${config.kmBom.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _thresholdPill(
                  title: 'Ganhos / Hora',
                  ruim: 'R\$ ${config.horaRuim.toStringAsFixed(0)}',
                  bom: 'R\$ ${config.horaBom.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _thresholdPill(
                  title: 'Nota Mínima',
                  ruim: '★ ${config.notaRuim.toStringAsFixed(2)}',
                  bom: '★ ${config.notaBom.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thresholdPill({
    required String title,
    required String ruim,
    required String bom,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(color: Neon.textDim, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ruim, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w800)),
                const Text(' / ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                Text(bom, style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Neon.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Cartão detalhado de uma oferta no histórico
class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer, this.big = false});

  final OfferRecord offer;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final statusColor = Neon.forSemaforo(offer.overallStatus);
    final statusLabel = Neon.labelForSemaforo(offer.overallStatus);

    return NeonCard(
      color: statusColor,
      glowing: big,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${offer.price.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(fontSize: big ? 28 : 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${offer.source})',
                              style: const TextStyle(color: Neon.textDim, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metricBadge(
                label: '\$/Km',
                value: 'R\$ ${offer.perKm.toStringAsFixed(2)}',
                color: Neon.forSemaforo(offer.kmStatus),
              ),
              _metricBadge(
                label: '\$/Hora',
                value: 'R\$ ${offer.perHour.toStringAsFixed(0)}/h',
                color: Neon.forSemaforo(offer.hourStatus),
              ),
              if (offer.rating != null)
                _metricBadge(
                  label: 'Nota',
                  value: '★ ${offer.rating!.toStringAsFixed(1)}',
                  color: Neon.forSemaforo(offer.ratingStatus),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${offer.totalKm.toStringAsFixed(1)} km · ${offer.totalMin} min'
            '${offer.pickupKm > 0 ? ' (Busca: ${offer.pickupKm.toStringAsFixed(1)}km, Viagem: ${offer.tripKm.toStringAsFixed(1)}km)' : ''}',
            style: const TextStyle(color: Neon.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Neon.textDim, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _OcrScanCard extends StatelessWidget {
  const _OcrScanCard({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      color: Neon.lime,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Neon.lime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Neon.lime.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.add_photo_alternate, color: Neon.lime, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analisar Print da Galeria',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Leitura automática de prints da Uber, 99 e inDrive',
                  style: TextStyle(color: Neon.textDim, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAnalyze,
            style: ElevatedButton.styleFrom(
              backgroundColor: Neon.lime,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'LER',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
