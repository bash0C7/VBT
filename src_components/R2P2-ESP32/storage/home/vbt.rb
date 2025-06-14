# VBT LED Display - Memory Efficient Stabilized Version for PicoRuby
# Minimal changes to fix flickering while preserving memory efficiency

# Round method for PicoRuby
class Float
  def round(digits = 0)
    if digits == 0
      return (self + 0.5).to_i if self >= 0
      (self - 0.5).to_i
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

puts "VBT Memory Efficient Start"

# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G

# Initialize WS2812 LED
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
    return [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF] if color.is_a?(Integer)
    color
  end
end

leds = WS2812.new(27)

# Pre-allocated LED array (25 LEDs) - reuse same array
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Colors (low brightness)
orange = 0x201000
skyblue = 0x001820
cyan = 0x002020

# Simple calibration - measure gravity baseline
puts "Calibrating..."
gravity_sum = 0.0
10.times do
  acc = mpu.acceleration
  # Simple magnitude without sqrt - memory efficient approximation
  mag = acc[:x] + acc[:y] + acc[:z]
  mag = mag >= 0 ? mag : -mag
  gravity_sum = gravity_sum + mag
  sleep_ms 50
end
gravity_baseline = gravity_sum / 10.0
puts "Baseline: #{gravity_baseline.round(2)}"

# State variables - minimal set
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0
prev_accel_leds = 0
prev_vel_leds = 0
last_led_change = Time.now.to_f * 1000
smoothed_accel = 0.0

puts "Loop start"

# Main loop - memory optimized with minimal changes
loop do
  current_time = Time.now.to_f * 1000
  
  # Read sensor data
  acc = mpu.acceleration
  
  # Simple magnitude calculation - avoid sqrt
  acc_mag = acc[:x] + acc[:y] + acc[:z]
  acc_mag = acc_mag >= 0 ? acc_mag : -acc_mag
  
  # Remove gravity baseline
  net_acc = acc_mag - gravity_baseline
  net_acc = 0.0 if net_acc < 0.0
  
  # Simple noise reduction - ignore small values and smooth
  net_acc = 0.0 if net_acc < 0.2
  smoothed_accel = smoothed_accel * 0.7 + net_acc * 0.3
  
  # Convert to m/s² and update velocity
  accel_ms2 = smoothed_accel * 9.81
  current_vel = current_vel + accel_ms2 * 0.2
  
  # Update maximums only during significant motion
  if smoothed_accel > 0.15
    max_accel = accel_ms2 if accel_ms2 > max_accel
    max_vel = current_vel if current_vel > max_vel
  else
    current_vel = current_vel * 0.9  # Decay when stationary
  end
  
  # Calculate LED display values - Arduino compliant scaling
  # Acceleration: 0-40 m/s² → 0-10 LEDs
  accel_leds = (max_accel * 10.0 / 40.0).to_i
  accel_leds = 10 if accel_leds > 10
  
  # Velocity: 0-2 m/s → 0-10 LEDs
  vel_leds = (max_vel * 10.0 / 2.0).to_i
  vel_leds = 10 if vel_leds > 10
  
  # Check if LED values changed
  led_changed = (accel_leds != prev_accel_leds) || (vel_leds != prev_vel_leds)
  
  if led_changed
    last_led_change = current_time
    prev_accel_leds = accel_leds
    prev_vel_leds = vel_leds
  end
  
  # Auto-dimming: 2 seconds after last LED change
  auto_dimmed = (current_time - last_led_change) > 2000
  
  # Update LEDs only when values change or auto-dim state changes
  if led_changed || (auto_dimmed && led_data[0] != 0) || (!auto_dimmed && led_data[0] == 0)
    # Clear array efficiently
    i = 0
    while i < 25
      led_data[i] = 0
      i = i + 1
    end
    
    unless auto_dimmed
      # Set acceleration LEDs (rows 0-1)
      i = 0
      while i < accel_leds
        led_data[i] = orange
        i = i + 1
      end
      
      # Set velocity LEDs (rows 2-3)
      i = 0
      while i < vel_leds
        led_data[10 + i] = skyblue
        i = i + 1
      end
      
      # Set indicator (set 1) - bottom right
      led_data[24] = cyan
    end
    
    leds.show(*led_data)
  end
  
  # Minimal debug output
  if (current_time.to_i / 2000) % 2 == 0 && (current_time.to_i % 2000) < 200
    status = auto_dimmed ? "DIM" : (smoothed_accel > 0.15 ? "MOV" : "STA")
    puts "#{status} #{max_accel.round(1)},#{max_vel.round(1)}"
    "#{max_accel.round(1)}m/s".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
  end
  
  sleep_ms 200
end
