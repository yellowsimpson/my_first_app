import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주유중',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FuelPage(),
    );
  }
}

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage>
    with SingleTickerProviderStateMixin {
  String fuelType = '경유';
  int amount = 10000; // 원
  double pricePerLiter = 1700; // 1L당 1700원이라고 가정
  bool isFueling = false;

  late AnimationController _controller;
  late Animation<double> _litersAnimation;
  Timer? _timer; // ✅ 주기적으로 서버에 요청하는 타이머

  double get liters => amount / pricePerLiter;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {}); // 🔥 매 프레임마다 UI 업데이트
      });

    _litersAnimation =
        Tween<double>(begin: 0, end: liters).animate(_controller);

    // ✅ 1초마다 서버에서 ROS 데이터 받아오기
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => fetchFuelData(),
    );
  }

  // 🔹 서버에서 유종 / 금액 받아오기
  Future<void> fetchFuelData() async {
    try {
      // ⬇⬇ 여기 IP를 실제 서버 IP로 바꿔줘야 해요!!
      // 예: 'http://192.168.0.10:8000/fuel_update'
      final response = await http
          .get(Uri.parse('http://192.168.0.10:8000/fuel_update'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          fuelType = data["fuel_type"] as String;
          amount = data["amount"] as int;
        });
      } else {
        debugPrint('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('서버 통신 오류: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel(); // ✅ 타이머 꼭 정리
    super.dispose();
  }

  void startFueling() {
    if (isFueling) return;

    setState(() {
      isFueling = true;
      _litersAnimation =
          Tween<double>(begin: 0, end: liters).animate(_controller);
    });

    _controller.reset();
    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        isFueling = false;
      });
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('⛽ 주유 완료'),
            content: Text(
              '$fuelType 주유가 완료되었습니다!\n\n'
              '금액: ${amount}원\n'
              '리터: ${liters.toStringAsFixed(2)}L',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLiters =
        isFueling ? _litersAnimation.value : liters; // 현재 리터 계산
    final progress = isFueling ? _controller.value : 0; // 현재 게이지 진행률

    return Scaffold(
      appBar: AppBar(
        title: const Text('주유중'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '주유 정보',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '종류',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DropdownButton<String>(
                        value: fuelType,
                        items: ['휘발유', '경유', '전기']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: isFueling
                            ? null
                            : (value) {
                                setState(() {
                                  fuelType = value!;
                                  if (fuelType == '휘발유') {
                                    pricePerLiter = 1850;
                                  } else if (fuelType == '경유') {
                                    pricePerLiter = 1700;
                                  } else {
                                    pricePerLiter = 263;
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRow('금액', '${amount}원'),
                  const SizedBox(height: 12),
                  _buildRow('리터', '${currentLiters.toStringAsFixed(2)} L'),
                  const SizedBox(height: 16),

                  // 🔹 주유 진행률 바
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '주유 진행률',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.toDouble(),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '※ + 버튼을 누르면 1,000원씩 증가합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isFueling ? null : startFueling,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFueling ? Colors.grey : Colors.greenAccent[700],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isFueling ? '주유 중...' : '주유 시작',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isFueling
            ? null
            : () {
                setState(() {
                  amount += 1000;
                });
              },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
}
