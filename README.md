# VBT

ATOM Matrixを使用してウェイトトレーニングの速度と加速度をリアルタイムで測定・表示する装置を実現します
- Velocity Based Training（VBT）手法を実装し、トレーニングの質を数値化・可視化します。
- 5×5のLEDマトリックスを使って直感的に結果を表示します
- Bluetooth Low Energy（BLE）を通じてスマートフォンへデータをリアルタイム送信します
- 測定データはLittleFSを使用してデバイス内部に保存され、後から参照可能です

詳細な仕様は以下docを参照してください
https://docs.google.com/document/d/1oe2xu4LA9d-4aYqymDxY2VGFpKa_j8ngO9hMCUcYLu4/edit?tab=t.0#heading=h.xutg4kgqj5vc

## VBT.ino

PoCの実装です

## Project Structure

```
VBT/
├── Rakefile                    # Build automation tasks
├── VBT.ino                    # PoC VBT Arduino sketch for ATOM Matrix
├── src_components/            # Source ESP-IDF components
├── components/                # ESP-IDF components (auto-generated, git-ignored)
│   └── R2P2-ESP32/           # Cloned R2P2-ESP32 repository
└── README.md                  # This file
```

## Path Roles

- **Project Root**: Contains the main Arduino sketch and project configuration
- **src_components/**: Source directory for ESP-IDF components that gets copied to the build environment
- **components/**: Build-time directory containing external ESP-IDF components (auto-generated, not tracked in git)
- **components/R2P2-ESP32/**: Cloned repository providing the build environment for PicoRuby on ESP32

## Build Tasks

Use Rake to manage the build process. All tasks automatically set up the required environment variables and ESP-IDF environment.

### Available Tasks

View all available tasks:
```bash
rake -T
```

### Task Descriptions

- **`rake setup`**: Initial project setup
  - Creates `components/` directory
  - Clones R2P2-ESP32 repository
  - Copies `src_components/` contents to build location
  - Performs full clean build

- **`rake update`**: Update project dependencies
  - Cleans git changes in R2P2-ESP32
  - Pulls latest changes with submodules
  - Re-copies `src_components/` contents
  - Performs full clean build

- **`rake cleanbuild`**: Clean build from scratch
  - Runs `idf.py fullclean`
  - Executes `rake setup_esp32`
  - Builds the project

- **`rake buildall`**: Build with setup
  - Executes `rake setup_esp32`
  - Builds the project

- **`rake build`**: Quick build (default)
  - Builds the project without cleanup or setup

### Usage Examples

Initial setup (first time):
```bash
rake setup
```

Regular development build:
```bash
rake build
```

Update dependencies:
```bash
rake update
```

Clean rebuild:
```bash
rake cleanbuild
```

## Environment Requirements

The Rakefile automatically configures the following environment:
- OpenSSL paths for Homebrew installation
- ESP-IDF environment variables
- GRPC build system configuration
- ESP32 baud rate settings

Make sure you have:
- ESP-IDF installed in `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL installed
- Git with submodule support
