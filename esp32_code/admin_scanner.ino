#include <SPI.h>
#include <MFRC522.h>

// Pin definitions (matched to your wiring)
#define RST_PIN    22  // RC522 Reset
#define SS_PIN     21  // RC522 SDA / NSS (you wired to GPIO21)
#define BUZZER_PIN 5   // Active buzzer wired to GPIO5

MFRC522 mfrc522(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(115200); // Use 115200 for ESP32 Serial Monitor
  delay(10);

  // Init SPI bus on ESP32 (SCK, MISO, MOSI)
  SPI.begin(18, 19, 23);

  // Init MFRC522
  mfrc522.PCD_Init();

  // Init buzzer pin
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.println("RFID reader initialized. Waiting for card...");
}

void loop() {
  // Look for new cards
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  // Read UID and format identical to your Uno sketch (lowercase hex, leading zero)
  String uid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) {
      uid += "0";
    }
    uid += String(mfrc522.uid.uidByte[i], HEX);
  }

  Serial.println(uid); // prints e.g. "0a1b2c3d"

  // Buzzer feedback (active buzzer)
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);

  // Halt PICC / stop crypto to avoid duplicate reads
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();

  delay(1000); // small debounce before next read
}
