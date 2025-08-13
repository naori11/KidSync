import serial
import time
import websocket
import json

# --- Configuration ---
SERIAL_PORT = 'COM5'         # Update this to your actual COM port (e.g. COM4, /dev/ttyUSB0)
BAUD_RATE = 115200             # Must match the Arduino Serial baud
WS_URL = "wss://rfid-websocket-server.onrender.com"  # Replace with your actual WebSocket URL

# --- Setup WebSocket ---
def connect_websocket():
    try:
        ws = websocket.WebSocket()
        ws.connect(WS_URL)
        print("✅ Connected to WebSocket server.")
        return ws
    except Exception as e:
        print("❌ Failed to connect to WebSocket:", e)
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

# --- Main Loop ---
def main():
    ws = connect_websocket()
    ser = connect_serial()

    if ws is None or ser is None:
        print("❌ Unable to start due to connection error.")
        return

    try:
        while True:
            if ser.in_waiting:
                uid = ser.readline().decode('utf-8').strip()
                if uid and len(uid) >= 8 and all(c in "0123456789abcdef" for c in uid.lower()):
                    print(f"📨 UID read: {uid}")
                    try:
                        # Create JSON message
                        message = {
                            "type": "rfid_scan",
                            "uid": uid,
                            "timestamp": time.time()
                        }
                        json_message = json.dumps(message)
                        ws.send(json_message)
                        print(f"✅ Sent JSON to WebSocket: {json_message}")
                    except Exception as send_error:
                        print("❌ Send failed. Reconnecting WebSocket...")
                        ws = connect_websocket()
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("🛑 Stopped by user.")
    finally:
        if ser:
            ser.close()
        if ws:
            ws.close()
        print("🔌 Closed connections.")

# --- Entry Point ---
if __name__ == "__main__":
    main()