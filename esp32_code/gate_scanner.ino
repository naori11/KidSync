#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>

// SPI pin definitions (explicit for ESP32)
#define SPI_SCK 18
#define SPI_MISO 19
#define SPI_MOSI 23

// RC522 #1 (Entry)
#define SS1_PIN 21
#define RST1_PIN 22

// RC522 #2 (Exit)
#define SS2_PIN 5
#define RST2_PIN 17

// Buzzer + Servo
#define BUZZER_PIN 16
#define SERVO_PIN 4

MFRC522 rfid1(SS1_PIN, RST1_PIN);
MFRC522 rfid2(SS2_PIN, RST2_PIN);

Servo myServo;

// Timing variables
unsigned long entryGateCloseTime = 0;
unsigned long exitGateCloseTime = 0;
const unsigned long gateOpenDuration = 7000; // 7 seconds

// Track servo state
bool entryGateOpen = false;
bool exitGateOpen = false;

// Gate control states
bool entryGateControlled = true; // Entry gate is always under system control
bool exitGateControlled = true; // Exit gate is always under system control
String lastScannedUID = ""; // Track last scanned UID for control verification
bool systemConnected = true; // System is always connected in this implementation
unsigned long lastHeartbeat = 0; // Track last heartbeat from system
const unsigned long heartbeatTimeout = 60000; // 60 seconds timeout

// Manual gate control states (for guard override)
bool manualGateControlActive = false;
int manualGatePosition = 90; // 90 = closed, 0 = entry open, 180 = exit open

// Smooth servo movement function
void smoothMove(Servo &servo, int startAngle, int endAngle, int stepDelay) {
  if (startAngle < endAngle) {
    for (int pos = startAngle; pos <= endAngle; pos++) {
      servo.write(pos);
      delay(stepDelay);
    }
  } else {
    for (int pos = startAngle; pos >= endAngle; pos--) {
      servo.write(pos);
      delay(stepDelay);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(10);

  SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI);

  rfid1.PCD_Init();
  rfid2.PCD_Init();

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  myServo.attach(SERVO_PIN);
  myServo.write(90);  // Neutral (closed)
  
  // Send ready signal
  Serial.println("SYSTEM_READY");
  Serial.println("INFO: Gates under FULL SYSTEM CONTROL");
  Serial.println("INFO: Gates will ONLY open on system approval - no manual opening");
}

// Helper: format UID
String formatUID(MFRC522::Uid *uid) {
  String uidStr = "";
  for (byte i = 0; i < uid->size; i++) {
    if (uid->uidByte[i] < 0x10) uidStr += "0";
    uidStr += String(uid->uidByte[i], HEX);
  }
  return uidStr;
}

// Process incoming serial commands from Python bridge
void processSerialCommand() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    
    if (command.startsWith("GATE_CONTROL:")) {
      systemConnected = true; // Mark system as connected when we receive commands
      
      // Parse JSON command
      String jsonStr = command.substring(13); // Remove "GATE_CONTROL:" prefix
      

      
      // Simple JSON parsing - handle both with and without spaces
      if ((jsonStr.indexOf("\"gate\":\"entry\"") != -1 || jsonStr.indexOf("\"gate\": \"entry\"") != -1) && 
          (jsonStr.indexOf("\"action\":\"open\"") != -1 || jsonStr.indexOf("\"action\": \"open\"") != -1)) {
        // Check if this is a guard override command (no UID matching required)
        if (jsonStr.indexOf("\"override_mode\":\"guard_override\"") != -1 || jsonStr.indexOf("\"override_mode\": \"guard_override\"") != -1) {
          Serial.println("INFO: Guard override entry - opening gate");
          openEntryGateControlled();
        } else {
          // Regular entry command - check UID match
          String uidSearchString = "\"uid\":\"" + lastScannedUID + "\"";
          String uidSearchStringWithSpace = "\"uid\": \"" + lastScannedUID + "\"";
          
          int foundPos = jsonStr.indexOf(uidSearchString);
          if (foundPos == -1) {
            foundPos = jsonStr.indexOf(uidSearchStringWithSpace);
          }
          
          if (foundPos != -1) {
            Serial.println("INFO: UID verified - opening entry gate");
            openEntryGateControlled();
          } else {
            Serial.println("WARNING: UID mismatch - entry denied");
          }
        }
      } 
      else if ((jsonStr.indexOf("\"gate\":\"exit\"") != -1 || jsonStr.indexOf("\"gate\": \"exit\"") != -1) && 
               (jsonStr.indexOf("\"action\":\"open\"") != -1 || jsonStr.indexOf("\"action\": \"open\"") != -1)) {
        
        // Check if this is a guard override command (no UID matching required)
        if (jsonStr.indexOf("\"override_mode\":\"guard_override\"") != -1 || jsonStr.indexOf("\"override_mode\": \"guard_override\"") != -1) {
          Serial.println("INFO: Guard override exit - opening gate");
          openExitGateControlled();
        } else {
          // Regular exit command - check UID match
          String uidSearchString = "\"uid\":\"" + lastScannedUID + "\"";
          String uidSearchStringWithSpace = "\"uid\": \"" + lastScannedUID + "\"";
          
          int foundPos = jsonStr.indexOf(uidSearchString);
          if (foundPos == -1) {
            foundPos = jsonStr.indexOf(uidSearchStringWithSpace);
          }
          
          if (foundPos != -1) {
            Serial.println("INFO: UID verified - opening exit gate");
            openExitGateControlled();
          } else {
            Serial.println("WARNING: UID mismatch - exit denied");
          }
        }
      }
      else if ((jsonStr.indexOf("\"gate\":\"entry\"") != -1 || jsonStr.indexOf("\"gate\": \"entry\"") != -1) && 
               (jsonStr.indexOf("\"action\":\"deny\"") != -1 || jsonStr.indexOf("\"action\": \"deny\"") != -1)) {
        // Entry denied - play rejection sound
        String uidSearchString = "\"uid\":\"" + lastScannedUID + "\"";
        String uidSearchStringWithSpace = "\"uid\": \"" + lastScannedUID + "\"";
        if (jsonStr.indexOf(uidSearchString) != -1 || jsonStr.indexOf(uidSearchStringWithSpace) != -1) {
          playRejectionBuzzer();
        }
      }
      else if ((jsonStr.indexOf("\"gate\":\"exit\"") != -1 || jsonStr.indexOf("\"gate\": \"exit\"") != -1) && 
               (jsonStr.indexOf("\"action\":\"deny\"") != -1 || jsonStr.indexOf("\"action\": \"deny\"") != -1)) {
        // Exit denied - play rejection sound
        String uidSearchString = "\"uid\":\"" + lastScannedUID + "\"";
        String uidSearchStringWithSpace = "\"uid\": \"" + lastScannedUID + "\"";
        if (jsonStr.indexOf(uidSearchString) != -1 || jsonStr.indexOf(uidSearchStringWithSpace) != -1) {
          playRejectionBuzzer();
        }
      }
    }
    else if (command == "SYSTEM_CONNECTED") {
      systemConnected = true;
      lastHeartbeat = millis(); // Update heartbeat timestamp
      Serial.println("INFO: System heartbeat received");
    }
    else if (command == "MANUAL_GATE_OPEN_ENTRY") {
      manualGateControlActive = true;
      manualGatePosition = 0;
      smoothMove(myServo, myServo.read(), 0, 15);
      playSuccessBuzzer();
      Serial.println("INFO: Entry gate opened manually");
    }
    else if (command == "MANUAL_GATE_OPEN_EXIT") {
      manualGateControlActive = true;
      manualGatePosition = 180;
      smoothMove(myServo, myServo.read(), 180, 15);
      playSuccessBuzzer();
      Serial.println("INFO: Exit gate opened manually");
    }
    else if (command == "MANUAL_GATE_CLOSE") {
      manualGateControlActive = false;
      manualGatePosition = 90;
      smoothMove(myServo, myServo.read(), 90, 15);
      // Reset any automatic gate timers
      entryGateOpen = false;
      exitGateOpen = false;
      entryGateCloseTime = 0;
      exitGateCloseTime = 0;
      Serial.println("INFO: Gate closed manually");
    }
    else if (command == "TEST_SERVO") {
      Serial.println("INFO: Testing servo movement");
      
      // Test sequence: center -> left -> center -> right -> center
      smoothMove(myServo, myServo.read(), 90, 15);
      delay(1000);
      
      smoothMove(myServo, myServo.read(), 0, 15);
      delay(1000);
      
      smoothMove(myServo, myServo.read(), 90, 15);
      delay(1000);
      
      smoothMove(myServo, myServo.read(), 180, 15);
      delay(1000);
      
      smoothMove(myServo, myServo.read(), 90, 15);
      Serial.println("INFO: Servo test complete");
    }
  }
}

// Open entry gate under system control
void openEntryGateControlled() {
  // Don't operate if manual control is active
  if (manualGateControlActive) {
    Serial.println("WARNING: Manual control active - ignoring system command");
    return;
  }
  
  smoothMove(myServo, myServo.read(), 0, 15);
  entryGateOpen = true;
  entryGateCloseTime = millis() + gateOpenDuration;
  
  // Play success sound
  playSuccessBuzzer();
}

// Open exit gate under system control
void openExitGateControlled() {
  // Don't operate if manual control is active
  if (manualGateControlActive) {
    Serial.println("WARNING: Manual control active - ignoring system command");
    return;
  }
  
  smoothMove(myServo, myServo.read(), 180, 15);
  exitGateOpen = true;
  exitGateCloseTime = millis() + gateOpenDuration;
  
  // Play success sound
  playSuccessBuzzer();
}

// Play success buzzer pattern
void playSuccessBuzzer() {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
  delay(100);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
}

// Play rejection buzzer pattern
void playRejectionBuzzer() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
    digitalWrite(BUZZER_PIN, LOW);
    delay(150);
  }
}

void loop() {
  unsigned long now = millis();
  
  // Check for system heartbeat timeout
  if (lastHeartbeat > 0 && (now - lastHeartbeat) > heartbeatTimeout) {
    // System timeout - still keep gates under control but warn
    lastHeartbeat = 0;
    
    // Play timeout warning sound
    for (int i = 0; i < 2; i++) {
      digitalWrite(BUZZER_PIN, HIGH);
      delay(100);
      digitalWrite(BUZZER_PIN, LOW);
      delay(100);
    }
    
    Serial.println("SYSTEM_TIMEOUT");
    Serial.println("WARNING: System timeout - gates remain under system control");
  }
  
  // Process incoming serial commands from Python bridge
  processSerialCommand();

  // --- Scanner 1 (Entry) ---
  if (rfid1.PICC_IsNewCardPresent() && rfid1.PICC_ReadCardSerial()) {
    String uid = formatUID(&rfid1.uid);
    lastScannedUID = uid; // Store for verification
    
    Serial.print("entry:");
    Serial.println(uid);
    
    // Always under system control - just acknowledge and wait for command
    digitalWrite(BUZZER_PIN, HIGH);
    delay(50);
    digitalWrite(BUZZER_PIN, LOW);

    rfid1.PICC_HaltA();
    rfid1.PCD_StopCrypto1();
  }

  // --- Scanner 2 (Exit) ---
  if (rfid2.PICC_IsNewCardPresent() && rfid2.PICC_ReadCardSerial()) {
    String uid = formatUID(&rfid2.uid);
    lastScannedUID = uid; // Store for verification
    
    Serial.print("exit:");
    Serial.println(uid);
    
    // Always under system control - just acknowledge and wait for command
    digitalWrite(BUZZER_PIN, HIGH);
    delay(50);
    digitalWrite(BUZZER_PIN, LOW);

    rfid2.PICC_HaltA();
    rfid2.PCD_StopCrypto1();
  }

  // --- Timer check for Entry gate (only if not in manual control) ---
  if (!manualGateControlActive && entryGateOpen && now > entryGateCloseTime) {
    smoothMove(myServo, myServo.read(), 90, 15); // return smoothly
    entryGateOpen = false;
  }

  // --- Timer check for Exit gate (only if not in manual control) ---
  if (!manualGateControlActive && exitGateOpen && now > exitGateCloseTime) {
    smoothMove(myServo, myServo.read(), 90, 15); // return smoothly
    exitGateOpen = false;
  }
}
