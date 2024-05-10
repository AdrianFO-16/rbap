import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue/flutter_blue.dart';


class BluetoothScanner {

  // constructor, pide permisos al ser creado
  BluetoothScanner({
    required this.scanTime,
    required this.rssiThreshold,
    required this.onDeviceFound,
    required this.onScanStarted,
    required this.onScanFinished,
    required this.onScanning,
    required this.onError
  }
      ) {
    _checkPermissions();
  }

  // parametros de funcionamiento
  final Duration scanTime;
  final int rssiThreshold;
  // eventos para ser gestionados por la app principal
  final Function(ScanResult) onDeviceFound;
  final Function() onScanStarted;
  final Function() onScanFinished;
  final Function(bool) onScanning;
  final Function(bool) onError;

  // instancia encargada de bluetooth
  FlutterBlue flutterBlue = FlutterBlue.instance;

  // timer de reinicio (para loopear indefinidamente)
  Timer? _restartTimer;


  static void requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.location.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  static Future<bool> shouldRequestPermissions() async {
    return await Permission.bluetooth.isDenied ||
        await Permission.location.isDenied ||
        await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothConnect.isDenied;
  }

  static Future<bool> allPermissionsGranted() async{
    return await Permission.bluetooth.isGranted &&
        await Permission.location.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted;
  }


  void _checkPermissions() async {
    if (await BluetoothScanner.shouldRequestPermissions()) {
      BluetoothScanner.requestPermissions();
    }
    if (await BluetoothScanner.allPermissionsGranted()) {
      onError(false);
      return;
    } else {
      onError(true);
    }
  }

  void startScan() {
    onScanning(true);
    _restartTimer = Timer.periodic(scanTime + const Duration(milliseconds: 10), (timer) async {
      onScanStarted();
      try { // en caso de que se incie un scan antes de que termine el anterior (SIGUE SUCEDIENDO)
        flutterBlue.startScan(timeout: scanTime, scanMode: ScanMode.lowLatency);
        flutterBlue.scanResults.listen((results) {
          for (ScanResult result in results) {
            if (result.rssi > rssiThreshold) {
              onDeviceFound(result); // Notify the parent widget
            }
          }
        });
      }
      catch (e) {

        return;
      }

      onScanFinished();
    });
  }

  void stopScan() {
    _restartTimer?.cancel();
    flutterBlue.stopScan();
    onScanning(false);
    onScanFinished();
  }

  void dispose() {
    stopScan();
  }
}