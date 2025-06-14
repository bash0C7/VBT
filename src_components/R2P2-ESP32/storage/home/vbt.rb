# VBT LED Display - Memory Optimized for PicoRuby
# Ultra minimal implementation to avoid out of memory errors

# Round method for PicoRuby
class Float
  def round(digits = 0)
    if digits == 0
      if self >= 0
        (self + 0.5).to_i
      else
        (self - 0.5).to_i
      end
    else
      factor = 10.0 ** digits
      ((self * factor) + (self >= 0 ? 0.5 : -0.5)).to_i / factor.to_f
    end
  end
end

puts "VBT Start"

# Initialize I2C
require 'i2c'
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21
)

# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G

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

  # ex. show(0xff0000, 0x00ff00, 0x0000ff)  # Hexadecimal RGB values
  # or show([255, 0, 0], [0, 255, 0], [0, 0, 255]) # Array of RGB values
  def show(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = parse_color(color)
      bytes << g << r << b
    end

    @rmt.write(bytes)
  end

  def parse_color(color)
    if color.is_a?(Integer)
      [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF]
    else
      color
    end
  end
end

# Initialize WS2812 - GPIO27 for ATOM Matrix
#require 'WS2812'
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

  # ex. show(0xff0000, 0x00ff00, 0x0000ff)  # Hexadecimal RGB values
  # or show([255, 0, 0], [0, 255, 0], [0, 0, 255]) # Array of RGB values
  def show(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = parse_color(color)
      bytes << g << r << b
    end

    @rmt.write(bytes)
  end

  def parse_color(color)
    if color.is_a?(Integer)
      [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF]
    else
      color
    end
  end
end

leds = WS2812.new(27)

# Pre-allocate LED array - REUSE to avoid memory allocation
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Colors
orange = 0xFF8000
skyblue = 0x00BFFF
cyan = 0x00FFFF

# Variables - use simple types
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0

puts "Loop start"

# Main loop - memory optimized
loop do
  # Get acceleration
  acc = mpu.acceleration
  
  # Simple magnitude calculation (avoid sqrt to save memory)
  acc_mag = acc[:x] + acc[:y] + acc[:z]
  acc_mag = acc_mag > 0 ? acc_mag : -acc_mag  # abs value
  
  # Remove gravity estimate (1.0G)
  net_acc = acc_mag - 1.0
  net_acc = 0.0 if net_acc < 0.0
  
  # Simple velocity integration
  current_vel = current_vel + net_acc * 0.2  # 200ms = 0.2s
  
  # Update maximums
  max_accel = net_acc if net_acc > max_accel
  max_vel = current_vel if current_vel > max_vel
  
  # Clear LED array (reuse existing array)
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Display acceleration (rows 0-1, orange)
  accel_leds = (max_accel * 2.5).to_i  # Scale to 0-10 range
  accel_leds = 10 if accel_leds > 10
  
  i = 0
  while i < accel_leds
    led_data[i] = orange
    i = i + 1
  end
  
  # Display velocity (rows 2-3, sky blue)
  vel_leds = (max_vel * 5.0).to_i  # Scale to 0-10 range  
  vel_leds = 10 if vel_leds > 10
  
  i = 0
  while i < vel_leds
    led_data[10 + i] = skyblue  # Start from index 10 (row 2)
    i = i + 1
  end
  
  # Set number display (row 4, rightmost LED for set 1)
  led_data[24] = cyan  # Bottom right LED for set number 1
  
  # Update LEDs
  leds.show(*led_data)
  
  # Minimal debug output
  debug_string = "A:#{max_accel.round(1)} V:#{max_vel.round(1)}"
  puts debug_string
  debug_string.bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
i2c.write(0x3e, 0, 0x80|0x40)

  sleep_ms 250
end
