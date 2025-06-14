# VBT LED Display - Minimal Sensor Test
# Start with basic sensor reading to verify functionality
require 'i2c'
require 'mpu6886'

puts "Starting VBT sensor test..."

# Initialize I2C using confirmed working configuration
puts "Initializing I2C..."
i2c = I2C.new(
  unit: :ESP32_I2C0,      # Use symbol format (confirmed working)
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000           # Add timeout parameter
)

sleep_ms 200
puts "I2C initialized successfully"

# Initialize MPU6886 sensor
puts "Initializing MPU6886..."
mpu = MPU6886.new(i2c)

# Set sensor configuration
puts "Configuring sensor..."
mpu.accel_range = MPU6886::ACCEL_RANGE_8G
mpu.gyro_range = MPU6886::GYRO_RANGE_500DPS

puts "Sensor configured. Starting basic measurement loop..."

# Simple variables for tracking
current_acceleration = 0.0
max_acceleration = 0.0
current_velocity = 0.0
max_velocity = 0.0
movement_detected = false
cycle_count = 0

# Constants
GRAVITY = 9.81
THRESHOLD = 1.5

puts "System ready. Starting 200ms measurement loop..."

# Basic measurement loop
loop do
  cycle_count += 1
  
  begin
    # Read sensor data
    accel_data = mpu.acceleration
    
    # Calculate magnitude (simple approximation for now)
    # Using simpler calculation to avoid potential sqrt issues
    accel_x_abs = accel_data[:x] > 0 ? accel_data[:x] : -accel_data[:x]
    accel_y_abs = accel_data[:y] > 0 ? accel_data[:y] : -accel_data[:y]  
    accel_z_abs = accel_data[:z] > 0 ? accel_data[:z] : -accel_data[:z]
    
    # Rough magnitude approximation (faster than sqrt)
    accel_magnitude = (accel_x_abs + accel_y_abs + accel_z_abs) * 0.577 # ~1/sqrt(3)
    
    # Convert to m/s² and remove gravity
    total_accel = accel_magnitude * GRAVITY
    current_acceleration = total_accel - GRAVITY
    current_acceleration = 0.0 if current_acceleration < 0
    
    # Simple movement detection
    if current_acceleration >= THRESHOLD
      if !movement_detected
        puts "Movement started!"
        movement_detected = true
        current_velocity = 0.0
      end
      # Integrate velocity (simple Euler method)
      current_velocity += current_acceleration * 0.2  # 200ms = 0.2s
    else
      if movement_detected
        puts "Movement ended. Max accel: #{max_acceleration.round(2)}, Max vel: #{max_velocity.round(2)}"
        movement_detected = false
      end
    end
    
    # Update maximums
    if current_acceleration > max_acceleration
      max_acceleration = current_acceleration
    end
    if current_velocity > max_velocity
      max_velocity = current_velocity
    end
    
    # Print status every 5 cycles (1 second)
    if cycle_count % 5 == 0
      puts "Cycle #{cycle_count}: Accel=#{current_acceleration.round(2)} Vel=#{current_velocity.round(2)} Motion=#{movement_detected}"
    end
    
  rescue => e
    puts "Error in measurement: #{e.message}"
  end
  
  # Wait 200ms
  sleep_ms 200
end