/**
 * ESP32 port implementation for PicoRuby I2C module (New API)
 *
 * 既存のinclude/i2c.hインターフェースを維持しつつ、
 * ESP-IDF v5.0+の新しいI2C master APIを使用
 */

#include "driver/i2c_master.h"
#include "esp_log.h"
#include <string.h>

#include "../../include/i2c.h"

static const char* TAG = "picoruby_i2c";

// I2Cバスハンドルを格納する構造体
typedef struct {
    i2c_master_bus_handle_t bus_handle;
    bool initialized;
    uint32_t frequency;
} i2c_bus_context_t;

// 各I2Cポート用のコンテキスト（ESP32は最大2ポート）
static i2c_bus_context_t i2c_contexts[2] = {0};

/**
 * I2Cユニット名をユニット番号に変換する関数
 * 既存インターフェース維持
 */
int I2C_unit_name_to_unit_num(const char *unit_name) {
    if (strcmp(unit_name, "I2C0") == 0 || strcmp(unit_name, "ESP32_I2C0") == 0) {
        return 0; // I2C_NUM_0
    } else if (strcmp(unit_name, "I2C1") == 0 || strcmp(unit_name, "ESP32_I2C1") == 0) {
        return 1; // I2C_NUM_1
    } else {
        return ERROR_INVALID_UNIT;
    }
}

/**
 * I2CのGPIOピンを初期化する関数
 * 既存インターフェース維持：i2c_status_t I2C_gpio_init(int, uint32_t, int8_t, int8_t)
 */
i2c_status_t I2C_gpio_init(int unit_num, uint32_t frequency, int8_t sda_pin, int8_t scl_pin) {
    // ユニット番号が有効か確認
    if (unit_num < 0 || unit_num >= 2) {
        ESP_LOGD(TAG, "Invalid I2C unit: %d", unit_num);
        return ERROR_INVALID_UNIT;
    }

    // 既に初期化済みの場合は既存バスを削除
    if (i2c_contexts[unit_num].initialized) {
        ESP_LOGD(TAG, "I2C unit %d already initialized, reinitializing", unit_num);
        i2c_del_master_bus(i2c_contexts[unit_num].bus_handle);
        i2c_contexts[unit_num].initialized = false;
    }

    // I2Cマスターバス設定
    i2c_master_bus_config_t i2c_mst_config = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = unit_num,
        .scl_io_num = scl_pin,
        .sda_io_num = sda_pin,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };

    // I2Cマスターバスの初期化
    esp_err_t err = i2c_new_master_bus(&i2c_mst_config, &i2c_contexts[unit_num].bus_handle);
    if (err != ESP_OK) {
        ESP_LOGD(TAG, "Failed to initialize I2C master bus: %s", esp_err_to_name(err));
        return ERROR_INVALID_UNIT;
    }

    i2c_contexts[unit_num].initialized = true;
    i2c_contexts[unit_num].frequency = frequency;
    
    ESP_LOGD(TAG, "I2C unit %d initialized (SDA:%d, SCL:%d, freq:%luHz)", 
             unit_num, sda_pin, scl_pin, frequency);

    return ERROR_NONE;
}

/**
 * I2Cからデータを読み込む関数
 * 既存インターフェース維持：int I2C_read_timeout_us(int, uint8_t, uint8_t*, size_t, bool, uint32_t)
 */
int I2C_read_timeout_us(int unit_num, uint8_t addr, uint8_t* dst, size_t len, bool nostop, uint32_t timeout_us) {
    // ユニット番号が有効か確認
    if (unit_num < 0 || unit_num >= 2 || !i2c_contexts[unit_num].initialized) {
        ESP_LOGD(TAG, "I2C unit %d not initialized", unit_num);
        return ERROR_INVALID_UNIT;
    }

    // デバイス設定
    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = addr,
        .scl_speed_hz = i2c_contexts[unit_num].frequency,
    };

    // デバイスハンドルの作成
    i2c_master_dev_handle_t dev_handle;
    esp_err_t err = i2c_master_bus_add_device(i2c_contexts[unit_num].bus_handle, &dev_cfg, &dev_handle);
    if (err != ESP_OK) {
        ESP_LOGD(TAG, "Failed to add I2C device 0x%02X: %s", addr, esp_err_to_name(err));
        return -1;
    }

    // タイムアウトをミリ秒に変換（最小10ms）
    uint32_t timeout_ms = (timeout_us + 999) / 1000; // 切り上げ
    if (timeout_ms < 10) {
        timeout_ms = 10;
    }

    // データ読み込み実行
    err = i2c_master_receive(dev_handle, dst, len, timeout_ms);
    
    // デバイスハンドルの削除
    i2c_master_bus_rm_device(dev_handle);

    if (err != ESP_OK) {
        ESP_LOGD(TAG, "I2C read from 0x%02X failed: %s", addr, esp_err_to_name(err));
        return -1; // 既存インターフェースに合わせて負の値を返す
    }

    return len; // 成功時は読み込んだバイト数を返す
}

/**
 * I2Cにデータを書き込む関数
 * 既存インターフェース維持：int I2C_write_timeout_us(int, uint8_t, uint8_t*, size_t, bool, uint32_t)
 */
int I2C_write_timeout_us(int unit_num, uint8_t addr, uint8_t* src, size_t len, bool nostop, uint32_t timeout_us) {
    // ユニット番号が有効か確認
    if (unit_num < 0 || unit_num >= 2 || !i2c_contexts[unit_num].initialized) {
        ESP_LOGD(TAG, "I2C unit %d not initialized", unit_num);
        return ERROR_INVALID_UNIT;
    }

    // デバイス設定
    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = addr,
        .scl_speed_hz = i2c_contexts[unit_num].frequency,
    };

    // デバイスハンドルの作成
    i2c_master_dev_handle_t dev_handle;
    esp_err_t err = i2c_master_bus_add_device(i2c_contexts[unit_num].bus_handle, &dev_cfg, &dev_handle);
    if (err != ESP_OK) {
        ESP_LOGD(TAG, "Failed to add I2C device 0x%02X: %s", addr, esp_err_to_name(err));
        return -1;
    }

    // タイムアウトをミリ秒に変換（最小10ms）
    uint32_t timeout_ms = (timeout_us + 999) / 1000; // 切り上げ
    if (timeout_ms < 10) {
        timeout_ms = 10;
    }

    // データ書き込み実行
    err = i2c_master_transmit(dev_handle, src, len, timeout_ms);
    
    // デバイスハンドルの削除
    i2c_master_bus_rm_device(dev_handle);

    if (err != ESP_OK) {
        ESP_LOGD(TAG, "I2C write to 0x%02X failed: %s", addr, esp_err_to_name(err));
        return -1; // 既存インターフェースに合わせて負の値を返す
    }

    return len; // 成功時は書き込んだバイト数を返す
}
