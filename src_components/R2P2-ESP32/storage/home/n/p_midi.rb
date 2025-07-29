# atom_midi_through_led.rb
require 'uart'
require 'ws2812'

puts "MIDI Through + LED"

# UART設定
pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
unit_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)

# LED設定
led = WS2812.new(RMTDriver.new(27))
colors = Array.new(25) { [0, 0, 0] }

# MIDI変数
note_leds = Array.new(25, 0)
midi_bytes = []

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    data.each_byte do |byte|
      midi_bytes.push(byte)
      
      # 3バイト溜まったらNote Onチェック
      if midi_bytes.length >= 3
        status = midi_bytes[-3]
        note = midi_bytes[-2]
        velocity = midi_bytes[-1]
        
        if status >= 0x90 && status <= 0x9F && velocity > 0
          # 光る場所：ノート番号を25で割った余り
          led_pos = note % 25
          
          # 輝度：ベロシティ * 2（最大255）
          brightness = velocity * 2
          brightness = brightness > 255 ? 255 : brightness
          
          # 色：オクターブ（ノート/12）で決定
          octave = note / 12
          case octave % 6
          when 0  # 赤
            colors[led_pos] = [brightness, 0, 0]
          when 1  # 黄
            colors[led_pos] = [brightness, brightness / 2, 0]
          when 2  # 緑
            colors[led_pos] = [0, brightness, 0]
          when 3  # シアン
            colors[led_pos] = [0, brightness / 2, brightness]
          when 4  # 青
            colors[led_pos] = [0, 0, brightness]
          when 5  # マゼンタ
            colors[led_pos] = [brightness / 2, 0, brightness]
          end
          
          note_leds[led_pos] = brightness
          puts "Note: #{note}, LED: #{led_pos}, Oct: #{octave}, Vel: #{velocity}"
        end
        
        # バッファ制限
        if midi_bytes.length > 10
          midi_bytes.shift
        end
      end
    end
  end
  
  # LED更新と減衰
  25.times do |i|
    if note_leds[i] > 0
      # 減衰処理
      note_leds[i] -= 5
      note_leds[i] = 0 if note_leds[i] < 0
    else
      colors[i] = [0, 0, 0]
    end
  end
  
  led.show_rgb(*colors)
  sleep_ms(10)
end
