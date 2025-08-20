// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cool-looking password gate. Returns true if verified.
Future<bool> showPasswordGate(
  BuildContext context, {
  String title = 'Area protetta',
  String subtitle = 'Inserisci la password per continuare',
  FutureOr<bool> Function(String password)? verify, // Async/sync
}) async {
  verify ??= (pwd) async => pwd == 'PMS2025'; // 🔒 placeholder (replace)

  final controller = TextEditingController();
  bool isObscured = true;
  bool isLoading = false;
  String? error;

  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Password',
        barrierColor: Colors.black.withOpacity(0.25),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (context, anim, __, ___) {
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          );
          final fade =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);

          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Material(
                            color: Colors.white.withOpacity(0.9),
                            elevation: 0,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade400,
                                              Colors.purple.shade400,
                                              Colors.pink.shade300,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.lock_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(title,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black87)),
                                            const SizedBox(height: 2),
                                            Text(subtitle,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: controller,
                                    autofocus: true,
                                    obscureText: isObscured,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) async {
                                      HapticFeedback.selectionClick();
                                      if (isLoading) return;
                                      setState(() => isLoading = true);
                                      final ok = await verify!(controller.text);
                                      if (ok) {
                                        Navigator.of(context).pop(true);
                                      } else {
                                        setState(() {
                                          error = 'Password non corretta';
                                          isLoading = false;
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Password',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.blue.shade400,
                                            width: 1.2),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip:
                                            isObscured ? 'Mostra' : 'Nascondi',
                                        onPressed: () => setState(
                                            () => isObscured = !isObscured),
                                        icon: Icon(
                                          isObscured
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (error != null) ...[
                                    const SizedBox(height: 8),
                                    Text(error!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 12)),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Annulla'),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () async {
                                                HapticFeedback.lightImpact();
                                                setState(
                                                    () => isLoading = true);
                                                final ok = await verify!(
                                                    controller.text);
                                                if (ok) {
                                                  Navigator.of(context)
                                                      .pop(true);
                                                } else {
                                                  setState(() {
                                                    error =
                                                        'Password non corretta';
                                                    isLoading = false;
                                                  });
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'Sblocca',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ) ??
      false;
}
