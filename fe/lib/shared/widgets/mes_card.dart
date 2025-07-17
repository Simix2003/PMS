import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/utils/helpers.dart';

class MesCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MesCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final int esito = data['esito'] ?? 0;
    final statusColor = getStatusColor(esito);
    final statusLabel = getStatusLabel(esito);
    final defectsRaw = (data['defect_categories'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.85), statusColor],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ID MODULO + STATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// ID Modulo (Left)
              Text(
                '${data['id_modulo']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),

              if (data['classe_qc'] != null)
                Row(
                  children: [
                    const Icon(Icons.verified_user,
                        color: Colors.white70, size: 36),
                    const SizedBox(width: 6),
                    Text(
                      'Classe QC: ',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 36,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      data['classe_qc'],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          /// Defects (only if NG and present)
          if (esito != 1 && defectsRaw.trim().isNotEmpty) ...[
            Text(
              defectsRaw.contains(',') ? 'Difetti:' : 'Difetto:',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: defectsRaw
                  .split(',')
                  .map((d) => d.trim())
                  .where((d) => d.isNotEmpty)
                  .map(
                    (d) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          // inside MesCard.build(), just before the final `]` of `children: [...]`

          if ((data['event_count'] ?? 1) > 1)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(top: 8, right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text('${data['event_count']} eventi',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
