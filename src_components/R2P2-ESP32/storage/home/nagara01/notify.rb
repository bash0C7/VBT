
require 'ws2812'
require 'uart'

def chika(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))
  uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  
  colors = Array.new(cnt) { [0, 0, 0] }
  
  loop do
    input = uart.read
    if input && input.length > 0
      input_char = input.strip.downcase
      puts "受信: #{input_char}"
      
      base_color = nil
      case input_char
      when "r"
        uart.puts "RED点灯開始"
        base_color = :red
      when "g"
        uart.puts "GREEN点灯開始"
        base_color = :green
      when "b"
        uart.puts "BLUE点灯開始"
        base_color = :blue
      end
      
      if base_color
        # 5秒間のアニメーション実行
        100.times do |step|
          cnt.times do |i|
            # 三角波で近似（0-255の範囲）
            wave_pos = (step * 4 + i * 16) % 128
            brightness = wave_pos < 64 ? wave_pos * 4 : (128 - wave_pos) * 4
            
            case base_color
            when :red
              colors[i] = [brightness, brightness / 4, 0]
            when :green
              colors[i] = [brightness / 4, brightness, 0]
            when :blue
              colors[i] = [0, brightness / 4, brightness]
            end
          end
          
          led.show_rgb(*colors)
          sleep_ms(50)
        end
        
        # 消灯
        cnt.times { |i| colors[i] = [0, 0, 0] }
        led.show_rgb(*colors)
      end
    end
    
    sleep_ms(100)
  end
end

arg_cnt = ARGV[0] || 25
puts arg_cnt
arg_pin = ARGV[1] || 27
puts arg_pin
chika(arg_cnt.to_i, arg_pin.to_i)
