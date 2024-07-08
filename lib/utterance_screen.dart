import 'package:drivetalk/speech_screen.dart';
import 'package:flutter/material.dart';

class UtteranceScreen extends StatelessWidget {
  const UtteranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '아래의 버튼을 누르고\n드라이브톡에게 물어보세요.',
                style: TextStyle(
                  fontSize: 25, // 폰트 크기
                  fontWeight: FontWeight.bold, // 폰트 두께
                  color: Colors.black, // 폰트 색상
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SpeechScreen()),
                  );
                },
                child: Image.asset(
                  'assets/img/mic.png', // 이미지 경로
                  width: 250,
                  height: 250, // 이미지 높이 조절
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '음성 명령 예시',
                style: TextStyle(
                  fontSize: 20, // 폰트 크기
                  fontWeight: FontWeight.normal, // 폰트 두께
                  color: Colors.black, // 폰트 색상
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SpeechScreen(initialText: '엔진오일 교환주기 알려줘'),
                    ),
                  );
                },
                child: Text('엔진오일 교환주기 알려줘'),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SpeechScreen(initialText: '뉴진스 하우스윗 틀어줘'),
                    ),
                  );
                },
                child: Text('뉴진스 하우스윗 틀어줘'),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SpeechScreen(initialText: '성수동 햄버거 맛집 알려줘'),
                    ),
                  );
                },
                child: Text('성수동 햄버거 맛집 알려줘'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
