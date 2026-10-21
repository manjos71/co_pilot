import 'package:flutter/material.dart';

import '../bridge.dart';
import '../theme.dart';
import '../widgets/semaforo_tarja.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _s = const AppSettings();
  bool _loaded = false;
  String _selectedApp = 'Geral'; // 'Geral', 'Uber', '99', 'inDrive'
  bool _isSaving = false;

  // Parâmetros de teste simulados para o preview
  double _testPrice = 17.0;
  double _testKm = 10.2;
  int _testMin = 23;
  double _testRating = 5.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Native.getSettings();
      if (mounted) setState(() => _s = s);
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveCurrent() async {
    setState(() => _isSaving = true);
    try {
      await Native.saveSettings(_s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações do Semáforo salvas com sucesso!'),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Neon.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  SemaforoConfig _currentConfig() {
    switch (_selectedApp) {
      case 'Uber':
        return _s.uber ?? _s.global;
      case '99':
        return _s.app99 ?? _s.global;
      case 'inDrive':
        return _s.inDrive ?? _s.global;
      default:
        return _s.global;
    }
  }

  void _updateCurrentConfig(SemaforoConfig newCfg) {
    setState(() {
      switch (_selectedApp) {
        case 'Uber':
          _s = _s.copyWith(uber: newCfg);
          break;
        case '99':
          _s = _s.copyWith(app99: newCfg);
          break;
        case 'inDrive':
          _s = _s.copyWith(inDrive: newCfg);
          break;
        default:
          _s = _s.copyWith(global: newCfg);
          break;
      }
    });
  }

  Future<void> _testTarjaNative() async {
    try {
      final res = await Native.testOverlay(
        source: _selectedApp == 'Geral' ? 'inDrive' : _selectedApp,
        price: _testPrice,
        totalKm: _testKm,
        totalMin: _testMin,
        rating: _testRating,
      );
      final shown = res['shown'] as bool? ?? false;
      final msg = res['message'] as String? ?? 'Tarja disparada!';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: shown ? const Color(0xFF15803D) : Neon.amber,
            action: !shown
                ? const SnackBarAction(
                    label: 'ATIVAR',
                    textColor: Colors.white,
                    onPressed: Native.openAccessibilitySettings,
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao disparar overlay: $e'), backgroundColor: Neon.red),
        );
      }
    }
  }

  Future<void> _analyzeScreenshot() async {
    try {
      final res = await Native.analyzeScreenshot();
      if (!mounted) return;
      if (res['success'] == true) {
        final src = res['source'] ?? '';
        final p = (res['price'] as num?)?.toDouble() ?? 0.0;
        final km = (res['totalKm'] as num?)?.toDouble() ?? 0.0;
        final min = (res['totalMin'] as num?)?.toInt() ?? 0;
        final r = (res['rating'] as num?)?.toDouble() ?? -1.0;

        setState(() {
          _testPrice = p;
          _testKm = km;
          _testMin = min;
          _testRating = r > 0 ? r : 5.0;
          if (src == 'Uber' || src == '99' || src == 'inDrive') {
            _selectedApp = src;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print lido com sucesso! ($src: R\$ ${p.toStringAsFixed(2)}, ${km.toStringAsFixed(1)}km)'),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 3),
          ),
        );
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
          SnackBar(content: Text('Erro ao analisar print: $e'), backgroundColor: Neon.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: Neon.cyan));

    final currentCfg = _currentConfig();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // --- Título / Cabeçalho ---
        Row(
          children: [
            const Icon(Icons.traffic, color: Neon.amber, size: 28),
            const SizedBox(width: 10),
            const Text(
              'SEMÁFORO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
            const Spacer(),
            if (_isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Neon.cyan),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Defina os parâmetros para leitura da corrida. A tarja indicará se a corrida compensa com base nas cores do semáforo.',
          style: TextStyle(color: Neon.textDim, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // --- Legenda do Semáforo ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Neon.surfaceHi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusLegend(color: Color(0xFFEF4444), label: 'Ruim (Recusar)'),
                SizedBox(width: 10),
                _StatusLegend(color: Color(0xFFF59E0B), label: 'Atenção (Avaliar)'),
                SizedBox(width: 10),
                _StatusLegend(color: Color(0xFF22C55E), label: 'Bom (Aceitar)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // --- Seletor de Aplicativo (Abas) ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _appChip('Geral', Icons.tune),
              const SizedBox(width: 8),
              _appChip('Uber', Icons.directions_car),
              const SizedBox(width: 8),
              _appChip('99', Icons.local_taxi),
              const SizedBox(width: 8),
              _appChip('inDrive', Icons.speed),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Card Principal de Configuração do Semáforo ---
        NeonCard(
          color: Neon.cyan,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Parâmetros: $_selectedApp',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_selectedApp != 'Geral') ...[
                    Text(
                      _isAppEnabled(_selectedApp) ? 'Ativo' : 'Padrão Geral',
                      style: TextStyle(
                        color: _isAppEnabled(_selectedApp) ? Neon.lime : Neon.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch(
                      value: _isAppEnabled(_selectedApp),
                      onChanged: (on) {
                        setState(() {
                          _setAppEnabled(_selectedApp, on);
                        });
                      },
                    ),
                  ],
                ],
              ),
              const Divider(color: Colors.white12, height: 24),

              // 1. Ganhos por Km
              _ParameterSection(
                title: 'Ganhos por Km (R\$/Km)',
                icon: Icons.alt_route,
                ruimValue: currentCfg.kmRuim,
                bomValue: currentCfg.kmBom,
                prefix: 'R\$ ',
                step: 0.05,
                min: 0.50,
                max: 10.00,
                decimals: 2,
                onRuimChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(kmRuim: v)),
                onBomChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(kmBom: v)),
              ),
              const SizedBox(height: 20),

              // 2. Ganhos por Hora
              _ParameterSection(
                title: 'Ganhos por Hora (R\$/Hora)',
                icon: Icons.timer,
                ruimValue: currentCfg.horaRuim,
                bomValue: currentCfg.horaBom,
                prefix: 'R\$ ',
                step: 1.0,
                min: 10.0,
                max: 150.0,
                decimals: 2,
                onRuimChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(horaRuim: v)),
                onBomChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(horaBom: v)),
              ),
              const SizedBox(height: 20),

              // 3. Nota do Passageiro
              _ParameterSection(
                title: 'Nota do passageiro',
                icon: Icons.star_rate,
                ruimValue: currentCfg.notaRuim,
                bomValue: currentCfg.notaBom,
                prefix: '★ ',
                step: 0.05,
                min: 3.0,
                max: 5.0,
                decimals: 2,
                onRuimChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(notaRuim: v)),
                onBomChanged: (v) => _updateCurrentConfig(currentCfg.copyWith(notaBom: v)),
              ),
              const SizedBox(height: 24),

              // Botão SALVAR
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveCurrent,
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text(
                    'SALVAR CONFIGURAÇÃO',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Neon.cyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- Preview da Tarja (Exatamente como aparece na Imagem 3) ---
        const Text(
          'PREVIEW DA TARJA (COMO APARECE NA TELA)',
          style: TextStyle(
            color: Neon.textDim,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SemaforoTarjaWidget(
          source: _selectedApp == 'Geral' ? 'inDrive' : _selectedApp,
          totalKm: _testKm,
          totalMin: _testMin,
          price: _testPrice,
          rating: _testRating,
          config: currentCfg,
        ),
        const SizedBox(height: 14),

        // Controles de Simulação para Teste do Preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Neon.surfaceHi,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulador de Corrida:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _simButton('Corrida Imagem 3 (R\$17, 10.2km)', () {
                      setState(() {
                        _testPrice = 17.0;
                        _testKm = 10.2;
                        _testMin = 23;
                        _testRating = 5.0;
                      });
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _simButton('Corrida Boa (R\$35, 12km, 25m)', () {
                      setState(() {
                        _testPrice = 35.0;
                        _testKm = 12.0;
                        _testMin = 25;
                        _testRating = 4.95;
                      });
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testTarjaNative,
                  icon: const Icon(Icons.picture_in_picture_alt, color: Neon.lime),
                  label: const Text(
                    'DISPARAR TARJA FLUTUANTE NO CELULAR',
                    style: TextStyle(color: Neon.lime, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Neon.lime, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _analyzeScreenshot,
                  icon: const Icon(Icons.add_photo_alternate, color: Neon.cyan),
                  label: const Text(
                    'ANALISAR PRINT DE CORRIDA (GALERIA)',
                    style: TextStyle(color: Neon.cyan, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Neon.cyan, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appChip(String name, IconData icon) {
    final selected = _selectedApp == name;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: selected ? Colors.black : Neon.textDim),
      label: Text(name),
      selected: selected,
      onSelected: (_) => setState(() => _selectedApp = name),
      selectedColor: Neon.cyan,
      backgroundColor: Neon.surfaceHi,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: selected ? Neon.cyan : Colors.white12),
    );
  }

  bool _isAppEnabled(String app) {
    switch (app) {
      case 'Uber':
        return _s.uberEnabled;
      case '99':
        return _s.app99Enabled;
      case 'inDrive':
        return _s.inDriveEnabled;
      default:
        return true;
    }
  }

  void _setAppEnabled(String app, bool on) {
    switch (app) {
      case 'Uber':
        _s = _s.copyWith(uberEnabled: on);
        break;
      case '99':
        _s = _s.copyWith(app99Enabled: on);
        break;
      case 'inDrive':
        _s = _s.copyWith(inDriveEnabled: on);
        break;
    }
  }

  Widget _simButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Seção com os seletores Ruim e Bom (como na imagem 2 do Zeca)
class _ParameterSection extends StatelessWidget {
  const _ParameterSection({
    required this.title,
    required this.icon,
    required this.ruimValue,
    required this.bomValue,
    required this.prefix,
    required this.step,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onRuimChanged,
    required this.onBomChanged,
  });

  final String title;
  final IconData icon;
  final double ruimValue;
  final double bomValue;
  final String prefix;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onRuimChanged;
  final ValueChanged<double> onBomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Neon.cyan),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Bloco "Ruim"
            Expanded(
              child: _StepperBox(
                label: 'Ruim (Abaixo)',
                labelColor: const Color(0xFFEF4444),
                value: ruimValue,
                prefix: prefix,
                step: step,
                min: min,
                max: bomValue, // Não pode ultrapassar o bom
                decimals: decimals,
                onChanged: onRuimChanged,
              ),
            ),
            const SizedBox(width: 12),
            // Bloco "Bom"
            Expanded(
              child: _StepperBox(
                label: 'Bom (Acima)',
                labelColor: const Color(0xFF22C55E),
                value: bomValue,
                prefix: prefix,
                step: step,
                min: ruimValue, // Não pode ser menor que o ruim
                max: max,
                decimals: decimals,
                onChanged: onBomChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Caixa com botões [-] e [+] para ajuste de valores (exatamente como na imagem 2)
class _StepperBox extends StatelessWidget {
  const _StepperBox({
    required this.label,
    required this.labelColor,
    required this.value,
    required this.prefix,
    required this.step,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
  });

  final String label;
  final Color labelColor;
  final double value;
  final String prefix;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = value.toStringAsFixed(decimals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Neon.surfaceHi,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              // Botão [-]
              IconButton(
                icon: const Icon(Icons.remove, size: 18, color: Colors.white70),
                onPressed: () {
                  final next = (value - step).clamp(min, max);
                  onChanged(double.parse(next.toStringAsFixed(decimals)));
                },
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              ),
              // Valor
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$prefix$formatted',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Botão [+]
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: Colors.white70),
                onPressed: () {
                  final next = (value + step).clamp(min, max);
                  onChanged(double.parse(next.toStringAsFixed(decimals)));
                },
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
