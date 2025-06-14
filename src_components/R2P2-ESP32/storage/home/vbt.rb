# VBT LED Display - Ultra Minimal Memory Fix
# Preserve original structure with minimal stability improvements

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

# Initialize I2C
require 'i2c'
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21
)

puts "VBT Start"
# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G

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

# Colors - Low brightness for eye comfort
orange = 0x201000
skyblue = 0x001820
cyan = 0x002020

# Quick gravity calibration - 5 samples only
puts "Cal"
g = 0.0
5.times do
  acc = mpu.acceleration
  g = g + acc[:x] + acc[:y] + acc[:z]
  sleep_ms 20
end
gravity = g / 5.0

# Variables - minimal set
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0
last_change = Time.now.to_f * 1000

puts "Start"

# Main loop - preserve original efficiency
loop do
  current_time = Time.now.to_f * 1000
  
  # Get acceleration - use simple approximation to avoid sqrt
  acc = mpu.acceleration
  acc_mag = acc[:x] + acc[:y] + acc[:z]
  acc_mag = acc_mag > 0 ? acc_mag : -acc_mag
  
  # Remove gravity and apply noise threshold
  net_acc = acc_mag - gravity
  net_acc = 0.0 if net_acc < 0.3  # Simple noise gate
  
  # Simple velocity integration
  current_vel = current_vel + net_acc * 9.81 * 0.2
  
  # Update maximums
  if net_acc > 0.2
    max_accel = net_acc * 9.81 if net_acc * 9.81 > max_accel
    max_vel = current_vel if current_vel > max_vel
  end
  
  # Calculate LEDs - Arduino scaling: 40m/s² → 10 LEDs, 2m/s → 10 LEDs
  accel_leds = (max_accel * 0.25).to_i
  accel_leds = 10 if accel_leds > 10
  vel_leds = (max_vel * 5.0).to_i
  vel_leds = 10 if vel_leds > 10
  
  # Auto-dimming after 2 seconds
  if accel_leds > 0 || vel_leds > 0
    last_change = current_time
  end
  
  dimmed = (current_time - last_change) > 2000
  
  # Clear LED array efficiently
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Set LEDs only if not dimmed
  unless dimmed
    # Acceleration LEDs (rows 0-1)
    i = 0
    while i < accel_leds
      led_data[i] = orange
      i = i + 1
    end
    
    # Velocity LEDs (rows 2-3)
    i = 0
    while i < vel_leds
      led_data[10 + i] = skyblue
      i = i + 1
    end
    
    # Set number (bottom right)
    led_data[24] = cyan
  end
  
  # Update LEDs
  leds.show(*led_data)
  
  # Minimal debug
  puts "#{max_accel.round(1)},#{max_vel.round(1)}"
  
  sleep_ms 200
end
