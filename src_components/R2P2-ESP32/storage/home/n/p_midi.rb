# https://claude.ai/chat/f6aa9f8a-3976-49ef-9998-ba6b3c6f038a
# atom_midi_through.rb
require 'uart'

puts "ATOM Matrix MIDI Through 開始"

# PC接続用（USB Serial）
pc_uart = UART.new(
  unit: :ESP32_UART0,  # USB Serial
  baudrate: 115200
)

# Unit MIDI接続用（既存の実績設定）
UART_TX = 26
UART_RX = 32
unit_uart = UART.new(
  unit: :ESP32_UART1,
  baudrate: 31250,
  txd_pin: UART_TX, 
  rxd_pin: UART_RX
)

puts "PCからのMIDIデータをUnit MIDIに転送中..."
puts "Ctrl+Cで終了"

# 無限ループ：PCからのデータをUnit MIDIにそのまま転送
loop do
  # PCからデータ受信チェック
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    # 転送確認（デバッグ用）
    puts "転送: #{data.length}バイト"
  end
  
  # CPU負荷軽減
  sleep_ms(1)
end
