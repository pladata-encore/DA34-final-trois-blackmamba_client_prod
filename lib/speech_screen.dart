import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SpeechScreen extends StatefulWidget {
  final String? initialText;

  const SpeechScreen({super.key, this.initialText});

  @override
  _SpeechScreenState createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final Dio dio = Dio();
  String recognizedText = "듣고 있어요...";
  String responseText = "";
  String backButtonText = "뒤로가기";
  Timer? countdownTimer;
  int uid = 0;
  String selectedCarName = "";
  bool isMusicPlaying = false;
  bool isLoading = false; // New loading state variable
  YoutubePlayerController? _youtubePlayerController;
  final List<String> musicKeywords = [
    "틀어줘",
    "틀어 줘",
    "들려줘",
    "들려 줘",
    "재생해줘",
    "음악",
    "재생",
    "노래",
    "영상"
  ];

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _youtubePlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    await _loadDevice();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setSpeechRate(0.5);

    if (widget.initialText != null) {
      recognizedText = widget.initialText!;
      _handleRecognizedText(recognizedText);
    } else {
      _speak("네, 말씀하세요");
    }
  }

  Future<void> _loadDevice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uid = prefs.getInt('uid') ?? 0;
      selectedCarName = prefs.getString('selectedCarName') ?? "";
      print("로드한 uid는 $uid");
      print("로드한 selectedCarName은 $selectedCarName");
    });
  }

  Future<void> _speak(String text) async {
    print('TTS 방송이 시작됩니다.');
    var trimText = text.replaceAll(RegExp(r'[^\w\s가-힣,.!?]'), '');
    await flutterTts.speak(trimText);
    flutterTts.setCompletionHandler(() {
      print('TTS 방송이 끝납니다.');
      if (text == "네, 말씀하세요") {
        _listen();
      } else if (!isMusicPlaying) {
        _startCountdown();
      }
    });
  }

  void _stopTTS() async {
    await flutterTts.stop();
    print('TTS 방송이 중단되었습니다.');
  }

  void _listen() async {
    bool available = await speech.initialize();
    if (available) {
      speech.listen(onResult: (result) {
        setState(() {
          recognizedText = result.recognizedWords;
        });
        if (result.finalResult) {
          _handleRecognizedText(recognizedText);
        }
      });
    } else {
      setState(() {
        recognizedText = "Speech recognition not available";
      });
    }
  }

  void _handleRecognizedText(String text) {
    if (_containsMusicKeyword(text)) {
      String searchText = _removeMusicKeywords(text).trim();
      _playMusic(searchText);
    } else {
      _sendRequestToAPI(text);
    }
    _saveMessageToServer(text, 1);
  }

  bool _containsMusicKeyword(String text) {
    return musicKeywords.any((keyword) => text.contains(keyword));
  }

  String _removeMusicKeywords(String text) {
    return musicKeywords.fold(
        text, (prev, keyword) => prev.replaceAll(keyword, ""));
  }

  Future<void> _playMusic(String query) async {
    await dotenv.load(fileName: ".env");
    String? youtubeApiKey = dotenv.env['YOUTUBE_API_KEY'];
    var url =
        'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&key=$youtubeApiKey';

    try {
      var response = await dio.get(url);
      if (response.statusCode == 200) {
        var jsonResponse = response.data;
        var videoId = jsonResponse['items'][0]['id']['videoId'];
        var videoTitle = jsonResponse['items'][0]['snippet']['title']
            .replaceAll(RegExp(r'[^\w\s가-힣,.!?]'), '');

        _youtubePlayerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(autoPlay: true, mute: false),
        );

        _youtubePlayerController!.addListener(() {
          if (_youtubePlayerController!.value.playerState ==
              PlayerState.ended) {
            _startCountdown();
          }
        });

        setState(() {
          isMusicPlaying = true;
          responseText = "$videoTitle 을(를) 재생합니다.";
          _saveMessageToServer(responseText, 2);
        });

        print('TTS 방송이 시작됩니다.');
        await flutterTts.speak(responseText);
        flutterTts.setCompletionHandler(() {
          print('TTS 방송이 끝납니다.');
        });
      } else {
        print("Failed to load video.");
        _showErrorDialog('음악을 재생하는 데 실패했습니다. 다시 시도해 주세요.');
      }
    } catch (e) {
      print("Failed to load video: $e");
      _showErrorDialog('네트워크 오류가 발생했습니다. 인터넷 연결을 확인해 주세요.');
    }
  }

  Future<void> _stopMusic() async {
    _youtubePlayerController?.pause();
    setState(() {
      isMusicPlaying = false;
    });
    _navigateBack();
  }

  Future<void> _sendRequestToAPI(String query) async {
    setState(() {
      isLoading = true; // Start loading
    });

    // var url =
    //     'https://2tcihkmmep.ap-northeast-1.awsapprunner.com/query?query=$query';
    var url = 'https://langchain-j5mv4ohetq-du.a.run.app/query?query=$query';

    try {
      var response = await dio.get(url);
      if (response.statusCode == 200) {
        var jsonResponse = response.data;
        setState(() {
          responseText = jsonResponse['answer'].trim();
        });
      } else {
        _handleAPIFailure();
      }
    } catch (e) {
      print("Failed to send request: $e");
      _handleAPIFailure();
      _showErrorDialog('네트워크 오류가 발생했습니다. 인터넷 연결을 확인해 주세요.');
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }

    print('TTS 방송이 시작됩니다.');
    print("응답텍스트 : $responseText");
    var trimText = responseText.replaceAll(RegExp(r'[^\w\s가-힣,.!?]'), '');
    await flutterTts.speak(trimText);
    flutterTts.setCompletionHandler(() {
      print('TTS 방송이 끝납니다.');
      if (!isMusicPlaying) {
        _startCountdown();
      }
    });

    _saveMessageToServer("$selectedCarName $responseText", 2);
  }

  void _handleAPIFailure() {
    setState(() {
      responseText = "저도 잘 모르겠어요. 좀 더 열심히 공부할께요.";
    });
  }

  Future<void> _saveMessageToServer(String message, int userId) async {
    var truncatedMessage =
        message.length > 500 ? message.substring(0, 500) : message;

    var data = {
      'text': truncatedMessage,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'uid': uid,
    };

    print("저장하는 메시지 내용은 $data");

    try {
      await dio.post('https://drivetalk-app-j5mv4ohetq-du.a.run.app/messages',
          data: data);
      print("메시지 저장에 성공했습니다.");
    } catch (e) {
      print("Failed to save message: $e");
      _showErrorDialog('메시지를 저장하는 데 실패했습니다. 네트워크 연결을 확인해 주세요.');
    }
  }

  void _startCountdown() {
    int countdown = 3;
    setState(() {
      backButtonText = "뒤로가기 ($countdown)";
    });

    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
        if (countdown > 0) {
          backButtonText = "뒤로가기 ($countdown)";
        } else {
          backButtonText = "뒤로가기";
          timer.cancel();
          _navigateBack();
        }
      });
    });
  }

  void _navigateBack() {
    Navigator.of(context).pop();
  }

  void _onBackButtonPressed() {
    _stopTTS();
    _navigateBack();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('네트워크 오류'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatBubble(
      String text, Color backgroundColor, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("음성 인식"),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "네, 말씀하세요",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildChatBubble(recognizedText, Colors.grey.shade200,
                            Alignment.centerLeft),
                        SizedBox(height: 20),
                        _buildChatBubble(responseText, Colors.blue.shade100,
                            Alignment.centerRight),
                        if (isLoading) // Display spinner when loading
                          Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _onBackButtonPressed,
                  child: Text(backButtonText),
                ),
              ],
            ),
          ),
          if (isMusicPlaying)
            Positioned(
              bottom: 16.0,
              right: 16.0,
              child: FloatingActionButton(
                onPressed: _stopMusic,
                child: Icon(Icons.stop),
              ),
            ),
          if (isMusicPlaying && _youtubePlayerController != null)
            Positioned(
              bottom: 70.0,
              left: 0.0,
              right: 0.0,
              child: SizedBox(
                height: 200.0,
                child: YoutubePlayer(
                  controller: _youtubePlayerController!,
                  showVideoProgressIndicator: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
