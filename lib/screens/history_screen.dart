import 'package:flutter/material.dart';

import '../bridge.dart';
import '../theme.dart';
import 'home_screen.dart' show OfferTile;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.active});

  final bool active;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<OfferRecord> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  Future<void> _load() async {
    try {
      final h = await Native.getHistory();
      if (mounted) setState(() => _items = h.where((o) => o.price >= 4.0).toList());
    } catch (_) {}
  }

  Future<void> _clear() async {
    await Native.clearHistory();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('HISTÓRICO',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Neon.cyan, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ),
              if (_items.isNotEmpty)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Limpar'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('Sem ofertas registradas.', style: TextStyle(color: Neon.textDim)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => OfferTile(offer: _items[i]),
                ),
        ),
      ],
    );
  }
}
