// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class ManualeReworkPage extends StatelessWidget {
  const ManualeReworkPage({super.key});
  @override
  Widget build(BuildContext context) {
    const viewType = 'pdf-rework';
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => html.IFrameElement()
          ..src =
              '${html.window.location.origin}/assets/assets/pdf/WorkInstructionReWork.pdf'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Work Instruction ReWork")),
      body: kIsWeb
          ? const SizedBox.expand(child: HtmlElementView(viewType: viewType))
          : const Center(
              child: Text("La visualizzazione è solo supportata sul Web")),
    );
  }
}
