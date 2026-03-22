import 'dart:convert';
import 'package:web_socket_channel/html.dart';

class GateControlService {
  static const String _wsUrl = 'wss://rfid-websocket-server.onrender.com';
  HtmlWebSocketChannel? _channel;

  // Singleton pattern
  static final GateControlService _instance = GateControlService._internal();
  factory GateControlService() => _instance;
  GateControlService._internal();

  // Initialize WebSocket connection
  void initialize() {
    try {
      _channel = HtmlWebSocketChannel.connect(_wsUrl);
      print('✅ Gate Control Service: Connected to WebSocket server');
      print('🔗 Gate Control Service: Connected to $_wsUrl');
    } catch (e) {
      print('❌ Gate Control Service: Failed to connect - $e');
    }
  }

  // Send gate control command to open entry gate
  Future<void> openEntryGate(String studentRfidUid) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'entry',
      'action': 'open',
      'uid': studentRfidUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Send gate control command to open entry gate (guard override)
  Future<void> openEntryGateOverride(String studentRfidUid) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'entry',
      'action': 'open',
      'uid': studentRfidUid,
      'override_mode': 'guard_override',
      'verified_by': 'Guard Override',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Send gate control command to open exit gate
  Future<void> openExitGate(String studentRfidUid) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'exit',
      'action': 'open',
      'uid': studentRfidUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Send gate control command to open exit gate (guard override)
  Future<void> openExitGateOverride(String studentRfidUid) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'exit',
      'action': 'open',
      'uid': studentRfidUid,
      'override_mode': 'guard_override',
      'verified_by': 'Guard Override',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Send gate control command to deny entry
  Future<void> denyEntry(String studentRfidUid, String reason) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'entry',
      'action': 'deny',
      'uid': studentRfidUid,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Send gate control command to deny exit
  Future<void> denyExit(String studentRfidUid, String reason) async {
    await _sendGateCommand({
      'type': 'gate_control',
      'gate': 'exit',
      'action': 'deny',
      'uid': studentRfidUid,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Manual gate control - open entry gate indefinitely
  Future<void> manualOpenEntryGate() async {
    await _sendManualGateCommand('MANUAL_GATE_OPEN_ENTRY');
  }

  // Manual gate control - open exit gate indefinitely
  Future<void> manualOpenExitGate() async {
    await _sendManualGateCommand('MANUAL_GATE_OPEN_EXIT');
  }

  // Manual gate control - close gate
  Future<void> manualCloseGate() async {
    await _sendManualGateCommand('MANUAL_GATE_CLOSE');
  }

  // Send manual gate control command
  Future<void> _sendManualGateCommand(String command) async {
    if (_channel?.sink == null) {
      print('❌ Gate Control Service: WebSocket not connected');
      initialize(); // Try to reconnect
      return;
    }

    try {
      final message = {
        'type': 'manual_gate_control',
        'command': command,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final jsonMessage = json.encode(message);
      _channel!.sink.add(jsonMessage);
      print('🔧 Manual Gate Control: Sent command - $command');
    } catch (e) {
      print('❌ Manual Gate Control: Failed to send command - $e');
    }
  }

  // Private method to send gate control command
  Future<void> _sendGateCommand(Map<String, dynamic> command) async {
    if (_channel?.sink == null) {
      print('❌ Gate Control Service: WebSocket not connected');
      initialize(); // Try to reconnect
      return;
    }

    try {
      final jsonMessage = json.encode(command);
      _channel!.sink.add(jsonMessage);
      print(
        'Gate Control: ${command['gate']} ${command['action']} (${command['uid']})',
      );
    } catch (e) {
      print('Gate Control Error: $e');
    }
  }

  // Clean up
  void dispose() {
    _channel?.sink.close();
    print('🔌 Gate Control Service: WebSocket connection closed');
  }
}
