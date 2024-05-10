import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async';
import 'bluetooth_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_player.dart';
import 'audio_clips.dart';


// Main Flutter/Dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BluetoothScanner.requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReactiveBluetoothAudioPlayer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal.shade100),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}


class MyHomePage extends StatefulWidget{
  const MyHomePage({super.key});
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>{

  // Managers
  late AudioPlayerManager _audioPlayerManager;
  late BluetoothScanner _bluetoothScanner;
  final Duration bluetoothScanDuration = const Duration(seconds: 3);

  // Estados provenientes del manager de bluetooth
  bool _error = false;
  bool _isScanning = false;
  bool _permissionsGranted = false;

  // Listado de clips
  final Map<String, AssetSource> clips = CLIPS;
  final AssetSource? _defaultClip = CLIPS["DEFAULT"];

  // Estados cambiantes de la app
  ScanResult? currentSignal;
  AssetSource? currentClip;

  // Condiciones alejamiento de señal
  int _scanCounter = 0;
  final int _maxScanCounter = 2;


  // Class lifecycle
  @override
  void initState() {
    super.initState();

    _audioPlayerManager = AudioPlayerManager(onClipFinished: onClipFinished);
    _bluetoothScanner = BluetoothScanner(
        scanTime: bluetoothScanDuration,
        rssiThreshold: -70,
        onDeviceFound: onDeviceFound,
        onScanFinished: onScanFinished,
        onScanStarted: onScanStarted,
        onError: setError,
        onScanning: setScanning
    );
  }

  @override
  void dispose() {
    _bluetoothScanner.dispose();
    _audioPlayerManager.stop();
    super.dispose();
  }

  // Setters de estados
  void setCounter(int counter) => setState(() {_scanCounter = counter;});

  void setAudioState(AssetSource? s, ScanResult? r) => setState(() {
    currentSignal = r; currentClip = s;
  });

  void clearAudioState() => setAudioState(null, null);


  // Audio Manager Callbacks
  void onClipFinished(){
    debugPrint("CLIP FINISHED IN MAIN");
    clearAudioState();
  }

  // Bluetooth Scanner Manager Callbacks
  void setError(bool error) => setState(() => _error = error);
  void setScanning(bool scanning) => setState(() => _isScanning = scanning);

  void onScanFinished() async {
    // Si recordamos una señal
    if(currentSignal != null) {
      if (_scanCounter >= _maxScanCounter) _signalOutOfRange();
    }
    else{
     //si no, y no estamos ya reproducinedo el clip default, reproducelo
      if (currentClip != _defaultClip) _clipTransition(_defaultClip, null, const Duration(seconds: 1));
    }
  }

  // Cuando inicia el scan, si recordamos una señal aumentamos el counter de escaneos uno
  void onScanStarted(){
    if (currentSignal != null) setCounter(_scanCounter + 1);
  }

  // Callback para procesar cada dispositivo encontrado
  void onDeviceFound(ScanResult result) async {
    String resultId = result.device.id.id;
    AssetSource? clip = clips[resultId];
    if (clip == null) return;
    // Si el clip no es nulo tratamos de hacer transicion
    _changeClip(clip, result);
  }

  // si la senal recordada ya no es encontrada de acuerdo a los contadores, transicionamos a un clip nulo
  void _signalOutOfRange() async {
    debugPrint("Signal out of range: Fading out");
    _clipTransition(null, null, const Duration(seconds: 1));
  }

  // Al dar click en iniciar scan iniciamos
  void _startScan() => _bluetoothScanner.startScan();
  // al dar click en terminar scan ademas de parar los scanneos pendientes transicionamos a un clip nulo
  void _stopScan() {
    _bluetoothScanner.stopScan();
    // changeClip to null
    _clipTransition(null, null, const Duration(seconds: 1));
  }


  // El meollo del asunto. Determinar si debemos cambiar clips o no
  // SOLO PARA CLIPS QUE PROVIENEN DE UNA SEÑAL, por eso no son nullable los parametros
  // de la funcion
  void _changeClip(AssetSource source, ScanResult result){

    if (currentSignal == null){
      // encontrar por primera vez
      _clipTransition(source, result, const Duration(seconds: 1));
    }
    else if (currentSignal?.device == result.device) {
      // repetir clip encontrado
      setCounter(0); // volvimos a encontrar la señal asi que llevamos 0 scaneos sin encontrarla
      setAudioState(source, result); // nos quedamos con la version mas reciente de la senal para poder ser comparada
      _audioPlayerManager.playOrResume(source); // resume en caso de que sea necesari
    }
    else if (currentSignal?.device == result.device && currentSignal!.rssi < result.rssi){
      // cambiar a una mas señal cercana a la que recordabamos
      _clipTransition(source, result, const Duration(seconds: 1));
    }
  }


  // EL SEGUNDO MEOLLO DEL ASUNTO
  void _clipTransition(AssetSource? source, ScanResult? result, Duration transition) async {

    // SI TRATAMOS DE TRANSICIONAR AL MISMO CLIP QUE ESTA CORRIENDO NO HACEMOS NADA
    if(currentClip == source) return;

    // YA en este punto sabemos que debemos de cambiar de clip
    debugPrint("Playing: ${source?.path}");

    // Si no estamos reproduciendo nada directamente la transicion es iniciar el player con el nuevo clip
    if (_audioPlayerManager.getState() != PlayerState.playing){
      await _audioPlayerManager.play(source);
    }
    else{
      // si si estamos reproduciendo algo iniciamos el fadeout (que reproduce el clip al final)
      await _audioPlayerManager.fadeOutPlay(transition, source);
    }

    // Cambiamos de estado la app y reseteamos el contador de timeout a 0
    setAudioState(source, result);
    setCounter(0);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reactive Bluetooth Audio Player"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
              child: _error
                  ? const Text("No se ha autorizado el uso de bluetooth, intenta reinicar la app")
                  : _isScanning
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const CircularProgressIndicator(),
                    ElevatedButton(
                      onPressed: _stopScan,
                      child: const Text('Stop Scan'),
                    ),
                  ])
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _startScan,
                        child: const Text('Start Scan'),
                      ),
                  ])
          ),


          // debugs:
          Text("Device: ${currentSignal?.device.id.id}"),
          if(currentClip != null)
            Text("Playing: ${currentClip?.path}"),
          if (currentSignal != null)
            Text("nScansFailed: $_scanCounter")
        ],
      )
    );
  }
}