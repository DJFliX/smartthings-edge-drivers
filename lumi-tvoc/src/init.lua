local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters" 
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local temperature_value_attr_header = function(driver, device, value, zb_rx)
  local temperature = value.value / 100

  if temperature < -99 or temperature > 99 then
    log.info("Temperature value out of range: " .. temperature)
    return
  end

  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = temperature, unit = "C" }))
end

local humidity_value_attr_handler = function(driver, device, value, zb_rx)
  local percent = utils.clamp_value(value.value / 100, 0.0, 100.0)
  if percent<99 then -- filter out spurious values
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(percent))
  end
end

local tvoc_value_attr_handler = function(driver, device, value, zb_rx)
  local tvoc_ppb = utils.clamp_value(value.value, 0.0, 2500.0)
  device:emit_event(capabilities.tvocMeasurement.tvocLevel({value = tvoc_ppb, unit = "ppm"}))
end

local battery_voltage_attr_handler = function(driver, device, value, zb_rx)
  local raw_bat_volt = value.value / 10
  local raw_bat_perc = (raw_bat_volt - 2.5) * 100 / (3.0 - 2.5)
  local bat_perc = math.floor(math.max(math.min(raw_bat_perc, 100), 0))
  device:emit_event(capabilities.battery.battery(bat_perc))
end

local function refresh_handler(driver, device, command)
  device:send(zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue:read(device))
  device:send(zcl_clusters.RelativeHumidity.attributes.MeasuredValue:read(device))
  device:send(cluster_base.read_attribute(device, data_types.ClusterId(0x000C), data_types.AttributeId(0x0055)))
end

local zigbee_temp_driver_template = {
  supported_capabilities = {
    capabilities.relativeHumidityMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.tvocMeasurement,
    capabilities.battery
  },
  use_defaults = true,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    }
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.PowerConfiguration.ID] = {
        [zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_voltage_attr_handler
      },
      [zcl_clusters.TemperatureMeasurement.ID] = {
        [zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID] = temperature_value_attr_header
      },
      [zcl_clusters.RelativeHumidity.ID] = {
        [zcl_clusters.RelativeHumidity.attributes.MeasuredValue.ID] = humidity_value_attr_handler
      },
      [0x000C] = { -- AnalogInput
        [0x0055] = tvoc_value_attr_handler -- PresentValue (single)
      }
    }
  },
}

defaults.register_for_default_handlers(zigbee_temp_driver_template, zigbee_temp_driver_template.supported_capabilities)
local driver = ZigbeeDriver("aqara_tvoc", zigbee_temp_driver_template)
driver:run()