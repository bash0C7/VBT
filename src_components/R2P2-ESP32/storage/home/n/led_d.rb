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
      distance = new_distance if new_distance > 0
    end
    
    # 距離に基づく色計算とLED点灯数制御
    if distance <= 0
      # エラー時は微弱な白色
      r, g, b = 2, 2, 2  # 20%輝度
      led_count = cnt
    else
      # 距離による色分け
      if distance <= 200
        # 20cm以下: 緑
        r, g, b = 0, 51, 0  # 255 * 0.2
      elsif distance <= 500
        # 50cm以下: 黄
        r, g, b = 51, 51, 0
      elsif distance <= 800
        # 80cm以下: 青
        r, g, b = 0, 0, 51
      elsif distance <= 1000
        # 1m以下: 赤
        r, g, b = 51, 0, 0
      else
        # 1m超: 赤で点灯数減少
        r, g, b = 51, 0, 0
      end
      
      # 1m超過時の点灯数制御
      if distance > 1000
        excess_cm = (distance - 1000) / 10  # 1mを超えた10cm単位
        led_count = [cnt - excess_cm, 1].max  # 最低1個は点灯
      else
        led_count = cnt
      end
    end
    
    # LEDの設定
    cnt.times do |i|
      if i < led_count
        colors[i] = [r, g, b]
      else
        colors[i] = [0, 0, 0]  # 消灯
      end
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
