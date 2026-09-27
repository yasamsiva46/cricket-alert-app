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
    home: CrexProOddsApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class CrexProOddsApp extends StatefulWidget {
  const CrexProOddsApp({super.key});

  @override
  State<CrexProOddsApp> createState() => _CrexProOddsAppState();
}

class _CrexProOddsAppState extends State<CrexProOddsApp> {
  InAppWebViewController? webViewController;
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  
  final AudioPlayer _alarmPlayer = AudioPlayer();
  final AudioPlayer _silentKeepAlivePlayer = AudioPlayer();

  bool isAlarmSet = false;
  bool isAlarmRinging = false;
  bool isBlackScreenActive = false;
  double? targetRate;
  String targetTeam = "";
  String selectedCondition = ">=";
  Timer? _rateCheckTimer;
  String currentStatus = "Crex Live Ready";
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

    // బ్యాటరీ & హీట్ తగ్గించడానికి ప్రతి 2 సెకన్లకు ఒకసారి మాత్రమే చెక్ చేస్తుంది
    _rateCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
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

          // స్కోర్ బోర్డు, హెడర్, బౌలర్, బ్యాటర్, ఓవర్ల పదాలను పూర్తిగా బ్లాక్ చేసే లిస్ట్
          const forbiddenRegex = /CRR|RRR|Over|Overs|Wicket|Wkt|W-R|Econ|Economy|Batter|Bowler|P'ship|Partnership|Last Wkt|Commentary|Scorecard|Match info|GET APP|Discussion|Points Table|\bvs\b|ODI|T20|Test|\bDay\b|Target|opt to bat|won the toss/i;

          let allDivs = Array.from(document.querySelectorAll('div, tr, li'));
          let validOddsRows = [];

          for (let el of allDivs) {
            if (el.children.length === 0 || el.children.length > 10) continue;

            let fullText = (el.innerText || '').trim();
            if (!fullText) continue;

            // ఓవర్లు లేదా స్కోర్ బోర్డు పదాలు ఉంటే వెంటనే రిజెక్ట్ చేయి
            if (forbiddenRegex.test(fullText)) continue;
            if (fullText.includes('(') || fullText.includes(')') || fullText.includes('=')) continue;

            let leaves = Array.from(el.querySelectorAll('*')).filter(leaf => {
              return leaf.children.length === 0 && leaf.innerText && leaf.innerText.trim().length > 0;
            });

            if (leaves.length < 2 || leaves.length > 8) continue;

            let numberLeaves = [];
            let textLeaves = [];

            for (let leaf of leaves) {
              let txt = leaf.innerText.trim();
              // కేవలం సరైన మార్కెట్ రేట్లను మాత్రమే లెక్కించు (1.01 నుండి 500 వరకు)
              // 1.0 లాంటి ఓవర్లను ఇది తీసుకోదు
              if (/^[0-9]+(\.[0-9]+)?$/.test(txt)) {
                let n = parseFloat(txt);
                if (!isNaN(n) && n > 1.01 && n <= 500) {
                  numberLeaves.push({ element: leaf, val: n, str: txt });
                  continue;
                }
              }
              textLeaves.push(txt);
            }

            // మార్కెట్ రేట్ల టేబుల్ లో ఖచ్చితంగా 1 లేదా 2 రేట్లు మరియు టీమ్ పేరు ఉంటాయి
            if (numberLeaves.length >= 1 && numberLeaves.length <= 3 && textLeaves.length >= 1) {
              let combinedText = textLeaves.join(' ').toLowerCase();
              if (forbiddenRegex.test(combinedText)) continue;

              validOddsRows.push({
                container: el,
                odds: numberLeaves,
                teamText: combinedText,
                teamLeaves: textLeaves
              });
            }
          }

          let specificRows = validOddsRows.filter(row => {
            return !validOddsRows.some(other => other !== row && row.container.contains(other.container));
          });

          for (let row of specificRows) {
            let rowText = row.teamText;
            let words = rowText.split(/[^a-zA-Z0-9]+/).filter(w => w.length > 0);

            let isTeamMatched = false;
            if (filterTeam.length > 0) {
              isTeamMatched = words.some(w => w === filterTeam || (filterTeam.length >= 3 && (w.includes(filterTeam) || filterTeam.includes(w))));
              if (!isTeamMatched) continue;
            }

            let displayTeam = row.teamLeaves[0] || filterTeam.toUpperCase();
            let shortBadge = row.teamLeaves.find(t => t.length >= 2 && t.length <= 4 && /^[A-Z]+$/i.test(t));
            if (shortBadge) displayTeam = shortBadge.toUpperCase();

            // రేటు ఇవ్వకపోతే - టీమ్ నిజంగా మార్కెట్ రేట్లలోకి రాగానే అలారమ్
            if (target === null) {
              let ratesSummary = row.odds.map(o => o.str).join(' - ');
              return JSON.stringify({
                found: true,
                team: displayTeam,
                rate: ratesSummary,
                onlyTeam: true
              });
            }

            // రేటు ఇస్తే - నిర్దిష్ట రేటు తాకినప్పుడు అలారమ్
            for (let o of row.odds) {
              let num = o.val;
              let isMatch = false;
              if (condition === '>=') {
                isMatch = (num >= (target - 0.0001));
              } else if (condition === '<=') {
                isMatch = (num > 0 && num <= (target + 0.0001));
              }

              if (isMatch) {
                return JSON.stringify({
                  found: true,
                  team: displayTeam,
                  rate: o.str,
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
      isBlackScreenActive = false;
      isAlarmRinging = true;
      if (onlyTeam) {
        matchedInfo = "$team మార్కెట్‌లోకి వచ్చింది! ($rate)";
        currentStatus = "🚨 $matchedInfo";
      } else {
        matchedInfo = "$team (రేటు: $rate)";
        currentStatus = "🚨 రేటు తాకింది: $matchedInfo";
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
      isBlackScreenActive = false;
      matchedInfo = "";
      currentStatus = "అలారమ్ ఆఫ్ చేయబడింది";
    });
  }

  void testSound() async {
    if (isAlarmRinging) {
      stopAlarm();
      return;
    }
    if (_beepBytes != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔊 సౌండ్ టెస్ట్ అవుతోంది..."), duration: Duration(seconds: 2)),
      );
      await _alarmPlayer.play(BytesSource(_beepBytes!), volume: 1.0);
      await Future.delayed(const Duration(seconds: 3));
      await _alarmPlayer.stop();
    }
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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B2E),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF00FFA3), size: 22),
            const SizedBox(width: 6),
            const Text(
              "CREX PRO",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber, width: 0.8),
              ),
              child: const Text("PRO", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.nightlight_round, color: Colors.cyanAccent),
            tooltip: "నైట్ మోడ్ (బ్లాక్ స్క్రీన్)",
            onPressed: () {
              setState(() {
                isBlackScreenActive = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.amber),
            tooltip: "సౌండ్ టెస్ట్",
            onPressed: testSound,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => webViewController?.reload(),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlarmRinging ? Colors.red[900] : const Color(0xFF131B2E),
                  border: Border(bottom: BorderSide(color: isAlarmRinging ? Colors.redAccent : const Color(0xFF263352))),
                ),
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
                              hintText: "టీం (RS/BT)",
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF0A0E1A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCondition,
                              dropdownColor: const Color(0xFF131B2E),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                              selectedItemBuilder: (BuildContext context) {
                                return [
                                  Center(child: Text(isUp ? "↑" : "↓", style: TextStyle(color: isUp ? const Color(0xFF00FFA3) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 19))),
                                  Center(child: Text(isUp ? "↑" : "↓", style: TextStyle(color: isUp ? const Color(0xFF00FFA3) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 19))),
                                ];
                              },
                              items: const [
                                DropdownMenuItem(value: ">=", child: Text("↑ పెరిగితే", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 12))),
                                DropdownMenuItem(value: "<=", child: Text("↓ తగ్గితే", style: TextStyle(color: Colors.redAccent, fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => selectedCondition = val);
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
                              hintText: "రేటు (ఆప్షనల్)",
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 9),
                              filled: true,
                              fillColor: const Color(0xFF0A0E1A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAlarmRinging ? Colors.white : (isAlarmSet ? Colors.orange[800] : const Color(0xFF00FFA3)),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            if (isAlarmRinging) {
                              stopAlarm();
                              return;
                            }

                            String teamEntered = _teamController.text.trim();
                            double? rateEntered = double.tryParse(_rateController.text.trim());

                            if (teamEntered.isEmpty && rateEntered == null) return;

                            FocusScope.of(context).unfocus();
                            setState(() {
                              targetRate = rateEntered;
                              targetTeam = teamEntered;
                              isAlarmSet = true;

                              if (rateEntered == null) {
                                currentStatus = "🟢 $targetTeam మార్కెట్‌లోకి రాగానే అలారమ్...";
                              }
