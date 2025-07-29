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
note_leds = Array.new(25, 0)  # 各LEDの輝度

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    # シンプルなNote On検出（0x90以降の3バイト目がベロシティ）
    data.each_byte do |byte|
      if byte >= 0x90 && byte <= 0x9F
        puts "Note On detected"
        # とりあえず中央のLEDを光らせる
        note_leds[12] = 200
      end
    end
  end
  
  # LED更新と減衰
  25.times do |i|
    if note_leds[i] > 0
      brightness = note_leds[i]
      colors[i] = [brightness, brightness / 2, 0]  # 黄色系
      note_leds[i] -= 5
      note_leds[i] = 0 if note_leds[i] < 0
    else
      colors[i] = [0, 0, 0]
    end
  end
  
  led.show_rgb(*colors)
  sleep_ms(10)
end
