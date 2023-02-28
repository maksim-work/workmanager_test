import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class FirebaseModel {
  final String? importantAndBidData;

  FirebaseModel({required this.importantAndBidData});

  static FirebaseModel fromJson(Map<String, dynamic> json) => FirebaseModel(
        importantAndBidData: json["important_and_bid_data"] as String?,
      );
}

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask(
    (task, inputData) async {
      await readLatestFirebaseData(inputData!['lastInputValue'] as String);
      return true;
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  runApp(const MyApp());
}

Future<void> readLatestFirebaseData(String lastInputValue) async {
  await Firebase.initializeApp();
  final readData = FirebaseFirestore.instance.collection("readExample").doc("value");
  final writeData = FirebaseFirestore.instance.collection("writeExample").doc("value");
  await writeData.update({"last_input_value": lastInputValue});
  final snapshot = await readData.get();

  if (snapshot.exists) {
    final prefs = await SharedPreferences.getInstance();
    final dataFromFirebase = FirebaseModel.fromJson(snapshot.data()!);
    await prefs.setString('value', dataFromFirebase.importantAndBidData ?? '');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  TextEditingController controller = TextEditingController();
  String data = '';

  Future<void> getLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString('value');
    setState(() {
      data = value ?? '';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        Workmanager().registerOneOffTask(
          "one time update",
          "OneOffTask",
          tag: "one_time",
          existingWorkPolicy: ExistingWorkPolicy.replace,
          initialDelay: const Duration(seconds: 5),
          constraints: Constraints(networkType: NetworkType.connected),
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(seconds: 10),
          inputData: {'lastInputValue': controller.text},
        );
        //or
        // Workmanager().registerPeriodicTask(
        //   "periodic update",
        //   "PeriodicTask",
        //   tag: "periodic",
        //   frequency: const Duration(minutes: 15),
        //   existingWorkPolicy: ExistingWorkPolicy.replace,
        //   initialDelay: const Duration(seconds: 5),
        //   constraints: Constraints(networkType: NetworkType.connected),
        //   backoffPolicy: BackoffPolicy.linear,
        //   backoffPolicyDelay: const Duration(seconds: 10),
        // );
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void initState() {
    getLocalData();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text("Workmanager example"),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('background firebase synchronization'),
            const SizedBox(height: 16.0),
            Text(
              data,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'input',
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
