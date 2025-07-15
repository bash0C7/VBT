#load '/home/nagara01/nagara_led.rb'

require 'ws2812'
require 'i2c'
require 'mpu6886'

def chika(cnt, pin = 32)
  led = WS2812.new(RMTDriver.new(pin))
  mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
  mpu.accel_range = MPU6886::ACCEL_RANGE_4G
  
  # 事前にcolors配列を作成（初期値は消灯状態）
  colors = Array.new(cnt) { [0, 0, 0] }
  
  off = 0
  frame = 0
  spd = 0
  str = 50
  
  loop do
    frame += 1
    if frame % 3 == 0
      a = mpu.acceleration
      spd = a[:x] * 10
      str = (a[:y].abs * 100).to_i
    end
    
    cnt.times do |i|
      pos = (off + i * 0.3) % 6.28318
      val = pos < 3.14159 ? pos - 1.5708 : -(pos - 4.7124)
      val = val > 1 ? 1 : (val < -1 ? -1 : val)
      
      r = [[(val + 1) * 0.5 * str, 0].max, 255].min.to_i
      g = [[(val * -1 + 1) * 0.5 * str, 0].max, 255].min.to_i
      b = [[150 + val * 50, 0].max, 255].min.to_i
      
      colors[i] = [r, g, b]
    end
    
    led.show_rgb(*colors)
    off = (off + 0.2 + spd * 0.01) % 6.28318
    
    sleep(0.05)
  end
end

chika(25, 27)
