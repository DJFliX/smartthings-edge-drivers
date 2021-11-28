local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local device_management = require "st.zigbee.device_management"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"

-- A lot of the following was heavily inspired by the following sources:
-- * https://github.com/veonua/SmartThingsEdge-Xiaomi < The base structure of the file (which of course changed over time)
-- * https://github.com/varzac/EdgeDrivers/blob/aqara-tvoc/xiaomi-sensor/src/aqara_air_sensor.lua < The fact that it is possible to register for default handlers for temperature + humidity :mindblown:

local ANALOG_INPUT_CLUSTER = 0x000C
local ANALOG_INPUT_PRESENT_VALUE = 0x0055

local function round_to(val, unit_val)
  local mult = 1 / unit_val
  if mult % 1 ~= 0 then
    error("unit_val should be a power of 10")
  end
  return (utils.round(val * mult)) * unit_val
end

local tvoc_value_attr_handler = function(driver, device, value, zb_rx)
  local tvoc_ppm = value.value / 1000 -- Value is in ppb
  device:emit_event(capabilities.tvocMeasurement.tvocLevel(round_to(tvoc_ppm, .001)))
end

local do_configure = function(self, device)
  device:configure()
  device:refresh()

  device:send(device_management.attr_refresh(device, ANALOG_INPUT_CLUSTER, ANALOG_INPUT_PRESENT_VALUE))
  device:send(device_management.build_bind_request(device, ANALOG_INPUT_CLUSTER, self.environment_info.hub_zigbee_eui))

  local analog_cluster_present_value_conf = {
    cluster = ANALOG_INPUT_CLUSTER,
    attribute = ANALOG_INPUT_PRESENT_VALUE,
    minimum_interval = 60, -- 30 seconds
    maximum_interval = 900, -- 10 minutes
    data_type = data_types.SinglePrecisionFloat,
    -- 10.0 ppb or .01 ppm
    reportable_change = data_types.SinglePrecisionFloat(0, 3, .25)
  }

  device:send(device_management.attr_config(device, analog_cluster_present_value_conf))

end

local function identify_handler(driver, device, zb_rx)
  device:send(device_management.attr_refresh(device, ANALOG_INPUT_CLUSTER, ANALOG_INPUT_PRESENT_VALUE))
end


local zigbee_temp_driver_template = {
  supported_capabilities = {capabilities.relativeHumidityMeasurement, capabilities.temperatureMeasurement,
                            capabilities.tvocMeasurement, capabilities.battery,
                            capabilities.firmwareUpdate},
  use_defaults = true,
  lifecycle_handlers = {
    init = battery_defaults.build_linear_voltage_init(2, 3),
    doConfigure = do_configure
  },
  zigbee_handlers = {
    attr = {
      [ANALOG_INPUT_CLUSTER] = { -- AnalogInput
        [ANALOG_INPUT_PRESENT_VALUE] = tvoc_value_attr_handler -- PresentValue (single)
      }
    },
    cluster = {
      [zcl_clusters.Identify.ID] = {
        [zcl_clusters.Identify.commands.IdentifyQuery.ID] = identify_handler
      }
    }
  }
}

defaults.register_for_default_handlers(zigbee_temp_driver_template,
  {capabilities.temperatureMeasurement, capabilities.relativeHumidityMeasurement, capabilities.battery,
   capabilities.firmwareUpdate})

local driver = ZigbeeDriver("aqara_tvoc", zigbee_temp_driver_template)
driver:run()
