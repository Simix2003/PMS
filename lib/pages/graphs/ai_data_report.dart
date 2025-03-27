import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIReportPage extends StatefulWidget {
  const AIReportPage({super.key});

  @override
  State<AIReportPage> createState() => _AIReportPageState();
}

class _AIReportPageState extends State<AIReportPage> {
  Map<String, dynamic>? report;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAIReport();
  }

  Future<void> fetchAIReport() async {
    setState(() => isLoading = true);
    final response =
        await http.get(Uri.parse("http://192.168.0.10:8000/api/ai_report"));

    if (response.statusCode == 200) {
      setState(() {
        report = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        report = null;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Report Produzione"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey[200],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : report == null
              ? const Center(child: Text("Errore nel caricamento del report"))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 15),
                    _buildProblemsCard(),
                    const SizedBox(height: 15),
                    _buildTrendCard(),
                    const SizedBox(height: 15),
                    _buildAdviceCard(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: fetchAIReport,
        icon: const Icon(Icons.refresh),
        label: const Text("Aggiorna"),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget _buildSummaryCard() => Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📅 ${report!['periodo_analisi']}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              _infoRow("Totale Pezzi", "${report!['totali']['pezzi_totali']}"),
              _infoRow("Buoni",
                  "${report!['totali']['pezzi_buoni']} (${report!['totali']['percentuale_buoni']})"),
              _infoRow("Scarti",
                  "${report!['totali']['pezzi_scarti']} (${report!['totali']['percentuale_scarti']})"),
            ],
          ),
        ),
      );

  Widget _buildProblemsCard() => Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🚩 Problemi Principali",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              ...report!['problemi_principali']
                  .map<Widget>((problem) => ListTile(
                        leading:
                            const Icon(Icons.warning, color: Colors.redAccent),
                        title: Text(problem['problema']),
                        trailing: Chip(
                          label: Text("${problem['numero_scarti']} scarti"),
                          backgroundColor: Colors.red.shade100,
                        ),
                      )),
            ],
          ),
        ),
      );

  Widget _buildTrendCard() => Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📈 Trend Produzione",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              _infoRow("Produttività", report!['trend']['produttivita']),
              _infoRow("Qualità", report!['trend']['qualita']),
            ],
          ),
        ),
      );

  Widget _buildAdviceCard() => Card(
        color: Colors.blue.shade50,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.orange, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(report!['consiglio_ai'],
                    style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
