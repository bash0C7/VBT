# PicoRuby Absolute Minimal Test
# Test basic functionality first

# Try with just one require at a time
require 'uart'

# Basic UART only - no RMT yet
uart = UART.new(unit: :ESP32_UART0, txd_pin: 0, rxd_pin: 1, baudrate: 115200)

uart.puts "Start"

# Minimal loop
count = 0
while count < 10
  uart.puts count.to_s
  count = count + 1
  sleep_ms 1000
end

uart.puts "End"
