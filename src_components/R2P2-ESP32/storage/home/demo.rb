# Ruby Gemstone Demo - Ultra Minimal

require 'i2c'
require 'mpu6886'
require 'rmt'

# I2C setup
i = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)

# MPU6886 setup
m = MPU6886.new(i)
m.accel_range = MPU6886::ACCEL_RANGE_4G

# WS2812 minimal class
class WS2812
  def initialize(pin)
    @rmt = RMT.new(pin, t0h_ns: 350, t0l_ns: 800, t1h_ns: 700, t1l_ns: 600, reset_ns: 60000)
  end
  def show(colors)
    b = []
    colors.each do |x|
      r = ((x >> 16) & 0xFF) >> 3
      g = ((x >> 8) & 0xFF) >> 3
      blue = (x & 0xFF) >> 3
      b << g
      b << r  
      b << blue
    end
    @rmt.write(b)
  end
end

w = WS2812.new(27)

# LCD init
[0x38,0x39,0x14,0x70,0x54,0x6c].each{|x|i.write(0x3e,0,x);sleep_ms 1}
[0x38,0x0c,0x01].each{|x|i.write(0x3e,0,x);sleep_ms 1}

# Ready
[82,101,97,100,121].each{|x|i.write(0x3e,0x40,x)}
sleep_ms 3000

# LEDs - manual array creation
l = []
25.times { l << 0 }

# Ruby positions
r = [1,2,3,5,6,7,8,9,11,12,13,17]

# Calibrate
[67,97,108].each{|x|i.write(0x3e,0x40,x)}
sx = sy = 0
5.times do
  a = m.acceleration
  sx += (a[:x]*100).to_i
  sy += (a[:y]*100).to_i
  sleep_ms 200
end
nx = sx/5
ny = sy/5

# Ready
i.write(0x3e,0,0x01)
sleep_ms 2
[79,75].each{|x|i.write(0x3e,0x40,x)}

# Main loop
c = 0
loop do
  a = m.acceleration
  x = (a[:x]*100).to_i - nx
  y = (a[:y]*100).to_i - ny
  
  # Color by motion
  t = x*x + y*y
  col = 0xFF0000
  col = 0xFF4080 if t > 400
  col = 0x8040FF if t > 1600
  
  # Movement
  sx = x/15
  sy = y/-15
  sx = sx > 4 ? 4 : sx < -4 ? -4 : sx
  sy = sy > 4 ? 4 : sy < -4 ? -4 : sy
  
  # Clear
  25.times{|j|l[j]=0}
  
  # Draw
  r.each do |p|
    cx = p%5 + sx
    cy = p/5 + sy
    l[cy*5+cx] = col if cx>=0 && cx<5 && cy>=0 && cy<5
  end
  
  w.show(l)
  
  # LCD - 3-axis display
  c += 1
  if c >= 20
    i.write(0x3e,0,0x01)
    sleep_ms 1
    
    # Line 1: X±nY±n (compact format)
    i.write(0x3e,0x40,88)  # 'X'
    if x >= 0
      i.write(0x3e,0x40,43)  # '+'
      val = x < 10 ? x : 9
    else
      i.write(0x3e,0x40,45)  # '-'
      val = (-x) < 10 ? (-x) : 9
    end
    i.write(0x3e,0x40,48+val)  # X digit
    
    i.write(0x3e,0x40,89)  # 'Y'
    if y >= 0
      i.write(0x3e,0x40,43)  # '+'
      val = y < 10 ? y : 9
    else
      i.write(0x3e,0x40,45)  # '-'
      val = (-y) < 10 ? (-y) : 9
    end
    i.write(0x3e,0x40,48+val)  # Y digit
    
    # Line 2: T:n (compact tilt display)
    i.write(0x3e,0,0x80|0x40)
    i.write(0x3e,0x40,84)  # 'T'
    i.write(0x3e,0x40,58)  # ':'
    
    # Normalize tilt to 0-9 range  
    tilt_val = t / 200  # Scale down from squared values
    tilt_val = tilt_val > 9 ? 9 : tilt_val
    i.write(0x3e,0x40,48+tilt_val)  # Tilt digit
    
    c = 0
  end
  
  sleep_ms 50
end