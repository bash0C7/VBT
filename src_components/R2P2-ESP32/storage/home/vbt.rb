# VBT LED Display - Omnidirectional Motion Detection
# Proper 3-axis acceleration calculation for any training direction

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

# Sqrt approximation for PicoRuby (Babylonian method)
class Numeric
  def sqrt
    return 0.0 if self <= 0
    x = self.to_f
    guess = x / 2.0
    5.times do  # 5 iterations for reasonable accuracy
      guess = (guess + x / guess) / 2.0
    end
    guess
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

puts "VBT Omnidirectional Start"
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

# Pre-allocate LED array
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Colors - Low brightness
orange = 0x100800     # Acceleration display
skyblue = 0x000C10    # Velocity display  
cyan = 0x001010       # Set number display

# Gravity calibration - measure static 3-axis magnitude
puts "Calibrating gravity..."
gravity_sum = 0.0
10.times do
  acc = mpu.acceleration
  # Calculate proper 3-axis magnitude
  acc_magnitude = (acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z]).sqrt
  gravity_sum = gravity_sum + acc_magnitude
  sleep_ms 50
end
static_gravity = gravity_sum / 10.0
puts "Static gravity: #{static_gravity.round(2)}G"

# Variables
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0
movement_threshold = 0.15  # Threshold for motion detection (G units)

puts "Ready for omnidirectional training"

# Main loop - omnidirectional motion detection
loop do
  # Get 3-axis acceleration data
  acc = mpu.acceleration
  
  # Calculate proper 3-axis magnitude: sqrt(x² + y² + z²)
  # This works for ANY direction of movement
  acc_magnitude = (acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z]).sqrt
  
  # Remove gravity to get net acceleration (works for any orientation)
  net_accel_g = acc_magnitude - static_gravity
  net_accel_g = 0.0 if net_accel_g < movement_threshold
  
  # Convert to m/s² (Arduino compatible)
  net_accel_ms2 = net_accel_g * 9.81
  
  # Simple velocity integration (only when moving)
  if net_accel_g > movement_threshold
    current_vel = current_vel + net_accel_ms2 * 0.2  # 200ms integration step
    
    # Update maximums
    max_accel = net_accel_ms2 if net_accel_ms2 > max_accel
    max_vel = current_vel if current_vel > max_vel
  end
  
  # Calculate LED display (Arduino scaling: 40m/s² → 10 LEDs, 2m/s → 10 LEDs)
  accel_leds = (max_accel / 4.0).to_i  # 40m/s² / 10 LEDs = 4.0 per LED
  accel_leds = 10 if accel_leds > 10
  
  vel_leds = (max_vel / 0.2).to_i      # 2m/s / 10 LEDs = 0.2 per LED
  vel_leds = 10 if vel_leds > 10
  
  # Clear LED array
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Set acceleration LEDs (rows 0-1, orange)
  i = 0
  while i < accel_leds
    led_data[i] = orange
    i = i + 1
  end
  
  # Set velocity LEDs (rows 2-3, sky blue)
  i = 0
  while i < vel_leds
    led_data[10 + i] = skyblue
    i = i + 1
  end
  
  # Set number display (bottom right, cyan)
  led_data[24] = cyan
  
  # Update LEDs
  leds.show(*led_data)
  
  # Debug output with direction info
  motion_status = net_accel_g > movement_threshold ? "[MOVING]" : "[STATIC]"
  puts "#{motion_status} A:#{max_accel.round(1)}m/s² V:#{max_vel.round(1)}m/s Raw:#{acc_magnitude.round(2)}G"
  
  sleep_ms 200
end