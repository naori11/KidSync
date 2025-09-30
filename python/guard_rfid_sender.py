import serial
import time
import websocket  # pip install websocket-client
import json
import threading

# --- Configuration ---
SERIAL_PORT = 'COM5'         # Update this to your actual COM port
BAUD_RATE = 115200           # Must match the Arduino Serial baud
WS_URL = "wss://rfid-websocket-server.onrender.com"  # Replace with your actual WebSocket URL

# Global variables for connections
ser = None
ws = None
running = False

# --- Setup WebSocket with message handling ---
def on_message(ws, message):
    """Handle incoming WebSocket messages (gate control commands)"""
    global ser
    try:
        print(f"📥 Received WebSocket message: {message}")
        
        # Parse the JSON message
        data = json.loads(message)
        print(f"🔍 Parsed message type: {data.get('type', 'unknown')}")
        
        # Check if this is a gate control command
        if data.get('type') == 'gate_control':
            print(f"🚪 Gate control command detected!")
            print(f"   Gate: {data.get('gate', 'unknown')}")
            print(f"   Action: {data.get('action', 'unknown')}")
            print(f"   UID: {data.get('uid', 'unknown')}")
            
            # Forward the gate control command to Arduino
            gate_command = f"GATE_CONTROL:{json.dumps(data)}\n"
            if ser and ser.is_open:
                ser.write(gate_command.encode('utf-8'))
                print(f"✅ Sent gate control to ESP32: {gate_command.strip()}")
            else:
                print("❌ Serial connection not available for gate control")
        elif data.get('type') == 'manual_gate_control':
            print(f"🔧 Manual gate control command detected!")
            print(f"   Command: {data.get('command', 'unknown')}")
            
            # Forward the manual gate control command to Arduino
            manual_command = f"{data.get('command', '')}\n"
            if ser and ser.is_open:
                ser.write(manual_command.encode('utf-8'))
                print(f"✅ Sent manual gate control to ESP32: {manual_command.strip()}")
            else:
                print("❌ Serial connection not available for manual gate control")
        else:
            print(f"ℹ️  Non-gate-control message type: {data.get('type', 'unknown')}")
                
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse WebSocket message as JSON: {e}")
        print(f"   Raw message: {message}")
    except Exception as e:
        print(f"❌ Error handling WebSocket message: {e}")
        print(f"   Raw message: {message}")

def on_error(ws, error):
    print(f"❌ WebSocket error: {error}")

def on_close(ws, close_status_code, close_msg):
    print("🔌 WebSocket connection closed")
    # Notify ESP32 that system is disconnected
    if ser and ser.is_open:
        ser.write(b"SYSTEM_DISCONNECTED\n")
        print("📡 Notified ESP32: System disconnected - gates allow manual operation")

def on_open(ws):
    print("✅ WebSocket connection opened")
    # Notify ESP32 that system is connected
    if ser and ser.is_open:
        ser.write(b"SYSTEM_CONNECTED\n")
        print("📡 Notified ESP32: System connected - gates under system control")

# --- Setup WebSocket ---
def connect_websocket():
    try:
        ws = websocket.WebSocketApp(WS_URL,
                                  on_message=on_message,
                                  on_error=on_error,
                                  on_close=on_close,
                                  on_open=on_open)
        print("✅ WebSocket configured with callbacks.")
        return ws
    except Exception as e:
        print("❌ Failed to configure WebSocket:", e)
        return None

# --- Setup Serial ---
def connect_serial():
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"✅ Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
        return ser
    except Exception as e:
        print("❌ Failed to connect to Serial port:", e)
        return None

# --- Serial reading thread ---
def serial_reader_thread():
    global ser, ws, running
    
    while running:
        try:
            if ser and ser.in_waiting:
                data = ser.readline().strip()
                if not data:
                    continue

                try:
                    text = data.decode("utf-8", errors="ignore").strip()
                    print(f"🔎 Raw data: {text}")
                    
                    # Handle system ready signal
                    if text == "SYSTEM_READY":
                        print("✅ ESP32 system is ready")
                        continue
                    
                    # Handle system timeout signal
                    if text == "SYSTEM_TIMEOUT":
                        print("⚠️ ESP32 system timeout detected")
                        continue
                    
                    # Handle debug messages (don't process as RFID)
                    if text.startswith("DEBUG:") or text.startswith("INFO:") or text.startswith("WARNING:"):
                        # Just log debug messages, don't process as RFID
                        continue

                    # Only process lines that look like RFID scans: "entry:uid" or "exit:uid"
                    if ":" not in text:
                        continue
                    
                    # Check if this looks like an RFID scan (entry:uid or exit:uid)
                    parts = text.split(":", 1)
                    if len(parts) != 2:
                        continue
                        
                    location = parts[0].strip().lower()
                    uid = parts[1].strip().lower()
                    
                    # Only process if location is 'entry' or 'exit'
                    if location not in ['entry', 'exit']:
                        continue

                    # Validate UID format
                    if not all(c in "0123456789abcdef" for c in uid) or len(uid) not in (8, 10, 14):
                        print(f"⚠️ Ignored invalid UID: {uid}")
                        continue

                    print(f"📨 Valid RFID scan detected - {location}: {uid}")

                    # Send JSON message via WebSocket
                    if ws:
                        message = {
                            "type": "rfid_scan",
                            "uid": uid,
                            "scanner": location,
                            "timestamp": time.time()
                        }
                        json_message = json.dumps(message)
                        ws.send(json_message)
                        print(f"✅ Sent JSON to WebSocket: {json_message}")

                except Exception as e:
                    print("❌ Send failed:", e)
                    
        except Exception as e:
            print(f"❌ Serial reading error: {e}")
            
        time.sleep(0.1)

# --- WebSocket thread ---
def websocket_thread():
    global ws, running
    
    while running:
        try:
            if ws:
                ws.run_forever()
            time.sleep(1)
        except Exception as e:
            print(f"❌ WebSocket thread error: {e}")
            time.sleep(5)  # Wait before retrying

# --- Main Loop ---
def main():
    global ser, ws, running
    
    running = True
    
    # Connect to serial and websocket
    ws = connect_websocket()
    ser = connect_serial()

    if ws is None or ser is None:
        print("❌ Unable to start due to connection error.")
        return

    try:
        # Start threads for serial reading and websocket handling
        serial_thread = threading.Thread(target=serial_reader_thread, daemon=True)
        ws_thread = threading.Thread(target=websocket_thread, daemon=True)
        heartbeat_thread = threading.Thread(target=heartbeat_thread_func, daemon=True)
        
        serial_thread.start()
        ws_thread.start()
        heartbeat_thread.start()
        
        print("🚀 Started bidirectional communication threads")
        print("📡 Listening for RFID scans and gate control commands...")
        print("⚠️  Gates are under SYSTEM CONTROL - will only open on approval")
        
        # Keep main thread alive
        while running:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("🛑 Stopped by user.")
    finally:
        running = False
        if ser and ser.is_open:
            ser.write(b"SYSTEM_DISCONNECTED\n")
            time.sleep(0.1)  # Give time for message to send
        if ser:
            ser.close()
        if ws:
            ws.close()
        print("🔌 Closed connections.")

# --- Heartbeat thread to keep ESP32 informed of system status ---
def heartbeat_thread_func():
    global ser, running
    
    while running:
        try:
            if ser and ser.is_open:
                ser.write(b"SYSTEM_CONNECTED\n")
            time.sleep(30)  # Send heartbeat every 30 seconds
        except Exception as e:
            print(f"❌ Heartbeat error: {e}")
            time.sleep(5)

# --- Entry Point ---
if __name__ == "__main__":
    main()
