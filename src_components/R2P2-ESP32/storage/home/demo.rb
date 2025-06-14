# Ruby Gemstone LED Demo - Memory Optimized
# Minimal memory usage while preserving visual effects

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

# Initialize WS2812 - GPIO27 for ATOM Matrix
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
      if color.is_a?(Integer)
        r = ((color>>16)&0xFF) >> 3  # 1/8 brightness
        g = ((color>>8)&0xFF) >> 3
        b = (color&0xFF) >> 3
      else
        r = color[0] >> 3
        g = color[1] >> 3  
        b = color[2] >> 3
      end
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end
end

leds = WS2812.new(27)

# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Pre-allocated arrays - REUSE ONLY
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Ruby pattern as simple array
ruby_pos = [1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 17]  # Pre-calculated positions

# Color constants - avoid calculation
red = 0xFF0000
pink = 0xFF4080  
purple = 0x8040FF

# Calibration
neutral_x = 0
neutral_y = 0

"Calibrating".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }

# Quick calibration - reduce iterations
sum_x = 0
sum_y = 0
8.times do
  acc = mpu.acceleration
  sum_x = sum_x + (acc[:x] * 100).to_i  # Convert to integer
  sum_y = sum_y + (acc[:y] * 100).to_i
  sleep_ms 100
end
neutral_x = sum_x / 8
neutral_y = sum_y / 8

# Ready message
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
"Ready!".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }

# Main variables
counter = 0

# Main loop - ultra simplified
loop do
  # Get sensor data as integers
  acc = mpu.acceleration
  rel_x = (acc[:x] * 100).to_i - neutral_x
  rel_y = (acc[:y] * 100).to_i - neutral_y
  
  # Simple tilt calculation using integers
  tilt_sq = rel_x * rel_x + rel_y * rel_y
  
  # Color selection - simple threshold
  color = red
  if tilt_sq > 625   # ~0.25 squared * 10000
    color = pink
  end
  if tilt_sq > 2500  # ~0.5 squared * 10000
    color = purple
  end
  
  # Position shift - simplified
  shift_x = rel_x / 33  # Approximate /33 for good range
  shift_y = rel_y / -33
  shift_x = 2 if shift_x > 2
  shift_x = -2 if shift_x < -2
  shift_y = 2 if shift_y > 2
  shift_y = -2 if shift_y < -2
  
  # Clear LEDs - direct loop
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Apply pattern - simplified positioning
  ruby_pos.each do |pos|
    col = pos % 5
    row = pos / 5
    new_col = col + shift_x
    new_row = row + shift_y
    
    if new_col >= 0 && new_col < 5 && new_row >= 0 && new_row < 5
      led_data[new_row * 5 + new_col] = color
    end
  end
  
  # Update display
  leds.show(*led_data)
  
  # LCD update every 10 cycles
  counter = counter + 1
  if counter >= 10
    i2c.write(0x3e, 0, 0x01)
    sleep_ms 1
    
    # Simple display - avoid string operations
    if rel_x >= 0
      "X:+".bytes.each { |c| i2c.write(0x3e, 0x40, c) }
    else
      "X:-".bytes.each { |c| i2c.write(0x3e, 0x40, c) }
      rel_x = -rel_x
    end
    
    # Simple number display
    if rel_x < 10
      i2c.write(0x3e, 0x40, 48 + rel_x)  # ASCII '0' + digit
    else
      i2c.write(0x3e, 0x40, 35)  # '#' for large values
    end
    
    i2c.write(0x3e, 0, 0x80|0x40)  # Move to line 2
    
    if rel_y >= 0
      "Y:+".bytes.each { |c| i2c.write(0x3e, 0x40, c) }
    else
      "Y:-".bytes.each { |c| i2c.write(0x3e, 0x40, c) }
      rel_y = -rel_y
    end
    
    if rel_y < 10
      i2c.write(0x3e, 0x40, 48 + rel_y)
    else
      i2c.write(0x3e, 0x40, 35)
    end
    
    counter = 0
  end
  
  sleep_ms 100
end