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
    home: CrexOddsAlarmApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class CrexOddsAlarmApp extends StatefulWidget {
  const CrexOddsAlarmApp({super.key});

  @override
  State<CrexOddsAlarmApp> createState() => _CrexOddsAlarmAppState();
}

class _CrexOddsAlarmAppState extends State<CrexOddsAlarmApp> {
  InAppWebViewController? webViewController;
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  
  final AudioPlayer _alarmPlayer = AudioPlayer();
  final AudioPlayer _silentKeepAlivePlayer = AudioPlayer();

  bool isAlarmSet = false;
  bool isAlarmRinging = false;
  double? targetRate;
  String targetTeam = "";
  String selectedCondition = ">="; // డిఫాల్ట్‌గా '↑' (పెరిగితే)
  Timer? _rateCheckTimer;
  String currentStatus = "Crex సిద్ధంగా ఉంది";
  String matchedInfo = "";
  
  Uint8List? _beepBytes;
  Uint8List? _silentBytes;

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

      String teamQuery = targetTeam.replaceAll("'", "\\'").toLowerCase().trim();
      String cond = selectedCondition;

      // Dart స్ట్రింగ్ ఎర్రర్స్ రాకుండా Raw JS స్క్రిప్ట్
      String jsScript = r'''
        (function() {
          let target = __TARGET__;
          let filterTeam = '__TEAM__';
          let condition = '__COND__';

          let allElements = Array.from(document.querySelectorAll('*'));
          let matchingTeamNodes = [];

          for (let el of allElements) {
            if (el.children.length === 0 || el.children.length <= 2) {
              let txt = el.innerText ? el.innerText.trim().toLowerCase() : '';
              if (filterTeam.length > 0 && (txt === filterTeam || (txt.length >= 2 && txt.includes(filterTeam)))) {
                let isStats = el.closest('table, tbody, [class*="scorecard"], [class*="batter"], [class*="bowler"]');
                if (!isStats) {
                  matchingTeamNodes.push(el);
                }
              }
            }
          }

          if (filterTeam.length > 0 && matchingTeamNodes.length === 0) {
            return JSON.stringify({ found: false });
          }

          let targetRows = [];
          if (matchingTeamNodes.length > 0) {
            for (let node of matchingTeamNodes) {
              let p = node.parentElement;
              for (let i = 0; i < 4; i++) {
                if (!p || p === document.body) break;
                let text = p.innerText.trim();
                if (!/batter|bowler|overs|p'ship/i.test(text)) {
                  targetRows.push(p);
                  break;
                }
                p = p.parentElement;
              }
            }
          } else {
            targetRows = [document.body];
          }

          for (let row of targetRows) {
            let potentialOdds = Array.from(row.querySelectorAll('*')).filter(e => {
              if (e.children.length > 0) return false;
              let val = e.innerText ? e.innerText.trim() : '';
              if (!val || val.length > 5 || val.indexOf('-') !== -1) return false;
              let n = Number(val);
              return !isNaN(n) && n > 0;
            });

            for (let box of potentialOdds) {
              let num = parseFloat(box.innerText.trim());
              if (isNaN(num)) continue;

              let isMatch = false;
              if (condition === '>=') {
                // ↑ రేటు పెరిగితే లేదా దాటితే
                isMatch = (num >= (target - 0.0001));
              } else if (condition === '<=') {
                // ↓ రేటు తగ్గితే లేదా పడిపోతే
                isMatch = (num > 0 && num <= (target + 0.0001));
              }

              if (isMatch) {
                return JSON.stringify({
                  found: true,
                  team: filterTeam.toUpperCase() || 'CREX',
                  rate: box.innerText.trim()
                });
              }
            }
          }

          return JSON.stringify({ found: false });
        })();
      '''
      .replaceAll('__TARGET__', targetRate.toString())
      .replaceAll('__TEAM__', teamQuery)
      .replaceAll('__COND__', cond);

      var result = await webViewController!.evaluateJavascript(source: jsScript);

      if (result != null && result.toString().isNotEmpty) {
        try {
          var data = jsonDecode(result.toString());
          if (data["found"] == true && !isAlarmRinging) {
            triggerAlarm(data["team"], data["rate"]);
          }
        } catch (_) {}
      }
    });
  }

  void triggerAlarm(String team, String rate) async {
    await _silentKeepAlivePlayer.stop();

    setState(() {
      isAlarmRinging = true;
      matchedInfo = "$team (రేటు: $rate)";
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
    bool isUp = selectedCondition == ">=";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: const Text("🏏 Crex Odds Alarm", style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => webViewController?.reload(),
          )
        ],
      ),
      body: Column(
        children: [
          // అలారమ్ కంట్రోలర్ బార్
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isAlarmRinging ? Colors.red[800] : Colors.blueGrey[800],
            child: Column(
              children: [
                Row(
                  children: [
                    // 1. టీం బాక్స్ (ఉదా: RS)
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _teamController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "టీం (RS)",
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

                    // 2. కేవలం రెండే ఆప్షన్లు: ↑ (పెరిగితే) లేదా ↓ (తగ్గితే)
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
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              Center(
                                child: Text(
                                  isUp ? "↑" : "↓",
                                  style: TextStyle(
                                    color: isUp ? Colors.greenAccent : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  isUp ? "↑" : "↓",
                                  style: TextStyle(
                                    color: isUp ? Colors.greenAccent : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ];
                          },
                          items: const [
                            DropdownMenuItem(
                              value: ">=",
                              child: Row(
                                children: [
                                  Text("↑", style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 6),
                                  Text("పెరిగితే", style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "<=",
                              child: Row(
                                children: [
                                  Text("↓", style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 6),
                                  Text("తగ్గితే", style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
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

                    // 3. రేటు బాక్స్ (ఉదా: 20)
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "రేటు (20)",
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

                    // 4. SET / STOP బటన్
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
                          String arrowText = selectedCondition == ">=" ? "↑ పెరిగితే" : "↓ తగ్గితే";
                          setState(() {
                            targetRate = entered;
                            targetTeam = _teamController.text.trim();
                            isAlarmSet = true;
                            currentStatus = targetTeam.isNotEmpty
                                ? "🟢 $targetTeam వద్ద రేటు $targetRate ($arrowText) అలారమ్..."
                                : "🟢 రేటు $targetRate ($arrowText) అలారమ్...";
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

          // Crex వెబ్‌సైట్
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://crex.com/"),
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
