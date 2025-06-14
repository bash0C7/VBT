# VBT LED Display - Stabilized Implementation for PicoRuby
# Fixed acceleration calculation, gravity calibration, and noise filtering

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

puts "VBT Stabilized Start"

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

# Pre-allocated LED array (25 LEDs)
led_data = Array.new(25, 0)

# Colors (low brightness)
ORANGE = 0x201000
SKYBLUE = 0x001820  
CYAN = 0x002020

# Configuration constants
MOTION_THRESHOLD = 1.5    # m/s² - motion detection threshold
DEADBAND_THRESHOLD = 0.3  # m/s² - noise elimination threshold
LOWPASS_ALPHA = 0.8       # Low-pass filter coefficient (0.0-1.0)
CALIBRATION_SAMPLES = 20  # Number of samples for gravity calibration

# State variables
gravity_baseline = 0.0
filtered_accel = 0.0
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0
motion_detected = false
prev_display_accel = 0
prev_display_vel = 0
last_change_time = Time.now.to_f * 1000
auto_dim_timeout = 3000

puts "Calibrating gravity baseline..."

# Gravity calibration - measure baseline acceleration when stationary
gravity_sum = 0.0
CALIBRATION_SAMPLES.times do |i|
  acc = mpu.acceleration
  # Correct 3-axis magnitude calculation
  magnitude = (acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z]) ** 0.5
  gravity_sum += magnitude
  puts "Cal #{i+1}/#{CALIBRATION_SAMPLES}: #{magnitude.round(3)}"
  sleep_ms 100
end

gravity_baseline = gravity_sum / CALIBRATION_SAMPLES
puts "Gravity baseline: #{gravity_baseline.round(3)}G"

# Helper function for acceleration processing
def process_acceleration(acc, gravity_baseline, prev_filtered)
  # Calculate correct 3-axis magnitude
  magnitude = (acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z]) ** 0.5
  
  # Remove gravity to get dynamic acceleration
  net_accel = magnitude - gravity_baseline
  
  # Apply deadband to eliminate noise
  net_accel = 0.0 if net_accel.abs < DEADBAND_THRESHOLD
  
  # Apply low-pass filter to smooth rapid changes
  filtered = prev_filtered * LOWPASS_ALPHA + net_accel * (1.0 - LOWPASS_ALPHA)
  
  # Ensure positive values only
  filtered = 0.0 if filtered < 0.0
  
  filtered
end

# Helper function for motion detection
def detect_motion(accel, current_motion, threshold)
  if accel >= threshold
    return true unless current_motion  # Start of new motion
  elsif accel < threshold * 0.5  # Hysteresis to prevent flickering
    return false if current_motion   # End of motion
  end
  current_motion  # Keep current state
end

puts "Starting measurement loop..."

# Main loop - stabilized and optimized
loop do
  current_time = Time.now.to_f * 1000
  
  # Read and process sensor data
  acc = mpu.acceleration
  filtered_accel = process_acceleration(acc, gravity_baseline, filtered_accel)
  
  # Motion detection with hysteresis
  prev_motion = motion_detected
  motion_detected = detect_motion(filtered_accel, motion_detected, MOTION_THRESHOLD)
  
  # Convert to m/s² for velocity integration and display
  accel_ms2 = filtered_accel * 9.81
  
  # Velocity integration only during motion
  if motion_detected
    current_vel += accel_ms2 * 0.2  # 200ms integration period
  else
    current_vel *= 0.95  # Gradual decay when stationary
  end
  
  # Update maximums only during significant motion
  if filtered_accel >= MOTION_THRESHOLD
    max_accel = accel_ms2 if accel_ms2 > max_accel
    max_vel = current_vel if current_vel > max_vel
  end
  
  # Calculate display values (LED count 0-10)
  display_accel = [(max_accel * 0.25).to_i, 10].min  # Scale for 40 m/s² max
  display_vel = [(max_vel * 5.0).to_i, 10].min       # Scale for 2 m/s max
  
  # Check if display values changed
  display_changed = (display_accel != prev_display_accel) || (display_vel != prev_display_vel)
  motion_state_changed = (motion_detected != prev_motion)
  
  # Reset change timer if values or motion state changed
  if display_changed || motion_state_changed
    last_change_time = current_time
    prev_display_accel = display_accel
    prev_display_vel = display_vel
  end
  
  # Auto-dimming check
  auto_dimmed = (current_time - last_change_time) > auto_dim_timeout
  
  # Update LEDs only when necessary
  if display_changed || motion_state_changed || auto_dimmed
    led_data.fill(0)
    
    unless auto_dimmed
      # Acceleration LEDs (rows 0-1, orange)
      display_accel.times { |idx| led_data[idx] = ORANGE }
      
      # Velocity LEDs (rows 2-3, sky blue)
      display_vel.times { |idx| led_data[10 + idx] = SKYBLUE }
      
      # Set indicator (cyan, blinking during motion)
      if motion_detected && ((current_time / 500).to_i % 2 == 0)
        led_data[24] = CYAN
      elsif !motion_detected
        led_data[24] = CYAN
      end
    end
    
    leds.show(*led_data)
  end
  
  # Debug output - reduced frequency and cleaner format
  if (current_time.to_i / 1000) % 2 == 0 && (current_time.to_i % 1000) < 200
    status = motion_detected ? "MOV" : "STA"
    puts "#{status} A:#{max_accel.round(1)} V:#{max_vel.round(1)}"
    
    # LCD display - show current motion state and values
    lcd_text = "#{status} #{max_accel.round(1)}m/s²"
    lcd_text.bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
  end
  
  sleep_ms 200
end
