## 🎯 基本指針
- **シンプルさを追求**：複雑化を避けて、じっくり考える
- **日本語出力**：プロンプトは日本語で語尾にピョン
- **コメント**：日本語で体言止め
- **ドキュメント**：README.mdは英語（ユーザー向け）

ファイルを変更したら適切な英語のメッセージでgit commitを行う

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Velocity-Based Training (VBT) system for ATOM Matrix ESP32 devices that measures and displays real-time weight training velocity and acceleration using IMU sensors. The system provides visual feedback through a 5×5 LED matrix and transmits data via Bluetooth Low Energy.

## Architecture

The project uses a hybrid architecture combining Arduino C++ and Ruby:

**Arduino Layer (`VBT.ino`)**:
- C++ firmware implementing core VBT measurement system
- Static class-based architecture (BLEManager, SensorManager, DisplayManager, StateManager, LogManager)
- Real-time sensor processing with state machine for measurement phases
- BLE communication and LittleFS data storage
- Memory-optimized design with pre-allocated buffers

**Ruby Layer (PicoRuby on ESP32)**:
- Ruby scripts for LED control, sensor demos, and VBT calculations
- Located in `src_components/R2P2-ESP32/storage/home/`
- Uses RMT peripheral for WS2812 LED control
- MPU6886 sensor integration for motion detection

**Build System**:
- Dual-layer build using ESP-IDF + R2P2-ESP32 (PicoRuby runtime)
- Ruby gems configured in `build_config/xtensa-esp.rb`
- Source components (`src_components/`) copied to build location (`components/`)

## Key Build Commands

**Initial setup**:
```bash
rake init
```

**Regular development build**:
```bash
rake build
```

**Update dependencies**:
```bash
rake update
```

**Clean rebuild**:
```bash
rake cleanbuild
```

**Check environment**:
```bash
rake check_env
```

**View all tasks**:
```bash
rake -T
```

## Development Environment

**Requirements**:
- ESP-IDF installed at `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL
- Git with submodule support

**Important Environment Variables**:
- All ESP-IDF environment setup is handled automatically by Rake tasks
- ESPBAUD=115200 for flashing
- OpenSSL paths configured for Homebrew installation

## File Structure Logic

- **Project Root**: Arduino sketch and build configuration
- **`src_components/`**: Source directory for ESP-IDF components (tracked in git)
- **`components/`**: Build-time directory (auto-generated, git-ignored)
- **`components/R2P2-ESP32/`**: Cloned PicoRuby runtime environment
- **Ruby Files**: Located in `src_components/R2P2-ESP32/storage/home/`

## Key Ruby Components

**`vbt.rb`**: Memory-efficient VBT implementation using squared acceleration values to avoid sqrt operations
**`demo.rb`**: Ruby gemstone demo with motion-responsive LED patterns
**`led.rb`**: WS2812 LED control library with brightness management

## Development Notes

- The Ruby runtime executes on ESP32 via PicoRuby, accessed through R2P2-ESP32 components
- All Ruby gems are configured in `build_config/xtensa-esp.rb`
- LED patterns use RMT peripheral for precise timing control
- Memory optimization is critical - use pre-allocated arrays and avoid dynamic allocation
- Sensor calibration uses squared values to eliminate expensive sqrt operations
- VBT calculations prioritize real-time performance over precision