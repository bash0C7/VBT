#距離レジスタの診断

require 'i2c'

# I2C初期化（Grove接続）
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 26, scl_pin: 32)
address = 0x29

puts "=== VL53L0X 距離レジスタ診断 ==="

# WHO_AM_I確認
who_am_i_data = i2c.read(address, 1, 0xC0, timeout: 1000)
who_am_i = who_am_i_data.bytes[0]
puts "WHO_AM_I: 0x#{who_am_i.to_s(16)}"

# 複数の距離関連レジスタを確認
puts "距離レジスタ確認:"
[0x14, 0x1E, 0x96, 0x97].each do |reg|
  data = i2c.read(address, 2, reg, timeout: 1000)
  bytes = data.bytes
  value = (bytes[0] << 8) | bytes[1]
  puts "0x#{reg.to_s(16)}: #{value} (0x#{value.to_s(16)})"
end
