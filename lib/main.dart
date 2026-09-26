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
  final TextEditingController _teamController = TextEditingController();
  
  final AudioPlayer _alarmPlayer = AudioPlayer();
  final AudioPlayer _silentKeepAlivePlayer = AudioPlayer();

  bool isAlarmSet = false;
  bool isAlarmRinging = false;
  double? targetRate;
  String targetTeam = "";
  String selectedCondition = ">=";
  Timer? _rateCheckTimer;
  String currentStatus = "వెబ్‌సైట్ సిద్ధంగా ఉంది";
  String matchedInfo = "";
  
  Uint8List? _beepBytes;
  Uint8List? _silentBytes;

  // Crex ప్రధాన వెబ్‌సైట్
  final String crexUrl = "https://crex.com/";

  @override
  void initState() {
    super.initState();
    _beepBytes = _generateLoudBeepWav();
    _silentBytes = _generateSilentWav();

    AudioPlayer.global.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.alarm,
        audioMode: AndroidAudioMode.normal,
      ),
    ));

    _alarmPlayer.setReleaseMode(ReleaseMode.loop);
    _alarmPlayer.setVolume(1.0);
    _silentKeepAlivePlayer.setReleaseMode(ReleaseMode.loop);
    _silentKeepAlivePlayer.setVolume(0.01);
  }

  Uint8List _generateSilentWav() {
    const int sampleRate = 44100;
    const double duration = 1.0;
    final int numSamples = (sampleRate * duration).toInt();
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final byteData = ByteData(44 + dataSize);
    byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49); byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46);
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41); byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45);
    byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D); byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61); byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61);
    byteData.setUint32(40, dataSize, Endian.little);
    return byteData.buffer.asUint8List();
  }

  Uint8List _generateLoudBeepWav() {
    const int sampleRate = 44100;
    const double duration = 1.0;
    final int numSamples = (sampleRate * duration).toInt();
    const double frequency = 1200.0;
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final byteData = ByteData(44 + dataSize);
    byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49); byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46);
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41); byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45);
    byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D); byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61); byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61);
    byteData.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      bool isBeep = (t % 0.4) < 0.25;
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

    if (_silentBytes != null) {
      _silentKeepAlivePlayer.play(BytesSource(_silentBytes!));
    }

    _rateCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (webViewController == null || !isAlarmSet || targetRate == null) return;

      String teamQuery = targetTeam.replaceAll("'", "\\'").toLowerCase();
      String cond = selectedCondition;

      var result = await webViewController!.evaluateJavascript(source: """
        (function() {
          let target = $targetRate;
          let filterTeam = '$teamQuery';
          let condition = '$cond';

          let bookmakerEl = Array.from(document.querySelectorAll('*')).find(el => 
            el.children.length === 0 && /^bookmaker$/i.test(el.innerText.trim())
          );

          let rows = document.querySelectorAll('tr, .runner-row, div[class*="runner"], div[class*="market-row"]');

          for (let row of rows) {
            if (row.closest('.scoreboard, .match-header, .score, thead')) continue;
            if (row.closest('[class*="bookmaker"], [id*="bookmaker"], [class*="fancy"]')) continue;
            if (bookmakerEl) {
              if (bookmakerEl.compareDocumentPosition(row) & Node.DOCUMENT_POSITION_FOLLOWING) {
                continue;
              }
            }

            let teamName = "";
            let nameEl = row.querySelector('.runner-name, .team-name, .nation-name, span[class*="name"]');
            if (nameEl) {
              teamName = nameEl.innerText.trim();
            } else {
              let firstCol = row.children[0];
              if (firstCol) {
                let txt = firstCol.innerText.trim().split(/\\r?\\n/)[0].trim();
                if (txt && !/back|lay|max|cashout|bookmaker/i.test(txt)) {
                  teamName = txt;
                }
              }
            }

            if (filterTeam.length > 0) {
              if (!teamName.toLowerCase().includes(filterTeam)) {
                continue; 
              }
            }

            let backBoxes = row.querySelectorAll('button[class*="back"], td[class*="back"], div[class*="back"]');
            let mainBackBox = null;

            if (backBoxes.length > 0) {
              mainBackBox = backBoxes[backBoxes.length - 1];
            } else {
              let allBoxes = row.querySelectorAll('button, td, div[class*="odds"]');
              let nonLay = Array.from(allBoxes).filter(b => {
                let cls = (b.className + " " + (b.parentElement?.className || '')).toLowerCase();
                return !cls.includes('lay') && !cls.includes('pink') && !cls.includes('name');
              });
              if (nonLay.length > 0) {
                mainBackBox = nonLay[nonLay.length - 1];
              }
            }

            if (mainBackBox) {
              let text = mainBackBox.innerText.trim();
              if (text) {
                let lines = text.split(/\\s+|\\r?\\n/);
                let mainRateStr = lines[0];
                let rateVal = parseFloat(mainRateStr);

                if (!isNaN(rateVal)) {
                  let isMatch = false;
                  if (condition === '>=') {
                    isMatch = (rateVal >= (target - 0.0001));
                  } else if (condition === '<=') {
                    isMatch = (rateVal <= (target + 0.0001));
                  } else {
                    isMatch = Math.abs(rateVal - target) < 0.001;
                  }

                  if (isMatch) {
                    return JSON.stringify({
                      found: true,
                      team: teamName || filterTeam.toUpperCase(),
                      type: "Back",
                      rate: mainRateStr
                    });
                  }
                }
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
    await _silentKeepAlivePlayer.stop();

    setState(() {
      isAlarmRinging = true;
      matchedInfo = "$team ($type: $rate)";
      currentStatus = "🚨 రేటు వచ్చింది: $matchedInfo";
    });

    if (_beepBytes != null) {
      await _alarmPlayer.play(BytesSource(_beepBytes!), volume: 1.0);
    }
  }

  void stopAlarm() async {
    await _silentKeepAlivePlayer.stop();
    await _alarmPlayer.stop();
    _rateCheckTimer?.cancel();
    WakelockPlus.disable();

    setState(() {
      isAlarmRinging = false;
      isAlarmSet = false;
      matchedInfo = "";
      currentStatus = "అలారమ్ ఆఫ్ చేయబడింది";
    });
  }

  void _openCrexBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[900],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("🏏 Crex Live Scores", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
              ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(crexUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    stopAlarm();
    _rateController.dispose();
    _teamController.dispose();
    _alarmPlayer.dispose();
    _silentKeepAlivePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String condSymbol = selectedCondition == ">=" ? "≥" : (selectedCondition == "<=" ? "≤" : "=");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: const Text("🏏 Live Odds Alarm", style: TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.sports_cricket, size: 18),
            label: const Text("Crex", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => _openCrexBottomSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => webViewController?.reload(),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isAlarmRinging ? Colors.red[800] : Colors.blueGrey[800],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _teamController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "టీం (ఉదా: IND)",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black38,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCondition,
                          dropdownColor: Colors.grey[900],
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              Center(child: Text(condSymbol, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                              Center(child: Text(condSymbol, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                              Center(child: Text(condSymbol, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                            ];
                          },
                          items: const [
                            DropdownMenuItem(value: ">=", child: Text("≥ దాటినా", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "<=", child: Text("≤ తగ్గినా", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "==", child: Text("= అదే", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedCondition = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "రేటు (1.20)",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black38,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAlarmRinging ? Colors.black : (isAlarmSet ? Colors.orange[800] : Colors.green[700]),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                            targetTeam = _teamController.text.trim();
                            isAlarmSet = true;
                            currentStatus = targetTeam.isNotEmpty
                                ? "🟢 $targetTeam (Back $condSymbol $targetRate) కోసం ట్రాకింగ్..."
                                : "🟢 Back $condSymbol $targetRate కోసం ట్రాకింగ్...";
                          });
                          startMonitoring();
                        }
                      },
                      child: Text(
                        isAlarmRinging ? "STOP" : (isAlarmSet ? "CANCEL" : "SET"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
                mediaPlaybackRequiresUserGesture: false,
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
