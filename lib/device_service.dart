import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Memo 데이터의 형식을 정해줍니다. 추후 isPinned, updatedAt 등의 정보도 저장할 수 있습니다.
class Device {
  Device({
    required this.uid,
    required this.cid,
  });
  int? uid;
  int? cid;
}

// Device 데이터는 모두 여기서 관리
class DeviceService extends ChangeNotifier {
  Map<String, Map<String, List<Map<String, dynamic>>>> carData = {};

  int? _uid;
  int? _cid;

  int? get uid => _uid;

  set uid(int? newUid) {
    _uid = newUid;
    notifyListeners(); // 상태 변경을 알림
  }

  int? get cid => _cid;

  set cid(int? newCid) {
    _cid = newCid;
    notifyListeners(); // 상태 변경을 알림
  }

  final Dio _dio = Dio();

  Future<Map<String, Map<String, List<Map<String, dynamic>>>>>
      getCarMenuList() async {
    try {
      final response = await _dio
          .get('https://dn4gad2bda.ap-northeast-1.awsapprunner.com/carmenu');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data.map((key, value) => MapEntry(
            key,
            (value as Map<String, dynamic>).map((key, value) => MapEntry(
                key,
                (value as List<dynamic>)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList()))));
      } else {
        throw Exception('Failed to load car menu');
      }
    } on SocketException catch (_) {
      throw Exception('인터넷 연결이 없습니다. 네트워크 상태를 확인해주세요.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('서버 연결 시간이 초과되었습니다. 나중에 다시 시도해주세요.');
      } else {
        throw Exception('Car menu 로딩 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('Car menu 로딩 실패: $e');
    }
  }

  Future<void> createDevice(String userAgent, int cid) async {
    try {
      print("createDevice에서 넘겨받은 userAgent : $userAgent");
      print("createDevice에서 넘겨받은 cid : $cid");

      final response = await _dio.post(
        'https://dn4gad2bda.ap-northeast-1.awsapprunner.com/devices',
        data: {'userAgent': userAgent, 'cid': cid},
        options: Options(
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        uid = data['uid'];
        print("cid $cid를 담아 uid $uid로 디바이스 생성했습니다.");

        // Save cid and uid to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('cid', cid);
        await prefs.setInt('uid', uid!);
        print("cid $cid와 uid $uid가 SharedPreferences에 저장되었습니다.");
      } else {
        print(
            "Failed to create device: ${response.statusCode} ${response.statusMessage}");
        throw Exception('Failed to create device');
      }
    } on SocketException catch (_) {
      throw Exception('인터넷 연결이 없습니다. 네트워크 상태를 확인해주세요.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('서버 연결 시간이 초과되었습니다. 나중에 다시 시도해주세요.');
      } else {
        print('DioException: ${e.message}');
        if (e.response != null) {
          print('Response data: ${e.response?.data}');
          print('Response headers: ${e.response?.headers}');
        }
        throw Exception('디바이스 생성 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('디바이스 생성 실패: $e');
    }
  }

  Future<void> updateDevice(int uid, int cid) async {
    print("updateDevice에서 넘겨받은 uid : $uid");
    print("updateDevice에서 넘겨받은 cid : $cid");
    try {
      final response = await _dio.put(
        'https://dn4gad2bda.ap-northeast-1.awsapprunner.com/devices/$uid',
        data: {'cid': cid},
        options: Options(
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
        ),
      );

      if (response.statusCode == 200) {
        print("uid $uid의 cid를 $cid로 수정 성공했습니다.");
        // Device updated successfully
      } else {
        throw Exception('Failed to update device');
      }
    } catch (e) {
      throw Exception('Failed to update device: $e');
    } on SocketException catch (_) {
      throw Exception('인터넷 연결이 없습니다. 네트워크 상태를 확인해주세요.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('서버 연결 시간이 초과되었습니다. 나중에 다시 시도해주세요.');
      } else {
        throw Exception('디바이스 업데이트 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('디바이스 업데이트 실패: $e');
    }
  }
}

class CarInfo {
  final String year;
  final int cid;

  CarInfo(this.year, this.cid);

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
