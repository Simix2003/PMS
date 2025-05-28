// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class ManualePage extends StatelessWidget {
  final String pdfFileName;

  const ManualePage({super.key, required this.pdfFileName});

  @override
  Widget build(BuildContext context) {
    const viewType = 'pdf-viewer-html';

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src =
                '${html.window.location.origin}/assets/assets/pdf/$pdfFileName'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          return iframe;
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(pdfFileName)),
      body: kIsWeb
          ? const SizedBox.expand(
              child: HtmlElementView(viewType: viewType),
            )
          : const Center(
              child: Text("La visualizzazione è solo supportata sul Web")),
    );
  }
}
