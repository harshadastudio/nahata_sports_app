import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider {
  static final ConnectivityProvider _instance = ConnectivityProvider._internal();
  factory ConnectivityProvider() => _instance;
  ConnectivityProvider._internal();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _controller.stream;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((result) {
      bool isOnline = result != ConnectivityResult.none;
      _controller.sink.add(isOnline);
    });
  }

  void dispose() {
    _controller.close();
  }
}
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({required this.child, super.key});

  @override
  _ConnectivityWrapperState createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    ConnectivityProvider().connectivityStream.listen((status) {
      if (mounted) {
        setState(() {
          _isOnline = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child, // your whole app

        // ✅ Popup in the center
        if (!_isOnline)
          Container(
            color: Colors.black.withOpacity(0.5), // dim background
            alignment: Alignment.center,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.wifi_off, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text(
                    "No Internet Connection",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Please check your network settings.",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

