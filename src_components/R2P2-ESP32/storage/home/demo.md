# Ruby Gemstone LED Demo Specification

## Overview
A tilt-responsive LED demonstration using M5Stack ATOM Matrix that displays a beautiful ruby gemstone pattern. The ruby moves like liquid following gravity and physics, with color changes based on motion intensity.

## Hardware Requirements
- **Device**: M5Stack ATOM Matrix
- **Sensor**: Built-in MPU6886 6-axis IMU
- **Display**: 5x5 WS2812 LED matrix
- **Debug Display**: Optional LCD (AE-AQM0802) via I2C
- **Power**: USB Type-C

## Features
### Visual Effects
- **Ruby Pattern**: Beautiful gemstone shape (□■■■□ ■■■■■ □■■■□ □□■□□)
- **Liquid Physics**: Natural gravity-based movement simulation
- **Dynamic Colors**: Motion-responsive color changes
- **Dramatic Range**: Ruby can flow completely off-screen

### Motion Response
- **Neutral Position**: USB port down, facing LED matrix while standing
- **Horizontal Tilt**: Ruby flows in the direction of tilt (left/right)
- **Vertical Tilt**: Ruby flows downward following gravity (natural liquid behavior)
- **Color Progression**: Red (static) → Pink (gentle motion) → Purple (active motion)

## Technical Specifications
### Performance
- **Update Rate**: 50ms (20 FPS) for responsive movement
- **LCD Update**: 1 second intervals to prevent flicker
- **Calibration**: 5-sample average over 1 second

### Memory Optimization
- **Target Platform**: PicoRuby on ESP32
- **String Operations**: Completely eliminated (ASCII direct write)
- **Memory Management**: Pre-allocated arrays, no dynamic allocation
- **Integer Math**: Fixed-point arithmetic for speed and stability

### Sensor Configuration
- **Accelerometer Range**: ±4G
- **Sensitivity**: 1/15 scaling for natural movement
- **Movement Range**: ±4 positions (can flow off-screen)
- **Color Thresholds**: 
  - Gentle motion: 400 (squared acceleration units)
  - Active motion: 1600 (squared acceleration units)

## Operation Sequence
1. **Startup**: Display "Ready" message, 3-second positioning time
2. **Calibration**: "Cal" display, collect neutral position over 1 second  
3. **Operation**: "OK" display, begin real-time demonstration
4. **Debug**: LCD shows X/Y relative movement values

## Physical Behavior
### Natural Physics Simulation
- **Left Tilt**: Ruby flows left (intuitive)
- **Right Tilt**: Ruby flows right (intuitive)  
- **Tilt Up**: Ruby flows down (gravity effect)
- **Tilt Down**: Ruby flows up (anti-gravity effect)

### Visual Feedback
- **Static State**: Deep red ruby, centered position
- **Light Movement**: Pink ruby, slight positional shift
- **Active Movement**: Purple ruby, dramatic flow effects
- **Extreme Tilt**: Ruby flows completely off visible area

## Color Specifications
- **Static Ruby**: `0xFF0000` (Deep Red)
- **Moving Ruby**: `0xFF4080` (Pink) 
- **Active Ruby**: `0x8040FF` (Purple)
- **Brightness**: 1/8 intensity for eye comfort

## Debug Information
- **LCD Display**: Real-time X/Y offset values
- **Format**: `X±n Y±n` (n = 0-9, # for larger values)
- **Update Rate**: 1 second intervals

## Development Notes
- Optimized for PicoRuby memory constraints
- No string interpolation or dynamic allocation
- Integer-only mathematics for performance
- Extensive commenting for maintainability
- Natural human-intuitive movement patterns
