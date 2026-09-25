import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CricketAlertApp());
}

class CricketAlertApp extends StatelessWidget {
  const CricketAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Odds Alert',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const LiveMatchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  final String apiKey = "f768ee8677e8516db99986e3401c68a2";
  final TextEditingController _targetController = TextEditingController(text: "50");

  String team1 = "NSW";
  String team2 = "VIC";
  String score1 = "257/10";
  String overs1 = "48.5";
  String matchStatus = "Innings Break";

  double backRate = 50.0;
  double layRate = 51.0;

  bool isMonitoring = false;
  Timer? _timer;
  String logStatus = "Monitoring is OFF";

  void toggleMonitoring() {
    setState(() {
      isMonitoring = !isMonitoring;
    });

    if (isMonitoring) {
      logStatus = "Monitoring Active (Screen-Off Alert Ready)";
      fetchLiveOdds();
      _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
        fetchLiveOdds();
      });
    } else {
      _timer?.cancel();
      FlutterRingtonePlayer().stop();
      logStatus = "Monitoring Stopped";
    }
  }

  Future<void> fetchLiveOdds() async {
    final double target = double.tryParse(_targetController.text) ?? 50.0;
    final sportsUrl = Uri.parse("https://api.the-odds-api.com/v4/sports/?apiKey=$apiKey");

    try {
      final res = await http.get(sportsUrl);
      if (res.statusCode == 200) {
        final List sports = json.decode(res.body);
        final cricket = sports.where((s) => s['key'].toString().contains('cricket')).toList();

        for (var item in cricket) {
          final sKey = item['key'];
          final oddsUrl = Uri.parse(
              "https://api.the-odds-api.com/v4/sports/$sKey/odds/?apiKey=$apiKey&regions=in,uk,eu,au&markets=h2h");
          final oddsRes = await http.get(oddsUrl);
          if (oddsRes.statusCode == 200) {
            final List matches = json.decode(oddsRes.body);
            for (var m in matches) {
              for (var bm in m['bookmakers'] ?? []) {
                for (var mkt in bm['markets'] ?? []) {
                  for (var out in mkt['outcomes'] ?? []) {
                    final double price = (out['price'] as num).toDouble();
                    if (price >= target) {
                      triggerLoudAlarm(out['name'], price);
                      return;
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        logStatus = "Sync Error: $e";
      });
    }
  }

  void triggerLoudAlarm(String team, double rate) {
    setState(() {
      logStatus = "TARGET REACHED: $team at $rate!";
    });

    FlutterRingtonePlayer().playAlarm(
      volume: 1.0,
      looping: true,
      asAlarm: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("NSW vs VIC, 6th One Day", style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
              isMonitoring ? Icons.notifications_active : Icons.notifications_none,
              color: isMonitoring ? const Color(0xFF00D26A) : Colors.white70,
            ),
            onPressed: toggleMonitoring,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$team1  $score1 ($overs1)",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(matchStatus,
                          style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("CRR: 5.26 | Target: 258", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text("Victoria", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Text("VIC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Container(
                    width: 48,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("${backRate.toInt()}",
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF472B6).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFFF472B6)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("${layRate.toInt()}",
                        style: const TextStyle(color: Color(0xFFF472B6), fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMonitoring ? const Color(0xFF00D26A) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.alarm, color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 8),
                      Text("SET RATE ALARM (SCREEN-OFF)",
                          style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text("Target Odds:", style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 75,
                        child: TextField(
                          controller: _targetController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: toggleMonitoring,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMonitoring ? Colors.redAccent : const Color(0xFF00D26A),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        child: Text(isMonitoring ? "STOP" : "START ALARM",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(logStatus,
                      style: TextStyle(
                          color: isMonitoring ? const Color(0xFF00D26A) : Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
