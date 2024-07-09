import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TalkScreen extends StatefulWidget {
  @override
  _TalkScreenState createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  bool isListening = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  FlutterTts flutterTts = FlutterTts();
  final Dio dio = Dio();
  int skip = 0;
  bool isLoadingMore = false;
  int uid = 0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadUid();
    flutterTts.setLanguage("ko-KR");
    flutterTts.setSpeechRate(0.5);
  }

  Future<void> _loadUid() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uid = prefs.getInt('uid') ?? 0;
      print("로드한 uid는 $uid");
    });
    _loadMessages();
  }

  ChatUser user1 = ChatUser(
    id: '1',
    firstName: 'me',
    lastName: 'me',
  );
  ChatUser user2 = ChatUser(
      id: '2',
      firstName: 'drivetalk',
      lastName: 'switchup',
      profileImage: "assets/img/drivetalk_icon.png");

  List<ChatMessage> messages = <ChatMessage>[];

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        isLoadingMore = true;
      });
    }

    try {
      var response = await dio.get(
        'https://drivetalk-app-j5mv4ohetq-du.a.run.app/messages',
        queryParameters: {'uid': uid, 'skip': skip, 'limit': 30},
      );

      if (response.statusCode == 200) {
        List<ChatMessage> newMessages = (response.data as List)
            .map((json) => ChatMessage(
                  text: json['text'],
                  user: json['user_id'] == 1 ? user1 : user2,
                  createdAt: DateTime.parse(json['created_at']),
                ))
            .toList();

        setState(() {
          if (loadMore) {
            messages.addAll(newMessages);
            isLoadingMore = false;
          } else {
            messages = newMessages;
          }
          skip += 30;
        });
        print("메시지 로드에 성공했습니다.");
      }
    } catch (e) {
      print("Failed to load messages: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화창'),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!isLoadingMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadMessages(loadMore: true);
          }
          return false;
        },
        child: DashChat(
          currentUser: user1,
          onSend: (ChatMessage m) async {
            setState(() {
              messages.insert(0, m);
            });
            await _saveMessageToServer(m);
            Future<String> data = sendMessageToServer(m.text);
            data.then((value) {
              setState(() {
                ChatMessage replyMessage = ChatMessage(
                  text: value,
                  user: user2,
                  createdAt: DateTime.now(),
                );
                messages.insert(0, replyMessage);
                _saveMessageToServer(replyMessage);
              });
            });
          },
          messages: messages,
          inputOptions: InputOptions(leading: [
            IconButton(
                icon: Icon(Icons.mic,
                    color: isListening ? Colors.red : Colors.black),
                onPressed: () {
                  setState(() {
                    isListening = !isListening;
                    if (isListening == true) {
                      print('음성인식 시작');
                      _startListening();
                    } else {
                      print('음성인식 끝');
                      _stopListening();
                    }
                  });
                }),
          ]),
        ),
      ),
    );
  }

  Future<void> _saveMessageToServer(ChatMessage message) async {
    var truncatedMessage =
        message.text.length > 500 ? message.text.substring(0, 500) : message;

    var data = {
      // 'id': messages.length + 1,
      'text': message.text,
      'user_id': message.user.id == '1' ? 1 : 2,
      'created_at': message.createdAt.toIso8601String(),
      'uid': uid,
    };
    print("저장하는 메시지 내용은 $data");

    try {
      await dio.post(
        'https://drivetalk-app-j5mv4ohetq-du.a.run.app/messages',
        data: data,
      );
      print("메시지 저장에 성공했습니다.");
    } catch (e) {
      print("Failed to save message: $e");
    }
  }

  Future<String> sendMessageToServer(String message) async {
    String requestUrl =
        'https://langchain-j5mv4ohetq-du.a.run.app/query?query=$message';

    try {
      var response = await dio.get(requestUrl);

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = response.data;
        String result = jsonResponse['answer'] ?? "저도 잘 모르겠어요. 좀 더 열심히 공부할께요.";
        print(response.data);
        return result;
      } else {
        print(response.statusMessage);
        return "ERROR";
      }
    } catch (e) {
      print("Failed to send request: $e");
      return "ERROR";
    }
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    print("음성인식 기능을 시작합니다.");
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    print("음성인식을 시작합니다.");
    await _speechToText.listen(onResult: _onSpeechResult);
    // setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    print("음성인식을 종료합니다.");
    await _speechToText.stop();
    // setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = "";
    if (result.finalResult) {
      _lastWords = result.recognizedWords;
      print("최종 인식된 문장: $_lastWords");

      setState(() {
        ChatMessage userMessage = ChatMessage(
          text: _lastWords,
          user: user1,
          createdAt: DateTime.now(),
        );
        messages.insert(0, userMessage);
        _saveMessageToServer(userMessage);
        print("$messages");
      });

      Future<String> data = sendMessageToServer(_lastWords);
      data.then((value) {
        setState(() {
          ChatMessage replyMessage = ChatMessage(
            text: value,
            user: user2,
            createdAt: DateTime.now(),
          );
          messages.insert(0, replyMessage);
          _saveMessageToServer(replyMessage);
          print("$messages");
        });
        flutterTts.speak(value);
      });
    }
  }
}
