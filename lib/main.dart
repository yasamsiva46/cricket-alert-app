import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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
  String currentStatus = "వెబ్‌సైట్ సిద్ధంగా ఉంది";
  String matchedInfo = "";
  Uint8List? _beepBytes;

  @override
  void initState() {
    super.initState();
    _beepBytes = _generateLoudBeepWav();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(1.0);
  }

  // చెవులు పగిలే లౌడ్ ఎలక్ట్రానిక్ బీప్ సౌండ్ (Offline Loud Buzzer)
  Uint8List _generateLoudBeepWav() {
    const int sampleRate = 44100;
    const double duration = 1.0;
    final int numSamples = (sampleRate * duration).toInt();
    const double frequency = 1200.0;
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final byteData = ByteData(44 + dataSize);
    byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49); byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46); // RIFF
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41); byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45); // WAVE
    byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D); byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20); // fmt
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61); byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61); // data
    byteData.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      bool isBeep = (t % 0.4) < 0.25; // బీప్ - బీప్ పల్స్
      int sample = 0;
      if (isBeep) {
        double sinVal = math.sin(2 * math.pi * frequency * t);
        sample = sinVal >= 0 ? 32000 : -32000;
      }
      byteData.setInt16(44 + i * 2, sample, Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  void startMonitoring() {
    WakelockPlus.enable();
    _rateCheckTimer?.cancel();

    _rateCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (webViewController == null || !isAlarmSet || targetRate == null) return;

      // కేవలం Back & Lay మెయిన్ రేట్లను మాత్రమే ఫిల్టర్ చేసే ప్రత్యేక స్క్రిప్ట్
      var result = await webViewController!.evaluateJavascript(source: """
        (function() {
          let target = $targetRate;

          // పైన ఉన్న స్కోర్‌బోర్డులు, హెడర్లు కాకుండా కేవలం ఆడ్స్ రోస్ (Odds Rows) మాత్రమే వెతకడం
          let rows = document.querySelectorAll('tr, .runner-row, div[class*="runner"], div[class*="market-row"]');

          for (let row of rows) {
            // స్కోర్‌బోర్డ్ సెక్షన్‌ను పూర్తిగా వదిలేయడం
            if (row.closest('.scoreboard, .match-header, .score, thead')) continue;

            // టీం / ప్లేయర్ పేరును గుర్తించడం
            let teamName = "";
            let nameEl = row.querySelector('.runner-name, .team-name, .nation-name, span[class*="name"]');
            if (nameEl) {
              teamName = nameEl.innerText.trim();
            } else {
              let firstCol = row.children[0];
              if (firstCol) {
                let txt = firstCol.innerText.trim().split(/\\r?\\n/)[0].trim();
                if (txt && !/back|lay|max|cashout/i.test(txt)) {
                  teamName = txt;
                }
              }
            }

            // కేవలం Back & Lay బాక్సులను మాత్రమే తనిఖీ చేయడం
            let oddsBoxes = row.querySelectorAll('button, td, div[class*="back"], div[class*="lay"]');

            for (let box of oddsBoxes) {
              let text = box.innerText.trim();
              if (!text) continue;

              // బాక్స్‌లోని మొదటి లైన్ మాత్రమే (ఇదే అసలైన రేట్, కింద ఉండే అమౌంట్ కాదు)
              let lines = text.split(/\\s+|\\r?\\n/);
              let mainRateStr = lines[0]; // ఉదా: 1.08 లేదా 1.09
              let rateVal = parseFloat(mainRateStr);

              // మనం ఇచ్చిన టార్గెట్ రేటుతో సరిగ్గా సమానమైతే మాత్రమే
              if (!isNaN(rateVal) && Math.abs(rateVal - target) < 0.001) {
                let isLay = /lay|pink/i.test(box.className) || /lay|pink/i.test(box.parentElement?.className || '');
                return JSON.stringify({
                  found: true,
                  team: teamName || "ప్లేయర్/టీం",
                  type: isLay ? "Lay" : "Back",
                  rate: mainRateStr
                });
              }
            }
          }
          return JSON.stringify({ found: false });
        })();
      """);

      if (result != null && result.toString().isNotEmpty) {
        try {
          var data = jsonDecode(result.toString());
          if (data["found"] == true && !isAlarmRinging) {
            triggerAlarm(data["team"], data["type"], data["rate"]);
          }
        } catch (_) {}
      }
    });
  }

  void triggerAlarm(String team, String type, String rate) async {
    setState(() {
      isAlarmRinging = true;
      matchedInfo = "$team ($type: $rate)";
      currentStatus = "🚨 రేటు వచ్చింది: $matchedInfo";
    });

    if (_beepBytes != null) {
      await _audioPlayer.play(BytesSource(_beepBytes!), volume: 1.0);
    }
  }

  void stopAlarm() async {
    await _audioPlayer.stop();
    _rateCheckTimer?.cancel();
    WakelockPlus.disable();

    setState(() {
      isAlarmRinging = false;
      isAlarmSet = false;
      matchedInfo = "";
      currentStatus = "అలారమ్ ఆఫ్ చేయబడింది";
    });
  }

  @override
  void dispose() {
    stopAlarm();
    _rateController.dispose();
    _audioPlayer.dispose();
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isAlarmRinging ? Colors.red[800] : Colors.blueGrey[800],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "టార్గెట్ రేట్ (ఉదా: 1.08 లేదా 1.09)",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                          filled: true,
                          fillColor: Colors.black38,
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAlarmRinging ? Colors.black : (isAlarmSet ? Colors.orange[800] : Colors.green[700]),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        if (isAlarmRinging) {
                          stopAlarm();
                          return;
                        }

                        double? entered = double.tryParse(_rateController.text.trim());
                        if (entered != null) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            targetRate = entered;
                            isAlarmSet = true;
                            currentStatus = "🟢 రేటు $targetRate కోసం ట్రాకింగ్ జరుగుతోంది...";
                          });
                          startMonitoring();
                        }
                      },
                      child: Text(
                        isAlarmRinging ? "STOP ALARM" : (isAlarmSet ? "CANCEL" : "SET ALARM"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currentStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isAlarmRinging ? Colors.white : Colors.yellowAccent,
                    fontSize: isAlarmRinging ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}
