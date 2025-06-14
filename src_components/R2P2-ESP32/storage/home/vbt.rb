# VBT LED Display - Ultra Minimal for Memory Constraints
# Test step by step to identify working components

# PicoRuby round method implementation (ESSENTIAL)
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

puts "Starting ultra-minimal VBT test..."

# Test 1: Check basic functionality
puts "Test 1: Basic Ruby functionality"
test_var = 1.0
puts "Basic variable: #{test_var}"

# Test 2: Check I2C availability  
puts "Test 2: I2C library"
begin
  require 'i2c'
  puts "I2C library loaded"
  
  i2c = I2C.new(
    unit: :ESP32_I2C0,
    frequency: 100_000,
    sda_pin: 25,
    scl_pin: 21,
    timeout: 2000
  )
  puts "I2C initialized"
  
rescue => e
  puts "I2C error: #{e.message}"
end

# Test 3: MPU6886 (REQUIRED)
puts "Test 3: MPU6886 library (required)"
require 'mpu6886'
puts "MPU6886 library loaded"

mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G
puts "MPU6886 initialized with 8G range"

# Simple read test
accel = mpu.acceleration
puts "Acceleration: x=#{accel[:x].round(2)} y=#{accel[:y].round(2)} z=#{accel[:z].round(2)}"

# Test 4: WS2812 LED (REQUIRED)
puts "Test 4: WS2812 LED (required)"
require 'WS2812'
puts "WS2812 library loaded"

leds = WS2812.new(27)
puts "WS2812 initialized"

# Minimal LED test - just one color at a time
puts "Testing single LED..."
leds.show(0xFF0000, 0x000000, 0x000000, 0x000000, 0x000000)  # Only first LED red
sleep_ms 500
leds.show(0x000000, 0x000000, 0x000000, 0x000000, 0x000000)  # All off
sleep_ms 500

puts "LED test successful"

# Test 5: Minimal VBT loop (both MPU6886 and LED required)
puts "Test 5: Starting minimal VBT loop"

# Ultra-simple variables
max_accel = 0.0
cycle = 0

# Very simple loop - no arrays, minimal objects
10.times do
  cycle += 1
  
  # Get data
  accel_data = mpu.acceleration
  
  # Simple magnitude (avoid sqrt)
  accel_sum = accel_data[:x] + accel_data[:y] + accel_data[:z]
  accel_mag = accel_sum > 0 ? accel_sum : -accel_sum  # absolute value
  
  # Track maximum
  if accel_mag > max_accel
    max_accel = accel_mag
  end
  
  # Very simple LED: just first few LEDs based on acceleration
  if accel_mag > 1.2  # High acceleration
    leds.show(0xFF8000, 0xFF8000, 0xFF8000, 0x000000, 0x000000)  # 3 orange LEDs
  elsif accel_mag > 1.0  # Medium acceleration  
    leds.show(0xFF8000, 0xFF8000, 0x000000, 0x000000, 0x000000)  # 2 orange LEDs
  elsif accel_mag > 0.8  # Low acceleration
    leds.show(0xFF8000, 0x000000, 0x000000, 0x000000, 0x000000)  # 1 orange LED
  else
    leds.show(0x000000, 0x000000, 0x000000, 0x000000, 0x000000)  # All off
  end
  
  puts "Cycle #{cycle}: mag=#{accel_mag.round(2)} max=#{max_accel.round(2)}"
  
  sleep_ms 200
end

puts "Test completed successfully!"

puts "All tests completed successfully!"
