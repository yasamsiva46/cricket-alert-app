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
  String selectedCondition = ">=";
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
      if (webViewController == null || !isAlarmSet) return;
      if (targetTeam.isEmpty && targetRate == null) return;

      String teamQuery = targetTeam.replaceAll("'", "\\'").toLowerCase().trim();
      String cond = selectedCondition;
      String targetParam = targetRate != null ? targetRate.toString() : "null";

      String jsScript = r'''
        (function() {
          let target = __TARGET__;
          let filterTeam = '__TEAM__';
          let condition = '__COND__';

          let allContainers = Array.from(document.querySelectorAll('div, tr, li'));
          let candidateRows = [];

          for (let el of allContainers) {
            if (el.children.length === 0 || el.children.length > 12) continue;

            let fullTxt = el.innerText ? el.innerText.trim() : '';
            if (!fullTxt) continue;

            if (/CRR|Scorecard|Commentary|Batter|Bowler|P'ship|GET APP|Match info/i.test(fullTxt)) {
              continue;
            }

            let oddsLeaves = Array.from(el.querySelectorAll('*')).filter(leaf => {
              if (leaf.children.length > 0) return false;
              let v = leaf.innerText ? leaf.innerText.trim() : '';
              return /^[0-9]+(\.[0-9]+)?$/.test(v) && v.length <= 5 && !v.includes('-');
            });

            if (oddsLeaves.length >= 1 && oddsLeaves.length <= 4) {
              candidateRows.push({
                container: el,
                leaves: oddsLeaves,
                text: fullTxt.toLowerCase()
              });
            }
          }

          candidateRows.sort((a, b) => a.text.length - b.text.length);

          for (let row of candidateRows) {
            let teamOnlyText = row.text;
            row.leaves.forEach(l => {
              teamOnlyText = teamOnlyText.replace(l.innerText.trim().toLowerCase(), '');
            });

            let words = teamOnlyText.split(/[^a-zA-Z0-9]+/).filter(w => w.length > 0);
            
            let isTeamMatched = false;
            if (filterTeam.length > 0) {
              isTeamMatched = words.some(w => w === filterTeam || (filterTeam.length >= 3 && w.includes(filterTeam)));
              if (!isTeamMatched) {
                continue;
              }
            }

            for (let box of row.leaves) {
              let valStr = box.innerText.trim();
              let num = parseFloat(valStr);
              if (isNaN(num)) continue;

              // 1. కేవలం టీమ్ మాత్రమే సెట్ చేసినప్పుడు (రేటు ఏదైనా సరే మోగుతుంది)
              if (target === null) {
                return JSON.stringify({
                  found: true,
                  team: filterTeam.toUpperCase() || words[0]?.toUpperCase() || 'CREX',
                  rate: valStr,
                  onlyTeam: true
                });
              }

              // 2. టీమ్ + రేటు రెండూ సెట్ చేసినప్పుడు
              let isMatch = false;
              if (condition === '>=') {
                isMatch = (num >= (target - 0.0001));
              } else if (condition === '<=') {
                isMatch = (num > 0 && num <= (target + 0.0001));
              }

              if (isMatch) {
                return JSON.stringify({
                  found: true,
                  team: filterTeam.toUpperCase() || words[0]?.toUpperCase() || 'CREX',
                  rate: valStr,
                  onlyTeam: false
                });
              }
            }
          }

          return JSON.stringify({ found: false });
        })();
      '''
      .replaceAll('__TARGET__', targetParam)
      .replaceAll('__TEAM__', teamQuery)
      .replaceAll('__COND__', cond);

      var result = await webViewController!.evaluateJavascript(source: jsScript);

      if (result != null && result.toString().isNotEmpty) {
        try {
          var data = jsonDecode(result.toString());
          if (data["found"] == true && !isAlarmRinging) {
            triggerAlarm(data["team"], data["rate"], data["onlyTeam"] == true);
          }
        } catch (_) {}
      }
    });
  }

  void triggerAlarm(String team, String rate, bool onlyTeam) async {
    await _silentKeepAlivePlayer.stop();

    setState(() {
      isAlarmRinging = true;
      if (onlyTeam) {
        matchedInfo = "$team లైవ్ రేట్లలోకి వచ్చింది! (రేటు: $rate)";
        currentStatus = "🚨 $matchedInfo";
      } else {
        matchedInfo = "$team (రేటు: $rate)";
        currentStatus = "🚨 రేటు వచ్చింది: $matchedInfo";
      }
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isAlarmRinging ? Colors.red[800] : Colors.blueGrey[800],
            child: Column(
              children: [
                Row(
                  children: [
                    // 1. టీం బాక్స్
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _teamController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "టీం (BT/RS)",
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

                    // 2. ↑ (పెరిగితే) / ↓ (తగ్గితే)
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

                    // 3. రేటు బాక్స్ (ఆప్షనల్)
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "రేటు (ఆప్షనల్)",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                          filled: true,
                          fillColor: Colors.black38,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 4. బటన్
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

                        String teamEntered = _teamController.text.trim();
                        double? rateEntered = double.tryParse(_rateController.text.trim());

                        if (teamEntered.isEmpty && rateEntered == null) {
                          return;
                        }

                        FocusScope.of(context).unfocus();
                        setState(() {
                          targetRate = rateEntered;
                          targetTeam = teamEntered;
                          isAlarmSet = true;

                          if (rateEntered == null) {
                            currentStatus = "🟢 $targetTeam లైవ్ రేట్లలోకి రాగానే అలారమ్...";
                          } else {
                            String arrowText = selectedCondition == ">=" ? "↑ పెరిగితే" : "↓ తగ్గితే";
                            currentStatus = targetTeam.isNotEmpty
                                ? "🟢 $targetTeam వద్ద రేటు $targetRate ($arrowText) అలారమ్..."
                                : "🟢 రేటు $targetRate ($arrowText) అలారమ్...";
                          }
                        });
                        startMonitoring();
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
