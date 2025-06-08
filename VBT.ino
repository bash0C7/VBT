/**
 * ATOM-MATRIX VBT (Velocity Based Training) Measurement System - Refactored
 * * This device measures and displays real-time velocity and acceleration
 * during weight training using M5Stack ATOM-MATRIX's built-in IMU sensor.
 * Data is transmitted via BLE and saved to internal storage.
 * * Refactored for improved readability and maintainability while preserving
 * memory efficiency through static class design.
 */

#include <M5Atom.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <LittleFS.h>
#include <cstdarg> // Required for va_list in LogManager

// ===== Build Configuration =====
// Uncomment one of the following lines to control the build mode:
//#define DEVELOPMENT_BUILD   // For detailed debug and info logs
#define PRODUCTION_BUILD // For clean measurement and dump data only

// ===== BLE Configuration =====
#define BLE_DEVICE_NAME     "bashatommatrix"
#define BLE_SERVICE_UUID    "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_RX_CHAR_UUID    "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_TX_CHAR_UUID    "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ===== Display Configuration =====
#define DISPLAY_MATRIX_SIZE         5
#define DISPLAY_LED_BRIGHTNESS      20
#define DISPLAY_MAX_ACCEL_RANGE     40.0
#define DISPLAY_MAX_VELOCITY_RANGE  2.0

// ===== Sensor Configuration =====
#define SENSOR_GRAVITY_MS2          9.81
#define SENSOR_SAMPLE_INTERVAL_MS   20
#define SENSOR_MIN_ACCEL_THRESHOLD  1.5
#define SENSOR_MOVEMENT_TIMEOUT_MS  300

// ===== Timing Configuration =====
#define TIMING_COUNTDOWN_MS         5000
#define TIMING_BLINK_INTERVAL_MS    500
#define TIMING_DEBUG_INTERVAL_MS    1000
#define TIMING_DATA_OUTPUT_MS       500

// ===== Color Definitions =====
#define COLOR_WHITE      0xFFFFFF
#define COLOR_CYAN       0x00FFFF
#define COLOR_YELLOW     0xFFFF00
#define COLOR_GREEN      0x00FF00
#define COLOR_RED        0xFF0000
#define COLOR_ORANGE     0xFF8000
#define COLOR_SKY_BLUE   0x00BFFF
#define COLOR_OFF        0x000000

// ===== Log Configuration =====
#define LOG_FILE_PATH   "/measurement_log.csv"
#define LOG_BUFFER_SIZE 64 // Sufficient for most log messages

// ===== System States =====
enum SystemState {
  STATE_INIT,
  STATE_LOG_DUMP,
  STATE_LOG_DELETE,
  STATE_IDLE,
  STATE_COUNTDOWN,
  STATE_MEASURING,
  STATE_MOVEMENT_DETECTED
};

// ===== Forward Declarations =====
// 全てのクラスを前方宣言
class BLEManager;
class LogManager;
class DisplayManager;
class SensorManager;
class StateManager;

// ===== Global State Data =====
struct GlobalState {
  SystemState currentState = STATE_INIT;
  uint8_t trainingSetNumber = 1;
  float currentAcceleration = 0.0;
  float maxAcceleration = 0.0;
  float currentVelocity = 0.0;
  float maxVelocity = 0.0;
  bool movementDetected = false;
  bool bleConnected = false;
  bool bleWasConnected = false;
  String receivedCommand = "";
  
  // Timing
  unsigned long lastSampleTime = 0;
  unsigned long countdownStartTime = 0;
  unsigned long lastMovementTime = 0;
  unsigned long lastBlinkTime = 0;
  unsigned long lastDebugTime = 0;
  unsigned long lastDataOutputTime = 0;
  bool blinkState = false;
} g_state;

// ===== Display Manager Class =====
// DisplayManagerは他のクラスから参照されるため、早めに定義します。
class DisplayManager {
public:
  static void initialize() {
    M5.dis.setBrightness(DISPLAY_LED_BRIGHTNESS);
    M5.dis.clear();
  }
  
  static void clear() {
    M5.dis.clear();
  }
  
  static void showStatusLED(uint32_t color) {
    M5.dis.drawpix(0, 0, color);
  }
  
  static void showTrainingSetNumber(uint32_t color) {
    if (g_state.trainingSetNumber > 31) {
      for (uint8_t i = 0; i < 5; i++) {
        M5.dis.drawpix(i, 4, color);
      }
    } else {
      for (uint8_t i = 0; i < 5; i++) {
        bool bitSet = (g_state.trainingSetNumber & (1 << i)) > 0;
        M5.dis.drawpix(4 - i, 4, bitSet ? color : COLOR_OFF);
      }
    }
  }
  
  // Declaration only, definition moved later
  static void showMeasurementResults(); 
  
  static void clearRow(int row) {
    for (uint8_t i = 0; i < 5; i++) {
      M5.dis.drawpix(i, row, COLOR_OFF);
    }
  }
  
  static void showSuccess() {
    M5.dis.fillpix(COLOR_GREEN);
    delay(500);
  }
  
  static void showError() {
    M5.dis.fillpix(COLOR_RED);
    delay(2000);
  }
  
  static void updateMeasurementDisplay() {
    if (g_state.currentState == STATE_MEASURING || 
        g_state.currentState == STATE_MOVEMENT_DETECTED) {
      showMeasurementResults();
    }
    
    uint32_t color = COLOR_CYAN;
    if (g_state.currentState == STATE_MEASURING) color = COLOR_WHITE;
    else if (g_state.currentState == STATE_MOVEMENT_DETECTED) color = COLOR_GREEN;
    
    showTrainingSetNumber(color);
  }
};

// ===== Log Manager Class (fully defined here first) =====
// LogManager の定義をBLEManagerよりも前に持ってくる
class LogManager {
private:
  static char s_logBuffer[LOG_BUFFER_SIZE]; // LogManager専用の静的バッファ
public:
  static void initialize() {
    if (!LittleFS.begin(true)) {
#ifdef DEVELOPMENT_BUILD
      info("SYSTEM", "LITTLEFS_INIT_FAILED", 0.00, 0.00); 
#endif
      return;
    }
#ifdef DEVELOPMENT_BUILD
    info("SYSTEM", "LITTLEFS_READY", 0.00, 0.00); 
#endif
  }
  
  // Debug output (e.g., current state, sensor readings for debugging)
  static void debug(const char* format, ...) {
#ifdef DEVELOPMENT_BUILD
    va_list args;
    va_start(args, format);
    vsnprintf(s_logBuffer, LOG_BUFFER_SIZE, format, args);
    va_end(args);
    Serial.print("DEBUG,");
    Serial.println(s_logBuffer);
#endif
  }

  // Information/Notification output (e.g., system events, state changes)
  static void info(const char* tag, const char* message, float value1, float value2) {
#ifdef DEVELOPMENT_BUILD
    snprintf(s_logBuffer, LOG_BUFFER_SIZE, "%s,%s,%.2f,%.2f", tag, message, value1, value2);
    Serial.println(s_logBuffer);
#endif
  }

  // Incoming command output
  static void command(const char* cmd) {
#ifdef DEVELOPMENT_BUILD
    snprintf(s_logBuffer, LOG_BUFFER_SIZE, "COMMAND,%s,0.00", cmd);
    Serial.println(s_logBuffer);
#endif
  }

  // Measurement data output - Declaration only, definition moved after BLEManager
  static void measurement(uint8_t setNumber, float velocity, float acceleration);

  // Measurement results output - Declaration only, definition moved after BLEManager
  static void result(float maxAccel, float maxVel);
  
  static void dumpToSerial() {
    Serial.println("--- LOG DUMP START ---");
    
    File file = LittleFS.open(LOG_FILE_PATH, "r");
    if (!file) {
#ifdef DEVELOPMENT_BUILD
      info("SYSTEM", "LOGFILE_NOT_FOUND", 0.00, 0.00);
#endif
      Serial.println("--- LOG DUMP END ---");
      return;
    }
    
    while (file.available()) {
      Serial.write(file.read());
    }
    file.close();
    
    Serial.println("--- LOG DUMP END ---");
  }
  
  static void deleteFile(); // Declaration only, definition moved after DisplayManager
};

// LogManager::s_logBufferの定義
char LogManager::s_logBuffer[LOG_BUFFER_SIZE];

// LogManager::deleteFile の定義 (DisplayManagerを参照)
void LogManager::deleteFile() {
  if (LittleFS.remove(LOG_FILE_PATH)) {
#ifdef DEVELOPMENT_BUILD
    LogManager::info("SYSTEM", "LOGFILE_DELETED", 0.00, 0.00); 
#endif
    DisplayManager::showSuccess();
  } else {
#ifdef DEVELOPMENT_BUILD
    LogManager::info("SYSTEM", "LOGFILE_DELETE_FAILED", 0.00, 0.00); 
#endif
    DisplayManager::showError();
  }
}

// DisplayManager::showMeasurementResults の定義 (LogManager::result を参照)
void DisplayManager::showMeasurementResults() {
  clear();
  
  // Display acceleration (rows 0-1, orange)
  int accelLEDs = map(g_state.maxAcceleration, 0, DISPLAY_MAX_ACCEL_RANGE, 0, 10);
  accelLEDs = constrain(accelLEDs, 0, 10);
  
  for (uint8_t i = 0; i < accelLEDs; i++) {
    uint8_t row = i / 5;
    uint8_t col = i % 5;
    M5.dis.drawpix(col, row, COLOR_ORANGE);
  }
  
  // Display velocity (rows 2-3, sky blue)
  int velLEDs = map(g_state.maxVelocity, 0, DISPLAY_MAX_VELOCITY_RANGE, 0, 10);
  velLEDs = constrain(velLEDs, 0, 10);
  
  for (uint8_t i = 0; i < velLEDs; i++) {
    uint8_t row = 2 + (i / 5);
    uint8_t col = i % 5;
    M5.dis.drawpix(col, row, COLOR_SKY_BLUE);
  }
  
#ifdef DEVELOPMENT_BUILD
  LogManager::result(g_state.maxAcceleration, g_state.maxVelocity); 
#endif
}

// ===== BLE Manager Class (fully defined after LogManager) =====
class BLEManager {
private:
  static BLEServer* server;
  static BLECharacteristic* txCharacteristic;
  
  class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
      g_state.bleConnected = true;
#ifdef DEVELOPMENT_BUILD
      LogManager::info("SYSTEM", "CONNECTED", 0.00, 0.00); // LogManagerが完全に定義されたのでOK
#endif
    }
    
    void onDisconnect(BLEServer* pServer) override {
      g_state.bleConnected = false;
#ifdef DEVELOPMENT_BUILD
      LogManager::info("SYSTEM", "DISCONNECTED", 0.00, 0.00); // LogManagerが完全に定義されたのでOK
#endif
    }
  };
  
  class CharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) override; // Declaration only, definition moved later
  };

public:
  static void initialize() {
    BLEDevice::init(BLE_DEVICE_NAME);
    
    server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());
    
    BLEService *service = server->createService(BLE_SERVICE_UUID);
    
    BLECharacteristic *rxChar = service->createCharacteristic(
      BLE_RX_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
    rxChar->setCallbacks(new CharacteristicCallbacks());
    
    txCharacteristic = service->createCharacteristic(
      BLE_TX_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    txCharacteristic->addDescriptor(new BLE2902());
    
    service->start();
    
    BLEAdvertising *advertising = BLEDevice::getAdvertising();
    advertising->addServiceUUID(BLE_SERVICE_UUID);
    advertising->setScanResponse(false);
    advertising->setMinPreferred(0x0);
    BLEDevice::startAdvertising();
    
#ifdef DEVELOPMENT_BUILD
    LogManager::info("SYSTEM", "BLE_READY", 0.00, 0.00); // LogManagerが完全に定義されたのでOK
#endif
  }
  
  static void manageConnection() {
    if (!g_state.bleConnected && g_state.bleWasConnected) {
      delay(100);
      server->startAdvertising();
#ifdef DEVELOPMENT_BUILD
      LogManager::info("SYSTEM", "ADVERTISING", 0.00, 0.00); // LogManagerが完全に定義されたのでOK
#endif
      g_state.bleWasConnected = g_state.bleConnected;
    }
    
    if (g_state.bleConnected && !g_state.bleWasConnected) {
      g_state.bleWasConnected = g_state.bleConnected;
    }
  }
  
  static void sendData(const char* data) {
    if (g_state.bleConnected && txCharacteristic) {
      txCharacteristic->setValue(data);
      txCharacteristic->notify();
    }
  }
};

// Static member definitions
BLEServer* BLEManager::server = nullptr;
BLECharacteristic* BLEManager::txCharacteristic = nullptr;

// ===== LogManagerの、BLEManagerに依存するメソッドの定義 (BLEManagerの定義後) =====
void LogManager::measurement(uint8_t setNumber, float velocity, float acceleration) {
  File file = LittleFS.open(LOG_FILE_PATH, "a");
  if (!file) {
#ifdef DEVELOPMENT_BUILD
    info("SYSTEM", "FILE_OPEN_FAILED", 0.00, 0.00);
#endif
    return;
  }
  
  file.printf("%lu,%d,%.2f,%.2f\n", 
              millis(), setNumber, velocity, acceleration);
  file.close();

  // Always send via BLE and Serial for measurement data
  snprintf(s_logBuffer, LOG_BUFFER_SIZE, "MEA,%d,%.2f,%.2f\n", setNumber, velocity, acceleration);
  BLEManager::sendData(s_logBuffer);
  Serial.print(s_logBuffer);
}

void LogManager::result(float maxAccel, float maxVel) {
  snprintf(s_logBuffer, LOG_BUFFER_SIZE, "RES,%.2f,%.2f", maxAccel, maxVel);
  Serial.println(s_logBuffer); // Always print result to Serial
  BLEManager::sendData(s_logBuffer); // Always send result via BLE
}

// ===== State Manager Class =====
// StateManager は BLEManager と SensorManager から参照されるが、
// そのメソッド自体が BLEManager や SensorManager、DisplayManager を参照するため、
// ここで宣言し、後でメソッドを定義します。
class StateManager {
public:
  static void transitionToInit();
  static void transitionToLogDump();
  static void transitionToLogDelete();
  static void transitionToIdle();
  static void transitionToCountdown();
  static void transitionToMeasuring();
  static void transitionToMovementDetected();
  
  static void handleInitState();
  static void handleLogDumpState();
  static void handleLogDeleteState();
  static void handleIdleState();
  static void handleCountdownState(unsigned long currentTime);
  static void handleMeasurementState(unsigned long currentTime);
  
  static void processState(unsigned long currentTime);
};


// BLEManager::CharacteristicCallbacks::onWrite の定義は、StateManager が完全に定義された後に行います。
void BLEManager::CharacteristicCallbacks::onWrite(BLECharacteristic *pCharacteristic) {
  g_state.receivedCommand = pCharacteristic->getValue();
  
  if (g_state.receivedCommand.length() > 0) {
#ifdef DEVELOPMENT_BUILD
    LogManager::command(g_state.receivedCommand.c_str()); 
#endif
    
    if (g_state.receivedCommand.equals("RESET")) {
      StateManager::transitionToCountdown(); 
    }
  }
}

// ===== Sensor Manager Class =====
// SensorManager は StateManager, BLEManager, LogManager を参照するため、
// それらが完全に定義された後にそのメソッドを定義します。
class SensorManager {
public:
  static void initialize() {
    delay(50);
    M5.IMU.Init();
  }
  
  static void resetMeasurementData() {
    g_state.currentAcceleration = 0.0;
    g_state.maxAcceleration = 0.0;
    g_state.currentVelocity = 0.0;
    g_state.maxVelocity = 0.0;
    g_state.movementDetected = false;
  }
  
  static void processSensorData(unsigned long currentTime); // 宣言
  // No direct output for outputMeasurementData, it calls LogManager::measurement
  
  static void outputDebugInfo(unsigned long currentTime) {
#ifdef DEVELOPMENT_BUILD // Only output debug info in development build
    const char* stateName;
    switch(g_state.currentState) {
      case STATE_INIT:              stateName = "INIT"; break;
      case STATE_LOG_DUMP:          stateName = "LOGDUMP"; break;
      case STATE_LOG_DELETE:        stateName = "LOGDEL"; break;
      case STATE_IDLE:              stateName = "IDLE"; break;
      case STATE_COUNTDOWN:         stateName = "COUNTDOWN"; break;
      case STATE_MEASURING:         stateName = "MEASURING"; break;
      case STATE_MOVEMENT_DETECTED: stateName = "MOVEMENT"; break;
      default:                      stateName = "UNKNOWN"; break;
    }
    
    int timeoutRemaining = -1;
    if (g_state.currentState == STATE_MOVEMENT_DETECTED) {
      int remaining = SENSOR_MOVEMENT_TIMEOUT_MS - (currentTime - g_state.lastMovementTime);
      timeoutRemaining = (remaining > 0) ? remaining : 0;
    }
    
    LogManager::debug("%s,%.2f,%d", stateName, g_state.currentAcceleration, timeoutRemaining); 
#endif
  }
};

// SensorManager::processSensorData の定義は、StateManager が完全に定義された後に行います。
void SensorManager::processSensorData(unsigned long currentTime) {
  float accX, accY, accZ;
  M5.IMU.getAccelData(&accX, &accY, &accZ);
  
  float totalAccel = sqrt(accX*accX + accY*accY + accZ*accZ) * SENSOR_GRAVITY_MS2;
  g_state.currentAcceleration = totalAccel - SENSOR_GRAVITY_MS2;
  
  if (g_state.currentAcceleration < 0) {
    g_state.currentAcceleration = 0;
  }
  
  float deltaTime = (currentTime - g_state.lastSampleTime) / 1000.0;
  
  // Detect movement start
  if (g_state.currentState == STATE_MEASURING && 
      g_state.currentAcceleration >= SENSOR_MIN_ACCEL_THRESHOLD) {
    StateManager::transitionToMovementDetected(); 
    g_state.lastMovementTime = currentTime;
    g_state.movementDetected = true;
    g_state.currentVelocity = 0.0;
    
#ifdef DEVELOPMENT_BUILD
    LogManager::info("DETECTION", "MOVEMENT_START", g_state.currentAcceleration, 0.00); 
#endif
  }
  
  // Process movement
  if (g_state.currentState == STATE_MOVEMENT_DETECTED) {
    g_state.currentVelocity += g_state.currentAcceleration * deltaTime;
    
    if (g_state.currentAcceleration > g_state.maxAcceleration) {
      g_state.maxAcceleration = g_state.currentAcceleration;
#ifdef DEVELOPMENT_BUILD
      LogManager::info("MAX_ACCEL", "UPDATE", g_state.maxAcceleration, 0.00); 
#endif
    }
    
    if (g_state.currentVelocity > g_state.maxVelocity) {
      g_state.maxVelocity = g_state.currentVelocity;
#ifdef DEVELOPMENT_BUILD
      LogManager::info("MAX_VELOCITY", "UPDATE", g_state.maxVelocity, 0.00); 
#endif
    }
    
    if (currentTime - g_state.lastMovementTime >= SENSOR_MOVEMENT_TIMEOUT_MS) {
#ifdef DEVELOPMENT_BUILD
      LogManager::info("MOVEMENT_END", "TIMEOUT", 0.00, 0.00); 
#endif
      StateManager::transitionToMeasuring(); 
    }
  }
}

// SensorManager has no direct outputMeasurementData method anymore; it calls LogManager::measurement
// This function will be called by StateManager::handleMeasurementState
static void sensorOutputMeasurementData() {
  float velocity = g_state.movementDetected ? g_state.currentVelocity : 0.0;
  float acceleration = g_state.movementDetected ? g_state.currentAcceleration : 0.0;
  
  // Always output measurement data
  LogManager::measurement(g_state.trainingSetNumber, velocity, acceleration); 
}


// StateManager のメソッド定義 (他の全てのクラスが定義された後)
void StateManager::transitionToInit() {
  g_state.currentState = STATE_INIT;
  DisplayManager::clear();
}

void StateManager::transitionToLogDump() {
  g_state.currentState = STATE_LOG_DUMP;
  DisplayManager::clear();
}

void StateManager::transitionToLogDelete() {
  g_state.currentState = STATE_LOG_DELETE;
  DisplayManager::clear();
}

void StateManager::transitionToIdle() {
  g_state.currentState = STATE_IDLE;
#ifdef DEVELOPMENT_BUILD
  LogManager::info("STATE", "IDLE", 0.00, 0.00); 
#endif
  DisplayManager::clear();
  SensorManager::resetMeasurementData();
  DisplayManager::updateMeasurementDisplay();
}

void StateManager::transitionToCountdown() {
  g_state.currentState = STATE_COUNTDOWN;
#ifdef DEVELOPMENT_BUILD
  LogManager::info("STATE", "COUNTDOWN", 0.00, 0.00); 
#endif
  g_state.countdownStartTime = millis();
  g_state.lastBlinkTime = g_state.countdownStartTime;
  g_state.blinkState = true;
  SensorManager::resetMeasurementData();
  DisplayManager::clear();
}

void StateManager::transitionToMeasuring() {
  g_state.currentState = STATE_MEASURING;
#ifdef DEVELOPMENT_BUILD
  LogManager::info("STATE", "MEASURING", 0.00, 0.00); 
#endif
  g_state.lastSampleTime = millis();
  g_state.movementDetected = false;
  DisplayManager::clear();
  DisplayManager::updateMeasurementDisplay();
}

void StateManager::transitionToMovementDetected() {
  g_state.currentState = STATE_MOVEMENT_DETECTED;
}

void StateManager::handleInitState() {
  DisplayManager::showStatusLED(COLOR_WHITE);
  
  if (M5.Btn.wasReleasefor(1000)) {
    transitionToLogDump();
  } else if (M5.Btn.wasReleased()) {
    transitionToIdle();
  }
}

void StateManager::handleLogDumpState() {
  DisplayManager::showStatusLED(COLOR_CYAN);
  
  if (M5.Btn.wasReleasefor(1000)) {
    LogManager::dumpToSerial();
    transitionToLogDelete();
  }
}

void StateManager::handleLogDeleteState() {
  DisplayManager::showStatusLED(COLOR_RED);
  
  if (M5.Btn.wasReleasefor(3000)) {
    LogManager::deleteFile();
    transitionToInit();
  }
}

void StateManager::handleIdleState() {
  DisplayManager::showTrainingSetNumber(COLOR_CYAN);
  
  if (M5.Btn.wasPressed()) {
    transitionToCountdown();
  }
}

void StateManager::handleCountdownState(unsigned long currentTime) {
  if (currentTime - g_state.lastBlinkTime >= TIMING_BLINK_INTERVAL_MS) {
    g_state.lastBlinkTime = currentTime;
    g_state.blinkState = !g_state.blinkState;
    
    if (g_state.blinkState) {
      DisplayManager::showTrainingSetNumber(COLOR_YELLOW);
    } else {
      DisplayManager::clearRow(4);
    }
  }
  
  if (currentTime - g_state.countdownStartTime >= TIMING_COUNTDOWN_MS) {
    transitionToMeasuring();
  }
  
  if (M5.Btn.wasPressed()) {
    transitionToIdle();
  }
}

void StateManager::handleMeasurementState(unsigned long currentTime) {
  if (currentTime - g_state.lastSampleTime >= SENSOR_SAMPLE_INTERVAL_MS) {
    SensorManager::processSensorData(currentTime);
    g_state.lastSampleTime = currentTime;
  }
  
  if (currentTime - g_state.lastDataOutputTime >= TIMING_DATA_OUTPUT_MS) {
    sensorOutputMeasurementData(); // Call the helper to output data
    g_state.lastDataOutputTime = currentTime;
  }
  
  if (currentTime - g_state.lastDebugTime >= TIMING_DEBUG_INTERVAL_MS) {
    SensorManager::outputDebugInfo(currentTime);
    g_state.lastDebugTime = currentTime;
  }
  
  if (g_state.currentState == STATE_MOVEMENT_DETECTED) {
    if (currentTime - g_state.lastBlinkTime >= TIMING_BLINK_INTERVAL_MS) {
      g_state.lastBlinkTime = currentTime;
      g_state.blinkState = !g_state.blinkState;
      
      if (g_state.blinkState) {
        DisplayManager::showTrainingSetNumber(COLOR_GREEN);
      } else {
        DisplayManager::clearRow(4);
      }
    }
  } else {
    DisplayManager::showTrainingSetNumber(COLOR_WHITE);
  }
  
  if (M5.Btn.wasPressed()) {
    g_state.trainingSetNumber++;
    transitionToIdle();
  }
}

void StateManager::processState(unsigned long currentTime) {
  switch (g_state.currentState) {
    case STATE_INIT:
      handleInitState();
      break;
      
    case STATE_LOG_DUMP:
      handleLogDumpState();
      break;
      
    case STATE_LOG_DELETE:
      handleLogDeleteState();
      break;
      
    case STATE_IDLE:
      handleIdleState();
      break;
      
    case STATE_COUNTDOWN:
      handleCountdownState(currentTime);
      break;
      
    case STATE_MEASURING:
    case STATE_MOVEMENT_DETECTED:
      handleMeasurementState(currentTime);
      break;
  }
}


// ===== Arduino Setup =====
void setup() {
  M5.begin(true, false, true);
  Serial.begin(115200);
  
  DisplayManager::initialize();
  SensorManager::initialize();
  LogManager::initialize();
  DisplayManager::updateMeasurementDisplay();
  
  delay(100);
  BLEManager::initialize();
  
  delay(500);
#ifdef DEVELOPMENT_BUILD
  LogManager::info("SYSTEM", "READY", 0.00, 0.00); 
#endif
}

// ===== Arduino Main Loop =====
void loop() {
  M5.update();
  unsigned long currentTime = millis();
  
  // Manage BLE connection periodically
  if (currentTime % 1000 < 5) {
    BLEManager::manageConnection();
  }
  
  // Process current state
  StateManager::processState(currentTime);
  
  delay(5);
}
