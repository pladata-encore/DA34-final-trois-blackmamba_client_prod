import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivetalk/car_selection_screen.dart';
import 'package:drivetalk/talk_screen.dart';
import 'package:drivetalk/utterance_screen.dart';
import 'package:drivetalk/device_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: BasicScreen(),
    );
  }
}

class BasicScreen extends StatefulWidget {
  const BasicScreen({super.key});

  @override
  State<BasicScreen> createState() => _BasicScreenState();
}

class _BasicScreenState extends State<BasicScreen> {
  var bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final deviceService = Provider.of<DeviceService>(context, listen: false);

    // Load uid from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid');
    deviceService.uid = uid;
    final cid = prefs.getInt('cid');
    deviceService.cid = cid;

    // Set the initial bottomNavIndex based on uid
    print("Loaded uid value: ${deviceService.uid}");
    setState(() {
      bottomNavIndex = (deviceService.uid == null) ? 2 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        UtteranceScreen(),
        TalkScreen(),
        CarSelectionScreen(),
      ].elementAt(bottomNavIndex),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 28,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() {
            bottomNavIndex = value;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: '음성입력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: '차량',
          ),
        ],
        currentIndex: bottomNavIndex,
      ),
    );
  }
}
