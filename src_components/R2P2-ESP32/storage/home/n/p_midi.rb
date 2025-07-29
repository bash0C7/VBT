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
midi_buf = [0, 0, 0]
buf_idx = 0
led_brightness = 0

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    data.each_byte do |byte|
      midi_buf[buf_idx] = byte
      buf_idx = (buf_idx + 1) % 3
      
      # Note On検出 (0x90-0x9F, velocity > 0)
      if midi_buf[0] >= 0x90 && midi_buf[0] <= 0x9F && midi_buf[2] > 0
        led_brightness = midi_buf[2] * 2
        led_brightness = led_brightness > 255 ? 255 : led_brightness
        puts "Note: #{midi_buf[1]}, Vel: #{midi_buf[2]}"
      end
    end
  end
  
  # LED更新
  25.times do |i|
    if led_brightness > 0
      colors[i] = [led_brightness, 0, led_brightness / 2]
    else
      colors[i] = [0, 0, 0]
    end
  end
  
  if led_brightness > 0
    led_brightness -= 5
    led_brightness = 0 if led_brightness < 0
  end
  
  led.show_rgb(*colors)
  sleep_ms(10)
end
