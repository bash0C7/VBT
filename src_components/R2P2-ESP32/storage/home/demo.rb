=begin
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

=end

# Ruby Gemstone Demo - Natural Motion Physics
# Liquid-like ruby movement following gravity and human intuition

# Initialize I2C
require 'i2c'
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21
)

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

# Initialize WS2812
require 'rmt'

class WS2812
  def initialize(pin)
    @rmt = RMT.new(
      pin,
      t0h_ns: 350,
      t0l_ns: 800,
      t1h_ns: 700,
      t1l_ns: 600,
      reset_ns: 60000)
  end

  def show(*colors)
    bytes = []
    colors.each do |color|
      # Apply 1/8 brightness for eye comfort
      r = ((color>>16)&0xFF) >> 3
      g = ((color>>8)&0xFF) >> 3
      b = (color&0xFF) >> 3
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end
end

leds = WS2812.new(27)

# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Simple startup message
i2c.write(0x3e, 0x40, 82)  # 'R'
i2c.write(0x3e, 0x40, 101) # 'e'
i2c.write(0x3e, 0x40, 97)  # 'a'
i2c.write(0x3e, 0x40, 100) # 'd'
i2c.write(0x3e, 0x40, 121) # 'y'
sleep_ms 3000  # Give user time to position device

# Pre-allocated LED array (reused every frame)
led_array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Ruby gemstone pattern positions (□■■■□ ■■■■■ □■■■□ □□■□□)
ruby_positions = [1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 17]

# Color constants - ruby progression
COLOR_RUBY_STATIC = 0xFF0000    # Deep red when still
COLOR_RUBY_MOVING = 0xFF4080    # Pink when gently moving  
COLOR_RUBY_ACTIVE = 0x8040FF    # Purple when actively tilted

# Motion sensitivity constants
MOTION_SENSITIVITY = 15         # Lower = more sensitive movement
MOVEMENT_RANGE = 4              # Maximum shift distance
GENTLE_MOTION_THRESHOLD = 400   # Squared threshold for pink
ACTIVE_MOTION_THRESHOLD = 1600  # Squared threshold for purple

# Calibration phase
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
i2c.write(0x3e, 0x40, 67)  # 'C'
i2c.write(0x3e, 0x40, 97)  # 'a' 
i2c.write(0x3e, 0x40, 108) # 'l'

# Collect neutral position (device held naturally)
neutral_x_sum = 0
neutral_y_sum = 0
5.times do
  sensor_data = mpu.acceleration
  neutral_x_sum = neutral_x_sum + (sensor_data[:x] * 100).to_i
  neutral_y_sum = neutral_y_sum + (sensor_data[:y] * 100).to_i
  sleep_ms 200
end
neutral_x = neutral_x_sum / 5
neutral_y = neutral_y_sum / 5

# Ready to start
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
i2c.write(0x3e, 0x40, 79)  # 'O'
i2c.write(0x3e, 0x40, 75)  # 'K'

# Main loop counter for LCD updates
lcd_update_count = 0

# Main rendering loop
loop do
  # Read current sensor state
  current_accel = mpu.acceleration
  
  # Calculate relative movement from neutral (integer math for speed)
  relative_x = (current_accel[:x] * 100).to_i - neutral_x
  relative_y = (current_accel[:y] * 100).to_i - neutral_y
  
  # Calculate motion intensity (squared to avoid expensive sqrt)
  motion_intensity = relative_x * relative_x + relative_y * relative_y
  
  # Select ruby color based on motion intensity
  ruby_color = COLOR_RUBY_STATIC
  if motion_intensity > GENTLE_MOTION_THRESHOLD
    ruby_color = COLOR_RUBY_MOVING
  end
  if motion_intensity > ACTIVE_MOTION_THRESHOLD
    ruby_color = COLOR_RUBY_ACTIVE
  end
  
  # Calculate liquid-like movement (gravity physics simulation)
  # Left/Right: tilt left -> ruby flows left (natural)
  horizontal_shift = relative_x / MOTION_SENSITIVITY
  
  # Up/Down: tilt up -> ruby flows down (like liquid following gravity)
  vertical_shift = relative_y / -MOTION_SENSITIVITY  # Negative for gravity effect
  
  # Clamp movement to screen boundaries
  if horizontal_shift > MOVEMENT_RANGE
    horizontal_shift = MOVEMENT_RANGE
  end
  if horizontal_shift < -MOVEMENT_RANGE
    horizontal_shift = -MOVEMENT_RANGE
  end
  if vertical_shift > MOVEMENT_RANGE
    vertical_shift = MOVEMENT_RANGE
  end
  if vertical_shift < -MOVEMENT_RANGE
    vertical_shift = -MOVEMENT_RANGE
  end
  
  # Clear LED array for this frame
  clear_index = 0
  while clear_index < 25
    led_array[clear_index] = 0
    clear_index = clear_index + 1
  end
  
  # Render ruby pattern with physics-based offset
  ruby_positions.each do |pattern_pos|
    # Convert 1D position to 2D coordinates
    base_col = pattern_pos % 5
    base_row = pattern_pos / 5
    
    # Apply movement offset
    shifted_col = base_col + horizontal_shift
    shifted_row = base_row + vertical_shift
    
    # Only draw if within screen bounds
    if shifted_col >= 0 && shifted_col < 5 && shifted_row >= 0 && shifted_row < 5
      array_index = shifted_row * 5 + shifted_col
      led_array[array_index] = ruby_color
    end
  end
  
  # Update LED display
  leds.show(*led_array)
  
  # Update LCD debug display (less frequently to avoid flicker)
  lcd_update_count = lcd_update_count + 1
  if lcd_update_count >= 20  # Every 1 second
    i2c.write(0x3e, 0, 0x01)
    sleep_ms 1
    
    # Display X (horizontal) movement
    i2c.write(0x3e, 0x40, 88)  # 'X'
    if relative_x >= 0
      i2c.write(0x3e, 0x40, 43)  # '+'
      display_val = relative_x
    else
      i2c.write(0x3e, 0x40, 45)  # '-'
      display_val = -relative_x
    end
    
    if display_val < 10
      i2c.write(0x3e, 0x40, 48 + display_val)  # ASCII digit
    else
      i2c.write(0x3e, 0x40, 35)  # '#' for large values
    end
    
    # Move to second line
    i2c.write(0x3e, 0, 0x80|0x40)
    
    # Display Y (vertical) movement  
    i2c.write(0x3e, 0x40, 89)  # 'Y'
    if relative_y >= 0
      i2c.write(0x3e, 0x40, 43)  # '+'
      display_val = relative_y
    else
      i2c.write(0x3e, 0x40, 45)  # '-'
      display_val = -relative_y
    end
    
    if display_val < 10
      i2c.write(0x3e, 0x40, 48 + display_val)  # ASCII digit
    else
      i2c.write(0x3e, 0x40, 35)  # '#' for large values
    end
    
    lcd_update_count = 0
  end
  
  # 50ms refresh rate for smooth, responsive movement
  sleep_ms 50
end