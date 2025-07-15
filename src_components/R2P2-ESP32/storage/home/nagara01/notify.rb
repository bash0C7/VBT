
require 'ws2812'
require 'uart'

def chika(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))
  uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  
  colors = [[0, 0, 0]] * cnt
  
  loop do
    input = uart.read
    if input && input.length > 0
      puts input
      
      if input == "r"
        uart.puts "R"
        # 簡単な赤点灯
        (0...cnt).each { |i| colors[i] = [100, 20, 0] }
        led.show_rgb(*colors)
        sleep_ms(2000)
        
      elsif input == "g"
        uart.puts "G" 
        # 簡単な緑点灯
        (0...cnt).each { |i| colors[i] = [20, 100, 0] }
        led.show_rgb(*colors)
        sleep_ms(2000)
        
      elsif input == "b"
        uart.puts "B"
        # 簡単な青点灯
        (0...cnt).each { |i| colors[i] = [0, 20, 100] }
        led.show_rgb(*colors)
        sleep_ms(2000)
      end
      
      # 消灯
      (0...cnt).each { |i| colors[i] = [0, 0, 0] }
      led.show_rgb(*colors)
    end
    
    sleep_ms(100)
  end
end

arg_cnt = ARGV[0] || 25
puts arg_cnt
arg_pin = ARGV[1] || 27
puts arg_pin
chika(arg_cnt.to_i, arg_pin.to_i)
