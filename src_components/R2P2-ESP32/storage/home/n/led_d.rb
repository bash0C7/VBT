# LED & Distance
require 'ws2812'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'

def chika(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))

  i2c = I2C.new(
    unit: :ESP32_I2C0,
    frequency: 100_000,
    sda_pin: 26,  # Grove SDA
    scl_pin: 32   # Grove SCL
  )
  sensor = VL53L0X.new(i2c)
  colors = Array.new(cnt) { [0, 0, 0] }
  distance = 0
  frame = 0

  loop do
    frame += 1
    
    # センサー読み取り頻度を下げる
    if frame % 5 == 0
      new_distance = sensor.read_distance
      puts new_distance
      distance = new_distance if new_distance > 0  # エラー時は前回値保持
    end
    
    # 距離に基づく色計算
    if distance <= 0
      # エラー時は微弱な白色
      r, g, b = 10, 10, 10
    else
      # 2m(2000mm)を最大として正規化
      normalized = [distance / 2000.0, 1.0].min
      
      if normalized <= 0.5
        # 近距離 (0-1000mm): Green → Blue
        ratio = normalized * 2.0
        r = 0
        g = (255 * (1.0 - ratio)).to_i
        b = (255 * ratio).to_i
      else
        # 遠距離 (1000-2000mm): Blue → Red  
        ratio = (normalized - 0.5) * 2.0
        r = (255 * ratio).to_i
        g = 0
        b = (255 * (1.0 - ratio)).to_i
      end
    end
    
    # 全LEDに同じ色を設定
    cnt.times do |i|
      colors[i] = [r, g, b]
    end
    
    led.show_rgb(*colors)
    
    sleep_ms(50)  # 間隔を長くしてCPU負荷軽減
  end
end

arg_cnt = ARGV[0] || 25
puts arg_cnt
arg_pin = ARGV[1] || 27
puts arg_pin
chika(arg_cnt.to_i, arg_pin.to_i)
