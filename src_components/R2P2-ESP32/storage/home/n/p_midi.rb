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
midi_state = 0  # 0=待機, 1=ノート受信, 2=ベロシティ受信
midi_status = 0
midi_note = 0
note_leds = Array.new(25, 0)  # 各LEDの輝度

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    data.each_byte do |byte|
      if byte >= 0x80  # ステータスバイト
        if byte >= 0x90 && byte <= 0x9F  # Note On
          midi_status = byte
          midi_state = 1
        else
          midi_state = 0
        end
      else  # データバイト
        if midi_state == 1  # ノート受信
          midi_note = byte
          midi_state = 2
        elsif midi_state == 2  # ベロシティ受信
          velocity = byte
          if velocity > 0  # Note On
            led_pos = midi_note % 25
            note_leds[led_pos] = velocity * 2
            note_leds[led_pos] = note_leds[led_pos] > 255 ? 255 : note_leds[led_pos]
            puts "Note: #{midi_note}, LED: #{led_pos}, Vel: #{velocity}"
          end
          midi_state = 0
        end
      end
    end
  end
  
  # LED更新と減衰
  25.times do |i|
    if note_leds[i] > 0
      brightness = note_leds[i]
      colors[i] = [brightness, brightness / 2, 0]  # 黄色系
      note_leds[i] -= 3
      note_leds[i] = 0 if note_leds[i] < 0
    else
      colors[i] = [0, 0, 0]
    end
  end
  
  led.show_rgb(*colors)
  sleep_ms(10)
end
