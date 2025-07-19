# VL53L0X Distance Sensor - Pure Ruby Implementation

class VL53L0X
  # VL53L0X I2C address
  I2C_ADDRESS = 0x29
  
  # Expected WHO_AM_I value
  CHIP_ID = 0xEE

  # Initialize VL53L0X sensor
  # @param i2c_instance [I2C] Existing I2C instance
  # @param address [Integer] I2C address (default: 0x29)
  def initialize(i2c_instance, address = I2C_ADDRESS)
    @i2c = i2c_instance
    @address = address
    @stop_variable = 0
    @initialized = false
    
    init_sensor
  end

  # Read distance measurement
  # @return [Integer] Distance in millimeters, -1 on error
  def read_distance
    return -1 unless @initialized
    
    begin
      # シングルショット測定開始
      write_reg(0x80, 0x01)
      write_reg(0xFF, 0x01)
      write_reg(0x00, 0x00)
      write_reg(0x91, @stop_variable)
      write_reg(0x00, 0x01)
      write_reg(0xFF, 0x00)
      write_reg(0x80, 0x00)
      
      write_reg(0x0A, 0x04)  # SYSTEM_INTERRUPT_CONFIG_GPIO
      clear_mask = read_reg(0x84, 1)[0]
      write_reg(0x84, clear_mask & ~0x10)
      write_reg(0x0B, 0x01)  # SYSTEM_INTERRUPT_CLEAR
      
      # 測定開始
      write_reg(0x00, 0x01)
      
      # 測定完了待ち
      timeout = 0
      loop do
        status = read_reg(0x13, 1)[0] & 0x07  # RESULT_INTERRUPT_STATUS
        break if status != 0
        
        timeout += 1
        if timeout > 1000
          puts "VL53L0X: Measurement timeout"
          return -1
        end
        sleep_ms(1)
      end
      
      # 距離読み取り
      data = read_reg(0x1E, 2)  # RESULT_RANGE_STATUS + 10
      distance_mm = (data[0] << 8) | data[1]
      
      # 割り込みクリア
      write_reg(0x0B, 0x01)
      
      distance_mm
    rescue => e
      puts "VL53L0X: Distance read failed - #{e.message}"
      -1
    end
  end

  # Check if sensor is ready
  # @return [Boolean] true if sensor is initialized
  def ready?
    @initialized
  end

  private

  # Initialize sensor
  def init_sensor
    begin
      # Check chip ID
      who_am_i = read_reg(0xC0, 1)[0]  # WHO_AM_I
      unless who_am_i == CHIP_ID
        puts "VL53L0X: Invalid chip ID: 0x#{who_am_i.to_s(16)} (expected: 0x#{CHIP_ID.to_s(16)})"
        return
      end
      
      # Basic initialization sequence
      write_reg(0x88, 0x00)
      write_reg(0x80, 0x01)
      write_reg(0xFF, 0x01)
      write_reg(0x00, 0x00)
      @stop_variable = read_reg(0x91, 1)[0]
      write_reg(0x00, 0x01)
      write_reg(0xFF, 0x00)
      write_reg(0x80, 0x00)
      
      # Configure measurement settings
      write_reg(0x44, 0x14)  # FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT
      write_reg(0x01, 0xE8)  # SYSTEM_SEQUENCE_CONFIG
      
      sleep_ms(10)
      
      @initialized = true
      puts "VL53L0X: Sensor initialized successfully"
      
    rescue => e
      puts "VL53L0X: Initialization failed - #{e.message}"
      @initialized = false
    end
  end

  # Write to register
  # @param reg [Integer] Register address
  # @param data [Integer] Data to write
  def write_reg(reg, data)
    result = @i2c.write(@address, reg, data, timeout: 2000)
    unless result > 0
      raise IOError, "VL53L0X write failed (reg: 0x#{reg.to_s(16)}, data: 0x#{data.to_s(16)})"
    end
  end

  # Read from register
  # @param reg [Integer] Register address
  # @param length [Integer] Number of bytes to read
  # @return [Array<Integer>] Array of read data
  def read_reg(reg, length)
    data = @i2c.read(@address, length, reg, timeout: 1000)
    
    if data.nil? || data.empty?
      raise IOError, "VL53L0X read failed (reg: 0x#{reg.to_s(16)}, length: #{length})"
    end
    
    # Convert from String to byte array
    data.bytes
  end

  # Sleep for specified milliseconds
  # @param ms [Integer] Milliseconds to sleep
  def sleep_ms(ms)
    sleep(ms / 1000.0)
  end
end

# Usage example (ATOM Matrix with Grove connection)
if __FILE__ == $0
  require 'i2c'
  
  puts "=== VL53L0X Distance Sensor Test (ATOM Matrix) ==="
  
  # Initialize I2C (ATOM Matrix Grove pins)
  i2c = I2C.new(
    unit: :ESP32_I2C0,
    frequency: 100_000,
    sda_pin: 26,  # ATOM Matrix Grove SDA
    scl_pin: 32   # ATOM Matrix Grove SCL
  )
  
  # Initialize VL53L0X sensor
  sensor = VL53L0X.new(i2c)
  
  if sensor.ready?
    puts "Starting distance measurements..."
    
    # Simple test readings
    10.times do |i|
      distance = sensor.read_distance
      
      if distance > 0
        puts "Reading #{i + 1}: #{distance} mm"
      else
        puts "Reading #{i + 1}: ERROR"
      end
      
      sleep(1)
    end
    
  else
    puts "Sensor initialization failed!"
  end
  
  puts "Test complete"
end

