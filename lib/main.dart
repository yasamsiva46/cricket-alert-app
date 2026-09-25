import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yasam siva',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      home: const MatchListScreen(),
    );
  }
}

// 1. అన్ని లైవ్ మ్యాచ్‌ల మోడల్
class CricketMatch {
  final String id;
  final String title;
  final String series;
  final String team1;
  final String team2;
  final String score;
  final String crr;
  final String target;
  double oddsBack;
  double oddsLay;

  CricketMatch({
    required this.id,
    required this.title,
    required this.series,
    required this.team1,
    required this.team2,
    required this.score,
    required this.crr,
    required this.target,
    required this.oddsBack,
    required this.oddsLay,
  });
}

// 2. మొదటి పేజీ: లైవ్ మ్యాచ్‌ల లిస్ట్
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  List<CricketMatch> matches = [
    CricketMatch(
      id: '1',
      title: 'NSW vs VIC',
      series: '6th One Day',
      team1: 'New South Wales',
      team2: 'Victoria',
      score: 'NSW 257/10 (48.5) Innings Break',
      crr: '5.26',
      target: '258',
      oddsBack: 50,
      oddsLay: 51,
    ),
    CricketMatch(
      id: '2',
      title: 'IND vs AUS',
      series: '2nd T20I Match',
      team1: 'India',
      team2: 'Australia',
      score: 'IND 182/4 (18.2)',
      crr: '9.92',
      target: 'Live',
      oddsBack: 75,
      oddsLay: 77,
    ),
    CricketMatch(
      id: '3',
      title: 'ENG vs SA',
      series: '1st ODI Match',
      team1: 'England',
      team2: 'South Africa',
      score: 'ENG 310/6 (50.0)',
      crr: '6.20',
      target: '311',
      oddsBack: 42,
      oddsLay: 44,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Cricket Matches', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.greenAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Matches refreshed!')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchDetailScreen(match: match),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          match.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(match.series, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 10),
                    Text(match.score, style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 14)),
                    const Divider(color: Color(0xFF334155), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${match.team2} Odds', style: const TextStyle(color: Colors.white70)),
                        Row(
                          children: [
                            _oddsChip('${match.oddsBack.toInt()}', const Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            _oddsChip('${match.oddsLay.toInt()}', const Color(0xFFBE185D)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _oddsChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

// 3. రెండవ పేజీ: ఎంచుకున్న మ్యాచ్ వివరాలు & అలారమ్ సెటప్
class MatchDetailScreen extends StatefulWidget {
  final CricketMatch match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final TextEditingController _oddsController = TextEditingController();
  bool isMonitoring = false;
  Timer? _timer;

  void _startMonitoring() {
    if (_oddsController.text.trim().isEmpty) return;
    setState(() {
      isMonitoring = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      double? target = double.tryParse(_oddsController.text);
      if (target != null && widget.match.oddsBack <= target) {
        FlutterRingtonePlayer().playRingtone();
        _showAlarmDialog();
        _stopMonitoring();
      }
    });
  }

  void _stopMonitoring() {
    _timer?.cancel();
    FlutterRingtonePlayer().stop();
    setState(() {
      isMonitoring = false;
    });
  }

  void _showAlarmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('🚨 RATE ALERT REACHED!', style: TextStyle(color: Colors.redAccent)),
        content: Text('${widget.match.title} Odds reached: ${widget.match.oddsBack}'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FlutterRingtonePlayer().stop();
              Navigator.pop(context);
            },
            child: const Text('STOP ALARM'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _oddsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.match.title}, ${widget.match.series}', style: const TextStyle(fontSize: 16)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_active, color: Colors.greenAccent),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // స్కోర్ కార్డ్
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.match.score,
                    style: const TextStyle(color: Color(0xFFFACC15), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('CRR: ${widget.match.crr} | Target: ${widget.match.target}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ఆడ్స్ కార్డ్
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(widget.match.team2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.match.team2.substring(0, 3).toUpperCase(), style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _oddsBox('${widget.match.oddsBack.toInt()}', const Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      _oddsBox('${widget.match.oddsLay.toInt()}', const Color(0xFFBE185D)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // అలారమ్ సెట్టింగ్ కార్డ్
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.6), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.alarm, color: Color(0xFFF97316)),
                      SizedBox(width: 8),
                      Text('SET RATE ALARM (SCREEN-OFF)', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Target Odds:', style: TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _oddsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMonitoring ? Colors.redAccent : Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
                        child: Text(isMonitoring ? 'STOP' : 'SET', style: const TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isMonitoring ? 'Monitoring Active (Screen-Off Alert Ready)' : 'Alarm Inactive',
                    style: TextStyle(color: isMonitoring ? Colors.greenAccent : Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oddsBox(String value, Color color) {
    return Container(
      width: 48,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
