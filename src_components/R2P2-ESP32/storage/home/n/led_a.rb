require 'ws2812'
require 'uart'
# ATOM Matrix + Unit ASR 簡素版
# hello / ok のみ対応

# 設定
LED_COUNT = 25
LED_PIN = 27
UART_TX = 32
UART_RX = 26

# 初期化
uart = UART.new(unit: :ESP32_UART0, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX)
led = WS2812.new(RMTDriver.new(LED_PIN))
colors = Array.new(LED_COUNT) { [0, 0, 10] }  # 初期：暗い青

# 色定義（20%輝度）
color_hello = [51, 25, 0]     # オレンジ - "hello"
color_ok = [0, 25, 51]        # シアン - "ok" 
color_standby = [0, 0, 10]    # 暗い青

# 現在の色
current_color = color_standby

# Unit ASR初期化
uart.write("\xAA\x55\xB1\x05")
sleep_ms(500)
puts "Unit ASR 準備完了"

# 初期表示
LED_COUNT.times { |i| colors[i] = current_color }
led.show_rgb(*colors)

# メインループ
loop do
  # UART受信確認
  if uart.bytes_available >= 5
    # 5バイトパケット読み取り
    packet = uart.read(5)
    
    if packet && packet.length == 5 && 
       packet[0].ord == 0xAA && packet[1].ord == 0x55 &&
       packet[3].ord == 0x55 && packet[4].ord == 0xAA
      
      cmd_id = packet[2].ord
      
      case cmd_id
      when 0x32  # hello
        puts "音声認識: hello"
        current_color = color_hello
      when 0x30  # ok
        puts "音声認識: ok"  
        current_color = color_ok
      else
        puts "音声認識: 不明(#{cmd_id.to_s(16)})"
        current_color = color_standby
      end
      
      # LED更新
      LED_COUNT.times { |i| colors[i] = current_color }
      led.show_rgb(*colors)
      
      # 3秒後に待機色に戻す
      sleep_ms(3000)
      current_color = color_standby
      LED_COUNT.times { |i| colors[i] = current_color }
      led.show_rgb(*colors)
    end
  end
  
  sleep_ms(50)
end
