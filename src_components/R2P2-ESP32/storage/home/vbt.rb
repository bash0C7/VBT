# VBT Accelerometer and Velocity LED Display
# Measures acceleration/velocity and displays on 5x5 LED matrix per specification
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


# Round method for PicoRuby compatibility
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

# Square root implementation for PicoRuby
def sqrt(x)
  return 0.0 if x <= 0.0
  
  # Newton's method for square root
  guess = x / 2.0
  3.times do
    guess = (guess + x / guess) / 2.0
  end
  guess
end

puts "VBT System Starting..."

# Initialize I2C for MPU6886
require 'i2c'
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000
)

# Initialize MPU6886 accelerometer
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G

# Initialize WS2812 LED matrix (ATOM Matrix uses GPIO27)
#require 'WS2812'
leds = WS2812.new(27)

# LED Colors from specification
COLOR_ORANGE    = 0xFF8000  # Acceleration display
COLOR_SKY_BLUE  = 0x00BFFF  # Velocity display  
COLOR_CYAN      = 0x00FFFF  # Set number (idle state)
COLOR_OFF       = 0x000000  # LED off

# VBT measurement variables
current_velocity = 0.0
max_acceleration = 0.0
max_velocity = 0.0
last_time = 0

# Configuration constants from specification
MAX_ACCEL_RANGE = 40.0    # m/s² display range
MAX_VELOCITY_RANGE = 2.0  # m/s display range
GRAVITY = 9.81           # m/s²

puts "Initialization complete. Starting measurement loop..."

# Clear all LEDs initially
led_array = Array.new(25, COLOR_OFF)
leds.show(*led_array)

# Main measurement loop - 200ms interval
loop do
  current_time = Time.now.to_f * 1000  # milliseconds
  
  # Calculate time delta for velocity integration
  if last_time > 0
    delta_time = (current_time - last_time) / 1000.0  # seconds
  else
    delta_time = 0.2  # Initial 200ms
  end
  last_time = current_time
  
  # Get 3-axis acceleration data
  accel_data = mpu.acceleration
  acc_x = accel_data[:x] * GRAVITY  # Convert to m/s²
  acc_y = accel_data[:y] * GRAVITY
  acc_z = accel_data[:z] * GRAVITY
  
  # Calculate 3-axis combined acceleration magnitude
  total_accel = sqrt(acc_x * acc_x + acc_y * acc_y + acc_z * acc_z)
  
  # Remove gravity to get net acceleration
  current_acceleration = total_accel - GRAVITY
  current_acceleration = 0.0 if current_acceleration < 0.0
  
  # Integrate acceleration to get velocity (simple integration)
  current_velocity += current_acceleration * delta_time
  
  # Update maximum values
  max_acceleration = current_acceleration if current_acceleration > max_acceleration
  max_velocity = current_velocity if current_velocity > max_velocity
  
  # Create LED array (5x5 = 25 LEDs)
  led_array = Array.new(25, COLOR_OFF)
  
  # Display acceleration on rows 0-1 (orange LEDs)
  accel_leds = ((max_acceleration / MAX_ACCEL_RANGE) * 10).to_i
  accel_leds = 10 if accel_leds > 10
  accel_leds = 0 if accel_leds < 0
  
  (0...accel_leds).each do |i|
    row = i / 5
    col = i % 5
    led_index = row * 5 + col
    led_array[led_index] = COLOR_ORANGE
  end
  
  # Display velocity on rows 2-3 (sky blue LEDs)  
  velocity_leds = ((max_velocity / MAX_VELOCITY_RANGE) * 10).to_i
  velocity_leds = 10 if velocity_leds > 10
  velocity_leds = 0 if velocity_leds < 0
  
  (0...velocity_leds).each do |i|
    row = 2 + (i / 5)  # Start from row 2
    col = i % 5
    led_index = row * 5 + col
    led_array[led_index] = COLOR_SKY_BLUE
  end
  
  # Display set number on row 4 (cyan color for idle state)
  # Show binary representation of set number 1 (always 1 for this simple version)
  set_number = 1
  (0...5).each do |i|
    bit_value = (set_number >> i) & 1
    led_index = 4 * 5 + (4 - i)  # Row 4, right to left
    led_array[led_index] = bit_value > 0 ? COLOR_CYAN : COLOR_OFF
  end
  
  # Update LED display
  leds.show(*led_array)
  
  # Debug output
  puts "Accel: #{current_acceleration.round(2)}m/s² | Vel: #{current_velocity.round(2)}m/s | Max A: #{max_acceleration.round(2)} | Max V: #{max_velocity.round(2)}"
  
  # 200ms delay
  sleep_ms 200
end
