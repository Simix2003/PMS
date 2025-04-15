// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import '../../shared/widgets/object_card.dart';

Widget M326HomePage(BuildContext context,
    {required String objectId,
    required String stringatrice,
    required selectedLine,
    required selectedChannel,
    required VoidCallback onSubmitOK,
    required VoidCallback onSubmitKO}) {
  if (objectId.isEmpty) {
    return const Center(
      child: Text(
        "Nessun oggetto in ReWork",
        style: TextStyle(fontSize: 20, color: Colors.black54),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectCard(
          objectId: objectId,
          stringatrice: stringatrice,
          isObjectOK: false,
          hasBeenEvaluated: true,
          selectedLine: selectedLine,
          selectedChannel: selectedChannel,
          issuesSubmitted: true,
          onIssuesLoaded: (_) {},
        ),
        const SizedBox(height: 24),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 28),
              label: const Text("Segna come OK"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              onPressed: onSubmitOK,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.close, size: 28),
              label: const Text("KO definitivo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              onPressed: onSubmitKO,
            ),
          ],
        )
      ],
    ),
  );
}
