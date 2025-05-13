import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformChannelExample extends StatefulWidget {
  const PlatformChannelExample({super.key});

  @override
  State<PlatformChannelExample> createState() => _PlatformChannelExampleState();
}

class _PlatformChannelExampleState extends State<PlatformChannelExample> {
  static const platform = MethodChannel(
    'com.example.flutter_module/platform_channel',
  );
  String _responseFromNative = 'No response yet';
  String _batteryLevel = 'Unknown';

  Future<void> _sendMessageToNative() async {
    try {
      final String result = await platform.invokeMethod('sendMessage', {
        'message': 'Hello from Flutter!',
        'timestamp': DateTime.now().toString(),
      });
      setState(() {
        _responseFromNative = result;
      });
    } on PlatformException catch (e) {
      setState(() {
        _responseFromNative = "Failed to send message: '${e.message}'.";
      });
    }
  }

  Future<void> _getBatteryLevel() async {
    try {
      final int result = await platform.invokeMethod('getBatteryLevel');
      setState(() {
        _batteryLevel = '$result%';
      });
    } on PlatformException catch (e) {
      setState(() {
        _batteryLevel = "Failed to get battery level: '${e.message}'.";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Set up method call handler for receiving messages from native
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'messageFromNative':
        final Map<String, dynamic> arguments = call.arguments;
        setState(() {
          _responseFromNative = "Native says: ${arguments['message']}";
        });
        return 'Message received in Flutter';
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'The method ${call.method} is not implemented.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Channel Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Platform Communication Example',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Response from Native: $_responseFromNative'),
            const SizedBox(height: 10),
            Text('Battery Level: $_batteryLevel'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _sendMessageToNative,
              child: const Text('Send Message to Native'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _getBatteryLevel,
              child: const Text('Get Battery Level'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
