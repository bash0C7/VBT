# vbt

ATOM Matrixを使用してウェイトトレーニングの速度と加速度をリアルタイムで測定・表示する装置を実現します
- Velocity Based Training（VBT）手法を実装し、トレーニングの質を数値化・可視化します。
- 5×5のLEDマトリックスを使って直感的に結果を表示します
- Bluetooth Low Energy（BLE）を通じてスマートフォンへデータをリアルタイム送信します
- 測定データはLittleFSを使用してデバイス内部に保存され、後から参照可能です

詳細な仕様は以下docを参照してください
https://docs.google.com/document/d/1oe2xu4LA9d-4aYqymDxY2VGFpKa_j8ngO9hMCUcYLu4/edit?tab=t.0#heading=h.xutg4kgqj5vc

A PicoRuby application for ESP32 development using the `picotorokko` (ptrk) build system.

**Created**: 2025-12-31 12:05:15
**Author**: bash0C7

## Quick Start

### 1. Setup Environment

First, fetch the latest repository versions automatically:

```bash
ptrk env set --latest
```

Or, create an environment with specific repository commits:

```bash
ptrk env set main --commit <R2P2-ESP32-hash>
```

Optionally, specify different commits for picoruby-esp32 and picoruby:

```bash
ptrk env set main \
  --commit <R2P2-hash> \
  --esp32-commit <picoruby-esp32-hash> \
  --picoruby-commit <picoruby-hash>
```

### 2. Build Application

```bash
ptrk device build
```

This clones repositories, applies patches, and builds firmware for your application.

### 3. Flash to Device

```bash
ptrk device flash
```

### 4. Monitor Serial Output

```bash
ptrk device monitor
```

## Project Structure

- **`storage/home/`** — Your PicoRuby application code (git-managed)
- **`patch/`** — Customizations to R2P2-ESP32 and dependencies (git-managed)
- **`.cache/`** — Immutable repository snapshots (git-ignored)
- **`build/`** — Active build working directory (git-ignored)
- **`.ptrk_env/`** — Environment metadata (git-ignored)

## Documentation

- **`SPEC.md`** — Complete specification of ptrk commands (in picotorokko gem)
- **`CLAUDE.md`** — Development guidelines and conventions
- **[picotorokko README](https://github.com/picoruby/picotorokko)** — Gem documentation and examples

## Common Tasks

### List Defined Environments

```bash
ptrk env list
```

### Show Current Environment Details

```bash
ptrk env show main
```

### Export Changes as Patches

After editing files in `build/current/`, export changes:

```bash
ptrk env patch_export main
```

Then commit:

```bash
git add patch/ storage/home/
git commit -m "Update patches and application code"
```

### Switch Between Environments

First, create the new environment:

```bash
ptrk env set development --commit <hash>
```

Then, rebuild with the new environment:

```bash
ptrk device build
```

## Troubleshooting

For detailed troubleshooting and advanced usage, see the picotorokko gem documentation.

### Environment Not Found

Check available environments:

```bash
ptrk env list
```

Create a new one:

```bash
ptrk env set myenv --commit <hash>
```

### Build Fails

Try rebuilding from scratch:

```bash
ptrk device build
```

If the issue persists, verify the environment is correctly set:

```bash
ptrk env show main
```

## Support

For issues with the picotorokko gem, see:
- GitHub: https://github.com/picoruby/picotorokko/issues
- Documentation: https://github.com/picoruby/picotorokko#readme

For PicoRuby and R2P2-ESP32 issues, see:
- PicoRuby: https://github.com/picoruby/picoruby
- R2P2-ESP32: https://github.com/picoruby/R2P2-ESP32
