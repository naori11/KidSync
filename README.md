# Smart Student Drop-Off and Pick-Up Verification System

## Overview
The **Smart Student Drop-Off and Pick-Up Verification System** is an IoT-powered solution developed by **C.Reate Solutions** for **National University – Fairview**. It enhances student safety by verifying authorized guardians during drop-off and pick-up through RFID and IoT technology. The system integrates both **hardware (ESP32 with RFID scanners and Servo Motor for Gate Functionality)** and **software (Flutter app with Supabase backend)** components to ensure real-time verification, attendance logging, and secure student management.

---

## Key Features & Benefits

*   **RFID-based Presence Detection:** Uses RFID technology to automatically register when a child enters or leaves a designated area (e.g., school, home).
*   **Location Tracking:** Provides real-time location updates of family members.
*   **Push Notifications:** Sends alerts to parents/guardians upon entry or exit from designated zones or other important events.
*   **Cross-Platform Compatibility:** Built with Flutter, ensuring compatibility across both Android and iOS devices.
*   **Backend Flexibility:** Backend is built using Supabase BaaS.

## Prerequisites & Dependencies

Before you begin, ensure you have the following installed:

*   **Flutter SDK:** Required for building and running the mobile application.
    *   [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)
*   **Android Studio/Xcode:**  Necessary for building and deploying to Android and iOS devices, respectively.
*   **Python 3.x:** Required for running RFID communication scripts.
    *   Python: [https://www.python.org/downloads/](https://www.python.org/downloads/)
*   **Pip:** Python package installer (usually included with Python installations).
*   **WebSocket Client (Python):** `pip install websocket-client`
*   **Serial Library (Python):** `pip install pyserial`
*   **Node.js and Deno (optional):** Required if you intend to use the Supabase Edge Function.
    *   Node.js: [https://nodejs.org/en/download/](https://nodejs.org/en/download/)
    *   Deno: [https://deno.land/#installation](https://deno.land/#installation)
*   **Supabase CLI (optional):** Required if you intend to deploy Supabase functions locally or to a Supabase project.
    *   [Supabase CLI Installation](https://supabase.com/docs/reference/cli/install)

---

## System Architecture

1. **Hardware**
   - ESP32 Microcontroller
   - RC522 RFID Scanners (2 units)
   - 15kg Servo Motor
   - USB Cable for direct connection

2. **Software**
   - **Frontend:** Flutter (Web & Mobile)
   - **Backend:** Supabase (PostgreSQL + Authentication + Functions)
   - **Integration:** REST API / Serial Communication

---

## IoT Features
- **ESP32 Integration**
  - Connects to the Flutter system through serial or Wi-Fi communication
- **Dual RFID Scanners**
  - One for student card scanning
  - One for guardian/driver verification
- **Servo Motor**
  - For physical gate movements
 
---

## Installation & Setup Instructions

Follow these steps to set up the project:

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/naori11/ksync.git
    cd ksync
    ```

2.  **Set up the Flutter project:**

    *   Navigate to the `android/` directory from the root of the repository and run:

      ```bash
      flutter pub get
      ```

    *   Connect a physical Android or iOS device, or start an emulator.
    *   Run the Flutter application:

        ```bash
        flutter run
        ```

3.  **Configure RFID Communication:**

    *   Install the required Python packages:

        ```bash
        pip install pyserial websocket-client
        ```

    *   Update `python/admin_rfid_sender.py` and `python/guard_rfid_sender.py` with the correct `SERIAL_PORT` and `WS_URL`. The `SERIAL_PORT` must correspond to the COM port where your Arduino is connected, and the `WS_URL` to your websocket server.
    *  Verify the `BAUD_RATE` matches your Arduino's serial baud rate (default is 115200).
    *   Run the RFID sender scripts:

        ```bash
        python python/admin_rfid_sender.py
        python python/guard_rfid_sender.py
        ```

---

## Usage Examples & API Documentation

### Python RFID Sender Scripts:

These scripts read RFID data from a serial port and send it to a WebSocket server.  Both scripts require the `pyserial` and `websocket-client` libraries.

*   **`admin_rfid_sender.py`:** For administrative actions related to RFID, such as adding or removing tags.
*   **`guard_rfid_sender.py`:**  For monitoring RFID tags and triggering events based on tag presence.

The WebSocket URL must be configured correctly in both scripts.

### Flutter App

The Flutter app is the main user interface. It connects to the WebSocket server and displays the data received from the RFID readers.  Refer to the Flutter documentation for details on UI customization and data handling.

## Configuration Options

*   **`SERIAL_PORT` (Python):** The COM port used for serial communication with the RFID reader.  Change in `python/admin_rfid_sender.py` and `python/guard_rfid_sender.py`.
*   **`BAUD_RATE` (Python):** The baud rate for serial communication.  Ensure this matches the baud rate configured on your Arduino.
*   **`WS_URL` (Python):** The WebSocket URL for sending RFID data.  Change in `python/admin_rfid_sender.py` and `python/guard_rfid_sender.py`.
*   **Firebase Service Account:** Required to send push notifications (configure in `supabase/functions/send-push-notification/index.ts`).
