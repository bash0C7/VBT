# Ruby Gemstone LED Demo with LCD Debug Display
# Tilt-responsive ruby pattern with real-time sensor data on LCD
# Neutral: USB port down, facing LED matrix while standing

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

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

# Initialize WS2812 - GPIO27 for ATOM Matrix
require 'rmt'

class WS2812
  def initialize(pin, brightness = 0.125)
    @rmt = RMT.new(
      pin,
      t0h_ns: 350,
      t0l_ns: 800,
      t1h_ns: 700,
      t1l_ns: 600,
      reset_ns: 60000)
    @brightness = brightness
  end

  def show(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = parse_color(color)
      # Apply brightness scaling
      r = (r * @brightness).to_i
      g = (g * @brightness).to_i
      b = (b * @brightness).to_i
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

leds = WS2812.new(27, 0.125)

# Initialize LCD with provided code
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Pre-allocate LED array - REUSE to avoid memory allocation
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Ruby gemstone pattern (5x5 matrix)
# □■■■□
# ■■■■■  
# □■■■□
# □□■□□
ruby_pattern = [
  0, 1, 1, 1, 0,
  1, 1, 1, 1, 1,
  0, 1, 1, 1, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 0, 0
]

# Color calculation function - Red to Pink to Purple based on tilt
def calculate_ruby_color(tilt_magnitude)
  # tilt_magnitude: 0.0 (vertical) to 1.0 (horizontal)
  # Red (0xFF0000) -> Pink (0xFF4080) -> Purple (0x8040FF)
  
  if tilt_magnitude < 0.5
    # Red to Pink transition
    t = tilt_magnitude * 2.0
    r = 255
    g = (64 * t).to_i
    b = (128 * t).to_i
  else
    # Pink to Purple transition
    t = (tilt_magnitude - 0.5) * 2.0
    r = (255 - 127 * t).to_i
    g = (64 - 24 * t).to_i
    b = (128 + 127 * t).to_i
  end
  
  # Ensure values are in valid range
  r = [[r, 0].max, 255].min
  g = [[g, 0].max, 255].min
  b = [[b, 0].max, 255].min
  
  (r << 16) | (g << 8) | b
end

# Convert 2D coordinates to 1D array index
def coord_to_index(x, y)
  return -1 if x < 0 || x >= 5 || y < 0 || y >= 5
  y * 5 + x
end

# Helper function to update LCD display
def update_lcd_display(i2c, rel_x, rel_y, tilt_magnitude)
  # Clear display and go to home position
  i2c.write(0x3e, 0, 0x01)
  sleep_ms 2
  
  # Line 1: X and Y relative values
  line1 = "X:#{rel_x.round(2)} Y:#{rel_y.round(2)}"
  line1.bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
  
  # Move to second line
  i2c.write(0x3e, 0, 0x80|0x40)
  
  # Line 2: Tilt magnitude
  line2 = "Tilt:#{tilt_magnitude.round(3)}"
  line2.bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
end

# Calibrate neutral position
# USB port down, facing LED matrix while standing
sleep_ms 1000  # Wait for stable position

neutral_x = 0.0
neutral_y = 0.0
neutral_z = 0.0

# Display calibration message
"Calibrating".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
i2c.write(0x3e, 0, 0x80|0x40)
"Hold steady".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }

15.times do
  acc = mpu.acceleration
  neutral_x = neutral_x + acc[:x]
  neutral_y = neutral_y + acc[:y] 
  neutral_z = neutral_z + acc[:z]
  sleep_ms 100
end

neutral_x = neutral_x / 15.0
neutral_y = neutral_y / 15.0
neutral_z = neutral_z / 15.0

# Display ready message
i2c.write(0x3e, 0, 0x01)
sleep_ms 2
"Ready!".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
sleep_ms 1000

# Main loop with LCD update counter
lcd_update_counter = 0

loop do
  # Get current acceleration
  acc = mpu.acceleration
  
  # Calculate relative movement from neutral
  rel_x = acc[:x] - neutral_x
  rel_y = acc[:y] - neutral_y
  rel_z = acc[:z] - neutral_z
  
  # Calculate tilt magnitude for color (0.0 to 1.0)
  tilt_magnitude = ((rel_x * rel_x + rel_y * rel_y) ** 0.5)
  tilt_magnitude = [[tilt_magnitude, 0.0].max, 1.0].min
  
  # Calculate ruby color based on tilt
  ruby_color = calculate_ruby_color(tilt_magnitude)
  
  # Calculate position shift (-2 to +2 range, then clamp)
  shift_x = (rel_x * 3.0).to_i
  shift_y = (rel_y * -3.0).to_i  # Invert Y for natural feel
  shift_x = [[-2, shift_x].max, 2].min
  shift_y = [[-2, shift_y].max, 2].min
  
  # Clear LED array
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Apply ruby pattern with position shift
  row = 0
  while row < 5
    col = 0
    while col < 5
      if ruby_pattern[row * 5 + col] == 1
        # Calculate shifted position
        new_x = col + shift_x
        new_y = row + shift_y
        
        # Set LED if position is valid
        index = coord_to_index(new_x, new_y)
        if index >= 0
          led_data[index] = ruby_color
        end
      end
      col = col + 1
    end
    row = row + 1
  end
  
  # Update LEDs
  leds.show(*led_data)
  
  # Update LCD every 5 cycles (500ms) to avoid flicker
  lcd_update_counter = lcd_update_counter + 1
  if lcd_update_counter >= 5
    update_lcd_display(i2c, rel_x, rel_y, tilt_magnitude)
    lcd_update_counter = 0
  end
  
  sleep_ms 100
end