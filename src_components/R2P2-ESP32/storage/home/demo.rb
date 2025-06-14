# Ruby Gemstone Demo - Ultra Memory Optimized
# Minimal memory footprint for stable operation

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
      r = ((color>>16)&0xFF) >> 3
      g = ((color>>8)&0xFF) >> 3
      b = (color&0xFF) >> 3
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end
end

leds = WS2812.new(27)

# Initialize LCD - minimal
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Simple startup - avoid string operations
i2c.write(0x3e, 0x40, 82)  # 'R'
i2c.write(0x3e, 0x40, 101) # 'e'
i2c.write(0x3e, 0x40, 97)  # 'a'
i2c.write(0x3e, 0x40, 100) # 'd'
i2c.write(0x3e, 0x40, 121) # 'y'
sleep_ms 3000  # 3 second wait

# LED array - pre-allocated
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Ruby positions - simplified
ruby = [1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 17]

# Colors
red = 0xFF0000
pink = 0xFF4080
purple = 0x8040FF

# Calibration - minimal
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
i2c.write(0x3e, 0x40, 67)  # 'C'
i2c.write(0x3e, 0x40, 97)  # 'a'
i2c.write(0x3e, 0x40, 108) # 'l'

sum_x = 0
sum_y = 0
5.times do
  acc = mpu.acceleration
  sum_x = sum_x + (acc[:x] * 100).to_i
  sum_y = sum_y + (acc[:y] * 100).to_i
  sleep_ms 200
end
neutral_x = sum_x / 5
neutral_y = sum_y / 5

# Ready
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
i2c.write(0x3e, 0x40, 79)  # 'O'
i2c.write(0x3e, 0x40, 75)  # 'K'

# Main loop variables
counter = 0

# Main loop
loop do
  acc = mpu.acceleration
  rel_x = (acc[:x] * 100).to_i - neutral_x
  rel_y = (acc[:y] * 100).to_i - neutral_y
  
  # Color selection
  tilt_sq = rel_x * rel_x + rel_y * rel_y
  color = red
  color = pink if tilt_sq > 625
  color = purple if tilt_sq > 2500
  
  # Movement calculation  
  shift_x = rel_x / 15
  shift_y = rel_y / 15  # Natural Y direction (no inversion)
  shift_x = 4 if shift_x > 4
  shift_x = -4 if shift_x < -4
  shift_y = 4 if shift_y > 4
  shift_y = -4 if shift_y < -4
  
  # Clear LEDs
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Set ruby LEDs
  ruby.each do |pos|
    col = pos % 5
    row = pos / 5
    new_col = col + shift_x
    new_row = row + shift_y
    
    if new_col >= 0 && new_col < 5 && new_row >= 0 && new_row < 5
      led_data[new_row * 5 + new_col] = color
    end
  end
  
  leds.show(*led_data)
  
  # Simple LCD update
  counter = counter + 1
  if counter >= 20
    i2c.write(0x3e, 0, 0x01)
    sleep_ms 1
    
    # X value
    i2c.write(0x3e, 0x40, 88)  # 'X'
    if rel_x >= 0
      i2c.write(0x3e, 0x40, 43)  # '+'
      val = rel_x
    else
      i2c.write(0x3e, 0x40, 45)  # '-'
      val = -rel_x
    end
    
    if val < 10
      i2c.write(0x3e, 0x40, 48 + val)
    else
      i2c.write(0x3e, 0x40, 35)  # '#'
    end
    
    i2c.write(0x3e, 0, 0x80|0x40)
    
    # Y value
    i2c.write(0x3e, 0x40, 89)  # 'Y'
    if rel_y >= 0
      i2c.write(0x3e, 0x40, 43)  # '+'
      val = rel_y
    else
      i2c.write(0x3e, 0x40, 45)  # '-'
      val = -rel_y
    end
    
    if val < 10
      i2c.write(0x3e, 0x40, 48 + val)
    else
      i2c.write(0x3e, 0x40, 35)  # '#'
    end
    
    counter = 0
  end
  
  sleep_ms 50
end