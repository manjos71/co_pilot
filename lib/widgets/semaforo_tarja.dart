import 'package:flutter/material.dart';

import '../bridge.dart';
import '../theme.dart';

/// Widget visual que reproduz a Tarja flutuante do Semáforo (conforme imagem 3).
/// Usado como preview interativo nas configurações e no histórico.
class SemaforoTarjaWidget extends StatelessWidget {
  const SemaforoTarjaWidget({
    super.key,
    required this.source,
    required this.totalKm,
    required this.totalMin,
    required this.price,
    this.rating,
    required this.config,
    this.onTap,
  });

  final String source;
  final double totalKm;
  final int totalMin;
  final double price;
  final double? rating;
  final SemaforoConfig config;
  final VoidCallback? onTap;

  double get perKm => price / (totalKm <= 0 ? 0.1 : totalKm);
  double get perHour => price / ((totalMin <= 0 ? 1 : totalMin) / 60.0);

  String get kmStatus {
    if (perKm < config.kmRuim) return 'BAD';
    if (perKm >= config.kmBom) return 'GOOD';
    return 'REGULAR';
  }

  String get hourStatus {
    if (perHour < config.horaRuim) return 'BAD';
    if (perHour >= config.horaBom) return 'GOOD';
    return 'REGULAR';
  }

  String get ratingStatus {
    if (rating == null) return 'REGULAR';
    if (rating! < config.notaRuim) return 'BAD';
    if (rating! >= config.notaBom) return 'GOOD';
    return 'REGULAR';
  }

  String get overallStatus {
    if (kmStatus == 'BAD' || hourStatus == 'BAD' || ratingStatus == 'BAD') {
      return 'BAD';
    }
    if (kmStatus == 'GOOD' && hourStatus == 'GOOD') {
      return 'GOOD';
    }
    return 'REGULAR';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Neon.tarjaBg(overallStatus);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Linha Superior (Header) ---
            Row(
              children: [
                _buildAppBadge(source),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${totalKm.toStringAsFixed(1)}km - ${totalMin}min',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (rating != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _ratingBg(ratingStatus),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '★ ${rating!.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // --- Linha Inferior: Caixas $/Km e $/Hora ---
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    label: '\$/Km',
                    value: perKm.toStringAsFixed(2),
                    statusColor: Neon.forSemaforo(kmStatus),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricBox(
                    label: '\$/Hora',
                    value: perHour.toStringAsFixed(2),
                    statusColor: Neon.forSemaforo(hourStatus),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBadge(String src) {
    switch (src.toLowerCase().trim()) {
      case 'indrive':
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF76BC21),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Text(
            'D',
            style: TextStyle(
              color: Color(0xFF2E6800),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        );
      case '99':
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC800),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Text(
            '99',
            style: TextStyle(
              color: Color(0xFF801500),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        );
      case 'uber':
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1),
          ),
          alignment: Alignment.center,
          child: const Text(
            'U',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        );
      default:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            src.isEmpty ? '?' : src[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        );
    }
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color statusColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 1.8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _ratingBg(String status) {
    switch (status) {
      case 'GOOD':
        return const Color(0xFF14532D);
      case 'REGULAR':
        return const Color(0xFF78350F);
      case 'BAD':
      default:
        return const Color(0xFF7F1D1D);
    }
  }
}

