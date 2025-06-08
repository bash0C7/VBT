require 'fileutils'

# Common environment setup for all tasks
def setup_environment
  # Set OpenSSL paths for Homebrew
  homebrew_openssl = "/opt/homebrew/opt/openssl"
  
  env_vars = {
    'PATH' => "#{homebrew_openssl}/bin:#{ENV['PATH']}",
    'LDFLAGS' => "-L#{homebrew_openssl}/lib #{ENV['LDFLAGS']}",
    'CPPFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CPPFLAGS']}",
    'CFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CFLAGS']}",
    'PKG_CONFIG_PATH' => "#{homebrew_openssl}/lib/pkgconfig:#{ENV['PKG_CONFIG_PATH']}",
    'GRPC_PYTHON_BUILD_SYSTEM_OPENSSL' => '1',
    'GRPC_PYTHON_BUILD_SYSTEM_ZLIB' => '1',
    'ESPBAUD' => '115200'
  }
  
  # Set basic ESP-IDF path
  esp_idf_path = "#{ENV['HOME']}/esp/esp-idf"
  if Dir.exist?(esp_idf_path)
    env_vars['IDF_PATH'] = esp_idf_path
  else
    puts "Critical Warning: ESP-IDF not found at #{esp_idf_path}"
    puts "Please install ESP-IDF or update the path in setup_environment method"
  end
  
  # Apply environment variables
  env_vars.each { |key, value| ENV[key] = value }
  
  puts "Environment setup complete"
  puts "IDF_PATH: #{ENV['IDF_PATH']}"
  
  # Note: Actual ESP-IDF tools will be available after sourcing export.sh in execute_with_esp_env
end

# Helper method to execute commands in R2P2-ESP32 directory with proper error handling
def execute_in_r2p2_directory(commands)
  Dir.chdir('components/R2P2-ESP32') do
    commands.each do |cmd|
      puts "Executing: #{cmd}"
      unless system(cmd)
        abort "Error: Command failed with exit code #{$?.exitstatus}: #{cmd}"
      end
    end
  end
end

# Helper method to execute shell command that sources ESP-IDF environment
def execute_with_esp_env(command)
  esp_idf_path = ENV['IDF_PATH'] || "#{ENV['HOME']}/esp/esp-idf"
  
  # Create a comprehensive environment setup script
  setup_script = <<~SCRIPT
    export PATH="/opt/homebrew/opt/openssl/bin:$PATH"
    export LDFLAGS="-L/opt/homebrew/opt/openssl/lib $LDFLAGS"
    export CPPFLAGS="-I/opt/homebrew/opt/openssl/include $CPPFLAGS"
    export CFLAGS="-I/opt/homebrew/opt/openssl/include $CFLAGS"
    export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
    export ESPBAUD=115200
    
    # Source ESP-IDF environment
    . #{esp_idf_path}/export.sh
    
    # Execute the command
    #{command}
  SCRIPT
  
  puts "Executing with ESP-IDF environment: #{command}"
  success = system("bash", "-c", setup_script)
  
  unless success
    abort "Error: ESP-IDF command failed with exit code #{$?.exitstatus}: #{command}"
  end
  
  success
end

# Helper method to check if commands are available in ESP-IDF environment
def check_commands_in_esp_env
  esp_idf_path = ENV['IDF_PATH'] || "#{ENV['HOME']}/esp/esp-idf"
  
  setup_script = <<~SCRIPT
    export PATH="/opt/homebrew/opt/openssl/bin:$PATH"
    export LDFLAGS="-L/opt/homebrew/opt/openssl/lib $LDFLAGS"
    export CPPFLAGS="-I/opt/homebrew/opt/openssl/include $CPPFLAGS"
    export CFLAGS="-I/opt/homebrew/opt/openssl/include $CFLAGS"
    export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
    export ESPBAUD=115200
    
    # Source ESP-IDF environment
    . #{esp_idf_path}/export.sh
    
    # Check commands
    echo "=== Commands after ESP-IDF setup ==="
    echo "python: $(which python || echo 'Not found')"
    echo "python3: $(which python3 || echo 'Not found')"
    echo "idf.py: $(which idf.py || echo 'Not found')"
    echo "xtensa-esp32-elf-gcc: $(which xtensa-esp32-elf-gcc || echo 'Not found')"
    
    # Return success if all essential commands are found
    if command -v python >/dev/null 2>&1 && command -v idf.py >/dev/null 2>&1 && command -v xtensa-esp32-elf-gcc >/dev/null 2>&1; then
      echo "All essential commands available"
      exit 0
    else
      echo "Some commands are missing"
      exit 1
    fi
  SCRIPT
  
  system("bash", "-c", setup_script)
end

# Helper method to copy source components contents
def copy_source_components
  source_dir = 'src_components'
  target_dir = 'components'
  
  if Dir.exist?(source_dir)
    begin
      FileUtils.cp_r("#{source_dir}/.", target_dir)
      puts "Copied src_components contents to #{target_dir}"
    rescue => e
      abort "Error: Failed to copy source components: #{e.message}"
    end
  else
    puts "Warning: #{source_dir} directory not found"
  end
end

desc "Initial setup: create components, clone R2P2-ESP32, copy picoruby-esp32, and build"
task :init do
  puts "Starting VBT project init..."
  setup_environment
  
  begin
    # Create components directory
    FileUtils.mkdir_p('components')
    puts "Created components directory"
    
    # Clone R2P2-ESP32 repository
    Dir.chdir('components') do
      if Dir.exist?('R2P2-ESP32')
        puts "R2P2-ESP32 already exists, skipping clone"
      else
        unless system('git clone --recursive https://github.com/picoruby/R2P2-ESP32.git')
          abort "Error: Failed to clone R2P2-ESP32 repository"
        end
        puts "Cloned R2P2-ESP32 repository"
      end
    end
    
    # Copy source components contents
    copy_source_components
    
    # Execute build commands in R2P2-ESP32 directory with ESP-IDF environment
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during setup: #{e.message}"
  end
  
  puts "Setup completed successfully"
end

desc "Update: clean git changes, pull latest, copy picoruby-esp32, and rebuild"
task :update do
  puts "Updating VBT project..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      # Clean git changes and untracked files
      unless system('git reset --hard HEAD')
        abort "Error: Failed to reset git repository"
      end
      unless system('git clean -fd')
        abort "Error: Failed to clean git repository"
      end
      puts "Cleaned git changes and untracked files"
      
      # Pull latest changes with submodules
      unless system('git pull --recurse-submodules')
        abort "Error: Failed to pull latest changes"
      end
      puts "Pulled latest changes"
    end
    
    # Copy source components contents
    copy_source_components
    
    # Execute build commands with ESP-IDF environment
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during update: #{e.message}"
  end
  
  puts "Update completed successfully"
end

desc "Clean build: fullclean, setup_esp32, and rake"
task :cleanbuild do
  puts "Performing clean build..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake')
    end
  rescue => e
    abort "Error during clean build: #{e.message}"
  end
  
  puts "Clean build completed successfully"
end

desc "Build all: setup_esp32 and rake build"
task :buildall do
  puts "Building all components..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during build all: #{e.message}"
  end
  
  puts "Build all completed successfully"
end

desc "Build: execute rake build only"
task :build do
  puts "Building project..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during build: #{e.message}"
  end
  
  puts "Build completed successfully"
end

desc "Check environment setup"
task :check_env do
  setup_environment
  
  puts "\n=== Basic Environment Check ==="
  puts "IDF_PATH: #{ENV['IDF_PATH']}"
  
  esp_idf_exists = File.exist?(ENV['IDF_PATH'] || '')
  puts "ESP-IDF exists: #{esp_idf_exists ? 'Yes' : 'No'}"
  
  unless esp_idf_exists
    puts "Error: ESP-IDF not found. Please install ESP-IDF or update the path."
    abort "ESP-IDF installation required"
  end
  
  puts "\n=== Checking commands without ESP-IDF environment ==="
  # Check basic commands first
  ['python3', 'git', 'cmake'].each do |cmd|
    available = system("which #{cmd}", out: File::NULL, err: File::NULL)
    puts "#{cmd}: #{available ? 'Available' : 'Not found'}"
  end
  
  puts "\n=== Checking ESP-IDF environment ==="
  # Check commands with ESP-IDF environment loaded
  if check_commands_in_esp_env
    puts "=== Environment Check Passed ==="
    puts "ESP-IDF environment is properly configured"
  else
    puts "\nError: ESP-IDF environment setup failed"
    puts "Please check your ESP-IDF installation:"
    puts "1. Ensure ESP-IDF is installed at #{ENV['IDF_PATH']}"
    puts "2. Run: #{ENV['IDF_PATH']}/install.sh"
    puts "3. Test manually: source #{ENV['IDF_PATH']}/export.sh"
    abort "ESP-IDF environment configuration failed"
  end
end

# Default task
task :default => :build
