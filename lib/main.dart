import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: OddsWebViewApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class OddsWebViewApp extends StatefulWidget {
  const OddsWebViewApp({super.key});

  @override
  State<OddsWebViewApp> createState() => _OddsWebViewAppState();
}

class _OddsWebViewAppState extends State<OddsWebViewApp> {
  InAppWebViewController? webViewController;
  final TextEditingController _rateController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isAlarmSet = false;
  bool isAlarmRinging = false;
  double? targetRate;
  Timer? _rateCheckTimer;
  String currentStatus = "వెబ్‌సైట్ లోడ్ అవుతోంది...";

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void startMonitoring() {
    WakelockPlus.enable();
    _rateCheckTimer?.cancel();

    _rateCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (webViewController == null || !isAlarmSet || targetRate == null) return;

      var result = await webViewController!.evaluateJavascript(source: """
        (function() {
          let text = document.body.innerText;
          let target = $targetRate;
          let regex = new RegExp('\\\\b' + target + '(\\\\.[0-9]+)?\\\\b');
          return regex.test(text);
        })();
      """);

      if (result == true && !isAlarmRinging) {
        triggerAlarm();
      }
    });
  }

  void triggerAlarm() async {
    setState(() {
      isAlarmRinging = true;
      currentStatus = "🚨 అలారమ్ మోగుతోంది! టార్గెట్ రేటు వచ్చింది!";
    });

    await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'));
  }

  void stopAlarm() async {
    await _audioPlayer.stop();
    _rateCheckTimer?.cancel();
    WakelockPlus.disable();
    setState(() {
      isAlarmRinging = false;
      isAlarmSet = false;
      currentStatus = "అలారమ్ ఆఫ్ చేయబడింది";
    });
  }

  @override
  void dispose() {
    _rateCheckTimer?.cancel();
    _rateController.dispose();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: const Text("🏏 Live Odds Alarm", style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => webViewController?.reload(),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isAlarmRinging ? Colors.red[700] : Colors.blueGrey[800],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "టార్గెట్ రేట్ (ఉదా: 45)",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black26,
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAlarmSet ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (isAlarmRinging) {
                          stopAlarm();
                          return;
                        }

                        double? entered = double.tryParse(_rateController.text.trim());
                        if (entered != null) {
                          setState(() {
                            targetRate = entered;
                            isAlarmSet = true;
                            currentStatus = "🟢 రేటు $targetRate కోసం ట్రాకింగ్ జరుగుతోంది...";
                          });
                          startMonitoring();
                        }
                      },
                      child: Text(isAlarmRinging ? "STOP ALARM" : (isAlarmSet ? "CANCEL" : "SET ALARM")),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  currentStatus,
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://allpanel9.global"),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                cacheEnabled: true,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStop: (controller, url) {
                setState(() {
                  if (!isAlarmSet) currentStatus = "వెబ్‌సైట్ రెడీగా ఉంది!";
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
