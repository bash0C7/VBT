require 'fileutils'

# Common environment setup for all tasks
def setup_environment
  env_vars = {
    'PATH' => "/opt/homebrew/opt/openssl/bin:#{ENV['PATH']}",
    'LDFLAGS' => "-L/opt/homebrew/opt/openssl/lib #{ENV['LDFLAGS']}",
    'CPPFLAGS' => "-I/opt/homebrew/opt/openssl/include #{ENV['CPPFLAGS']}",
    'CFLAGS' => "-I/opt/homebrew/opt/openssl/include #{ENV['CFLAGS']}",
    'PKG_CONFIG_PATH' => "/opt/homebrew/opt/openssl/lib/pkgconfig:#{ENV['PKG_CONFIG_PATH']}",
    'GRPC_PYTHON_BUILD_SYSTEM_OPENSSL' => '1',
    'GRPC_PYTHON_BUILD_SYSTEM_ZLIB' => '1',
    'ESPBAUD' => '115200'
  }
  
  env_vars.each { |key, value| ENV[key] = value }
  
  # Source ESP-IDF environment
  system('. $HOME/esp/esp-idf/export.sh')
end

# Helper method to execute commands in R2P2-ESP32 directory
def execute_in_r2p2_directory(commands)
  Dir.chdir('components/R2P2-ESP32') do
    commands.each { |cmd| system(cmd) }
  end
end

# Helper method to copy source components contents
def copy_source_components
  source_dir = 'src_components'
  target_dir = 'components'
  
  if Dir.exist?(source_dir)
    FileUtils.cp_r("#{source_dir}/.", target_dir)
    puts "Copied src_components contents to #{target_dir}"
  else
    puts "Warning: #{source_dir} directory not found"
  end
end

desc "Initial setup: create components, clone R2P2-ESP32, copy picoruby-esp32, and build"
task :setup do
  puts "Starting VBT project setup..."
  setup_environment
  
  # Create components directory
  FileUtils.mkdir_p('components')
  puts "Created components directory"
  
  # Clone R2P2-ESP32 repository
  Dir.chdir('components') do
    system('git clone --recursive https://github.com/picoruby/R2P2-ESP32.git')
  end
  puts "Cloned R2P2-ESP32 repository"
  
  # Copy source components contents
  copy_source_components
  
  # Execute build commands in R2P2-ESP32 directory
  execute_in_r2p2_directory([
    'idf.py fullclean',
    'rake setup_esp32',
    'rake build'
  ])
  
  puts "Setup completed successfully"
end

desc "Update: clean git changes, pull latest, copy picoruby-esp32, and rebuild"
task :update do
  puts "Updating VBT project..."
  setup_environment
  
  Dir.chdir('components/R2P2-ESP32') do
    # Clean git changes and untracked files
    system('git reset --hard HEAD')
    system('git clean -fd')
    puts "Cleaned git changes and untracked files"
    
    # Pull latest changes with submodules
    system('git pull --recurse-submodules')
    puts "Pulled latest changes"
  end
  
  # Copy source components contents
  copy_source_components
  
  # Execute build commands
  execute_in_r2p2_directory([
    'idf.py fullclean',
    'rake setup_esp32',
    'rake build'
  ])
  
  puts "Update completed successfully"
end

desc "Clean build: fullclean, setup_esp32, and rake"
task :cleanbuild do
  puts "Performing clean build..."
  setup_environment
  
  execute_in_r2p2_directory([
    'idf.py fullclean',
    'rake setup_esp32',
    'rake'
  ])
  
  puts "Clean build completed successfully"
end

desc "Build all: setup_esp32 and rake build"
task :buildall do
  puts "Building all components..."
  setup_environment
  
  execute_in_r2p2_directory([
    'rake setup_esp32',
    'rake build'
  ])
  
  puts "Build all completed successfully"
end

desc "Build: execute rake build only"
task :build do
  puts "Building project..."
  setup_environment
  
  execute_in_r2p2_directory(['rake build'])
  
  puts "Build completed successfully"
end

# Default task
task :default => :build
