require 'uart'

UART_TX = 26
UART_RX = 32

uart = UART.new(
  unit: :ESP32_UART1, 
  baudrate: 31250,
  txd_pin: UART_TX, 
  rxd_pin: UART_RX
)

MIDI_CHANNEL = 0

def busy_wait_ms(duration_ms)
  counter = duration_ms * 2000
  while counter > 0
    counter -= 1
  end
end

# Arduino C++ライブラリ準拠の楽器設定
def set_instrument(uart, bank, channel, program)
  # Bank Select Control Change
  cc_data = (0xB0 + channel).chr + 0x00.chr + bank.chr
  uart.write(cc_data)
  busy_wait_ms(10)
  
  # Program Change
  pc_data = (0xC0 + channel).chr + program.chr
  uart.write(pc_data)
  busy_wait_ms(50)
  puts "Instrument: Bank=#{bank}, Program=#{program}"
end

def note_on(uart, channel, note, velocity)
  data = (0x90 + channel).chr + note.chr + velocity.chr
  uart.write(data)
  puts "Note On: #{note}"
end

def note_off(uart, channel, note)
  data = (0x80 + channel).chr + note.chr + 0.chr  # velocity=0固定
  uart.write(data)
  puts "Note Off: #{note}"
end

# Master Volume設定（C++ライブラリから）
def set_master_volume(uart, level)
  # SysEx: F0 7F 7F 04 01 00 level F7
  sysex = "\xF0\x7F\x7F\x04\x01\x00" + level.chr + "\xF7"
  uart.write(sysex)
  busy_wait_ms(100)
  puts "Master Volume: #{level}"
end

puts "Unit MIDI開始（C++ライブラリ準拠）"
busy_wait_ms(2000)

# Master Volume最大
set_master_volume(uart, 127)

# 楽器設定（Bank=0, Program=1）
set_instrument(uart, 0, MIDI_CHANNEL, 1)  # Acoustic Grand Piano

# テスト音
puts "テスト音演奏"
note_on(uart, MIDI_CHANNEL, 60, 127)
busy_wait_ms(2000)
note_off(uart, MIDI_CHANNEL, 60)

puts "完了"
