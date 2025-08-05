#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <RTClib.h>

#define HALL_PIN1 2
#define HALL_PIN2 3
#define SD_CS_PIN 4
#define WHEEL_CIRCUMFERENCE 0.29767
#define PULSES_PER_TURN 6
#define DEBOUNCE_MS 15
#define TIMEOUT 1500
#define MAX_DELTAS 3

RTC_DS3231 rtc;
File dataFile;

unsigned long lastSensor1Change = 0;
unsigned long lastSensor2Change = 0;

int lastSensor1State = LOW;
int lastSensor2State = LOW;

float maxSpeed = 0, totalDistance = 0;
bool sessionActive = false;
unsigned long lastSessionEndTime = 0;

unsigned long sessionStartTime = 0, lastPulseTime = 0;
DateTime sessionStartRTC, sessionEndRTC;

float deltas[MAX_DELTAS] = {0};
int deltaIndex = 0;
bool deltasFilled = false;

unsigned long lastDoublePulseMillis = 0;

String formatDateTime(DateTime dt) {
  char buf[20];
  sprintf(buf, "%02d.%02d.%04d %02d:%02d:%02d", dt.day(), dt.month(), dt.year(), dt.hour(), dt.minute(), dt.second());
  return String(buf);
}

String formatDecimal(float value) {
  char buf[10];
  dtostrf(value, 1, 2, buf);
  String str(buf); str.replace('.', ',');
  return str;
}

float computeAverageDelta() {
  float sum = 0;
  int count = deltasFilled ? MAX_DELTAS : deltaIndex;
  for (int i = 0; i < count; i++) sum += deltas[i];
  return (count > 0) ? sum / count : 0;
}

void endSession(const char* reason) {
  if (totalDistance < 0.01) {
    sessionActive = false;
    lastSessionEndTime = millis();
    lastDoublePulseMillis = 0;
    return;
  }

  sessionEndRTC = rtc.now();
  float duration = (lastPulseTime - sessionStartTime) / 1000.0;
  float avgSpeed = (duration > 0) ? totalDistance / duration : 0;

  Serial.print("⏹️ End: "); Serial.println(reason);
  Serial.print("Distance: "); Serial.print(totalDistance, 3); Serial.println(" m");
  Serial.print("Max speed: "); Serial.print(maxSpeed, 2); Serial.println(" m/s");
  Serial.print("Avg speed: "); Serial.print(avgSpeed, 2); Serial.println(" m/s");

  dataFile = SD.open("data.csv", FILE_WRITE);
  if (dataFile) {
    dataFile.print(formatDateTime(sessionStartRTC)); dataFile.print(";");
    dataFile.print(formatDateTime(sessionEndRTC)); dataFile.print(";");
    dataFile.print(formatDecimal(totalDistance)); dataFile.print(";");
    dataFile.print(formatDecimal(maxSpeed)); dataFile.print(";");
    dataFile.println(formatDecimal(avgSpeed));
    dataFile.close();
  }

  sessionActive = false;
  lastSessionEndTime = millis();
  lastDoublePulseMillis = 0;
}

void setup() {
  Serial.begin(9600);
  pinMode(HALL_PIN1, INPUT);
  pinMode(HALL_PIN2, INPUT);

  Wire.begin();
  rtc.begin();

  if (!SD.begin(SD_CS_PIN)) {
    Serial.println("Chyba SD karty"); while (1);
  }

  if (!SD.exists("data.csv")) {
    dataFile = SD.open("data.csv", FILE_WRITE);
    if (dataFile) {
      dataFile.println("Start;End;Distance(m);Max speed(m/s);Avg speed(m/s)");
      dataFile.close();
    }
  }
}

void loop() {
  unsigned long now = millis();

  int sensor1State = digitalRead(HALL_PIN1);
  int sensor2State = digitalRead(HALL_PIN2);

  if (sensor1State != lastSensor1State && (now - lastSensor1Change > DEBOUNCE_MS)) {
    lastSensor1Change = now;
    handlePulse(1, now);
  }

  if (sensor2State != lastSensor2State && (now - lastSensor2Change > DEBOUNCE_MS)) {
    lastSensor2Change = now;
    handlePulse(2, now);
  }

  lastSensor1State = sensor1State;
  lastSensor2State = sensor2State;

  if (sessionActive && (now - lastPulseTime > TIMEOUT)) {
    endSession("timeout");
  }
}

void handlePulse(int sensor, unsigned long now) {
  static int previousSensor = 0;
  static unsigned long previousPulseTime = 0;

  if (!sessionActive && sensor != previousSensor && (now - previousPulseTime <= TIMEOUT)) {
    sessionActive = true;
    sessionStartTime = now;
    sessionStartRTC = rtc.now();
    totalDistance = 0;
    maxSpeed = 0;
    deltaIndex = 0;
    deltasFilled = false;
    Serial.println("▶️ Start");
  }

  if ((sensor != previousSensor) && (now - previousPulseTime <= TIMEOUT)) {
    lastDoublePulseMillis = now;

    float delta = (now - lastPulseTime) / 1000.0;
    if (delta > 0.01) {
      deltas[deltaIndex++] = delta;
      if (deltaIndex >= MAX_DELTAS) { deltaIndex = 0; deltasFilled = true; }

      float avgDelta = computeAverageDelta();
      float speed = (WHEEL_CIRCUMFERENCE / PULSES_PER_TURN) / avgDelta;
      if (speed > maxSpeed) maxSpeed = speed;
      totalDistance += WHEEL_CIRCUMFERENCE / PULSES_PER_TURN;
    }
  }

  // One sensor is silent longer than timeout
  if (sessionActive) {
    if (sensor == 1 && (now - lastSensor2Change > TIMEOUT)) {
      endSession("sensor 2 silent too long");
      return;
    }
    if (sensor == 2 && (now - lastSensor1Change > TIMEOUT)) {
      endSession("sensor 1 silent too long");
      return;
    }
  }

  lastPulseTime = now;
  previousSensor = sensor;
  previousPulseTime = now;
}
