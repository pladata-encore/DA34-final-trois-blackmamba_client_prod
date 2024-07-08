import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io'; // For Platform check
import 'package:drivetalk/device_service.dart';
import 'package:drivetalk/home_screen.dart';

class CarSelectionScreen extends StatefulWidget {
  const CarSelectionScreen({super.key});

  @override
  State<CarSelectionScreen> createState() => _CarSelectionScreenState();
}

class _CarSelectionScreenState extends State<CarSelectionScreen> {
  bool _noCarSelected = false;
  String? _selectedCarCompany;
  String? _selectedCarName;
  CarInfo? _selectedCarInfo;

  @override
  void initState() {
    super.initState();
    _initializeSelection().catchError((error) {
      print("Failed to initialize selection: $error");
      _showErrorDialog('초기화 중 오류가 발생했습니다. 네트워크 연결을 확인해 주세요.');
    });
  }

  Future<void> _initializeSelection() async {
    await _fetchCarMenuList();
    await _loadSelection();
    setState(() {});
  }

  Future<String> _getUserAgent() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String userAgent;

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      userAgent =
          "Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; ${androidInfo.model}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${androidInfo.version.sdkInt} Mobile Safari/537.36";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      userAgent =
          "Mozilla/5.0 (iPhone; CPU iPhone OS ${iosInfo.systemVersion.replaceAll('.', '_')} like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/${iosInfo.systemVersion} Mobile/${iosInfo.identifierForVendor} Safari/604.1";
    } else {
      userAgent =
          "Mozilla/5.0 (compatible; MyApp/1.0; +http://example.com/bot)";
    }

    return userAgent;
  }

  Future<void> _fetchCarMenuList() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      deviceService.carData = await deviceService.getCarMenuList();
      print("Loaded car data: ${deviceService.carData}");
      print("Current cid value: ${deviceService.cid}");
      print("Current uid value: ${deviceService.uid}");
    } catch (e) {
      print("Failed to fetch car menu list: $e");
      _showErrorDialog('차량 목록을 불러오는 데 실패했습니다. 네트워크 연결을 확인해 주세요.');
    }
  }

  Future<void> _loadSelection() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // noCarSelected 값 로드
      _noCarSelected = prefs.getBool('noCarSelected') ?? false;
      print("Loaded noCarSelected: $_noCarSelected");

      // selectedCarCompany 값 로드
      _selectedCarCompany = prefs.getString('selectedCarCompany');
      print("Loaded selectedCarCompany: ${_selectedCarCompany ?? 'null'}");

      // selectedCarName 값 로드
      _selectedCarName = prefs.getString('selectedCarName');
      print("Loaded selectedCarName: ${_selectedCarName ?? 'null'}");

      // selectedCarInfo 값 로드
      String? jsonString = prefs.getString('selectedCarInfo');
      if (jsonString != null) {
        try {
          Map<String, dynamic> carInfoMap = jsonDecode(jsonString);
          _selectedCarInfo = CarInfo(carInfoMap['year'], carInfoMap['cid']);
          print("Loaded carInfo: $_selectedCarInfo");
        } catch (e) {
          _selectedCarInfo = null;
          print("Failed to parse carInfo: $e");
        }
      } else {
        _selectedCarInfo = null;
        print("Loaded carInfo: null");
      }
    } catch (e) {
      print("Failed to load selection: $e");
      // Handle error (show a message to the user, etc.)
    }
  }

  Future<void> _saveSelection(BuildContext context) async {
    if (!_noCarSelected &&
        (_selectedCarCompany == null ||
            _selectedCarName == null ||
            _selectedCarInfo == null)) {
      _showErrorDialog('제조사, 차량, 연식 정보를 모두 선택하세요.');
      return;
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final deviceService = Provider.of<DeviceService>(context, listen: false);

      // noCarSelected 저장
      await prefs.setBool('noCarSelected', _noCarSelected);
      print("Saved noCarSelected: $_noCarSelected");

      // selectedCarCompany 저장
      if (_selectedCarCompany != null) {
        await prefs.setString('selectedCarCompany', _selectedCarCompany!);
      } else {
        await prefs.remove('selectedCarCompany');
      }
      print("Saved selectedCarCompany: ${_selectedCarCompany ?? 'null'}");

      // selectedCarName 저장
      if (_selectedCarName != null) {
        await prefs.setString('selectedCarName', _selectedCarName!);
      } else {
        await prefs.remove('selectedCarName');
      }
      print("Saved selectedCarName: ${_selectedCarName ?? 'null'}");

      // selectedCarInfo 저장
      if (_selectedCarInfo != null) {
        String jsonString = jsonEncode(
            {'year': _selectedCarInfo!.year, 'cid': _selectedCarInfo!.cid});
        await prefs.setString('selectedCarInfo', jsonString);
      } else {
        await prefs.remove('selectedCarInfo');
      }
      print("Saved carInfo: ${_selectedCarInfo ?? 'null'}");

      String userAgent = await _getUserAgent();

      if (deviceService.uid == null) {
        await deviceService.getCarMenuList();
        await deviceService.createDevice(userAgent, deviceService.cid!);
        print("디바이스를 생성했습니다.");
      } else {
        await deviceService.updateDevice(
            deviceService.uid!, deviceService.cid!);
        print("디바이스를 업데이트했습니다.");
      }

      // Navigation should happen after all async operations are done
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      print("Failed to save selection: $e");
      _showErrorDialog('선택 사항을 저장하는 데 실패했습니다. 네트워크 연결을 확인해 주세요.');
    }
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

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceService>(
      builder: (context, deviceService, child) {
        Map<String, Map<String, List<Map<String, dynamic>>>> carData =
            deviceService.carData;
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: carData.isEmpty
                ? Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/img/carselection.png',
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '안내 받을 차량을 선택하세요.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        title: Text("차량을 선택하지 않음"),
                        value: _noCarSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            _noCarSelected = value ?? false;
                            if (_noCarSelected) {
                              _selectedCarCompany = null;
                              _selectedCarName = null;
                              _selectedCarInfo = null;
                              deviceService.cid = 1;
                            }
                          });
                        },
                      ),
                      _buildDropdown<String>(
                        hint: '제조사를 선택하세요.',
                        value: _selectedCarCompany,
                        items: carData.keys.map((carCompany) {
                          return DropdownMenuItem<String>(
                            value: carCompany,
                            child: Text(carCompany),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedCarCompany = newValue;
                            _selectedCarName = null;
                            _selectedCarInfo = null;
                          });
                        },
                        enabled: !_noCarSelected,
                      ),
                      _buildDropdown<String>(
                        hint: '차량을 선택하세요.',
                        value: _selectedCarName,
                        items: _selectedCarCompany == null
                            ? []
                            : carData[_selectedCarCompany]!.keys.map((carName) {
                                return DropdownMenuItem<String>(
                                  value: carName,
                                  child: Text(carName),
                                );
                              }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedCarName = newValue;
                            _selectedCarInfo = null;
                          });
                        },
                        enabled: !_noCarSelected,
                      ),
                      _buildDropdown<CarInfo>(
                        hint: '연식을 선택하세요.',
                        value: _selectedCarInfo,
                        items: _selectedCarName == null
                            ? []
                            : carData[_selectedCarCompany]![_selectedCarName]!
                                .map((carInfo) {
                                return DropdownMenuItem<CarInfo>(
                                  value:
                                      CarInfo(carInfo['year'], carInfo['cid']),
                                  child: Text(carInfo['year'].toString()),
                                );
                              }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedCarInfo = newValue;
                            deviceService.cid = newValue?.cid ?? 1;
                          });
                        },
                        enabled: !_noCarSelected,
                      ),
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 24),
                        child: ElevatedButton(
                          onPressed: () => _saveSelection(context),
                          child: Text('확인'),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool enabled,
  }) {
    // Check for duplicates and print current items and value
    print('Dropdown hint: $hint');
    print('Current value: $value');
    print('Items: $items');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButton<T>(
        hint: Text(hint),
        value: value,
        onChanged: enabled ? onChanged : null,
        items: items,
        isExpanded: true,
      ),
    );
  }
}

class CarInfo {
  final String year;
  final int cid;

  CarInfo(this.year, this.cid);

  @override
  String toString() {
    return 'CarInfo{year: $year, cid: $cid}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarInfo &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          cid == other.cid;

  @override
  int get hashCode => year.hashCode ^ cid.hashCode;
}
