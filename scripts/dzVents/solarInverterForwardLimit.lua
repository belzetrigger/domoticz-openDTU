--[[
This script reacts on dimmer level change and forward it to regarding openDtu
info:
as inverter only works with sunlight - no light no inverter no changes
easies is use solarReadOpenDtu v2 to let devices create automaticly:

alternative:
use bash script on domoticz to keep user/pw out of domoticz
or
like in v1 just do it here

-- Contributors  ----------------------------------------------------------------
	V1.0  - belzetrigger - init / POC

--]]
--local json = require('dkjson')
local scriptName = 'solarInverterForwardLimit'
local scriptVersion = '1.0'
local apiPath = '/api/limit/config' -- path to fetch data from
local cbName = 'OpenDtuBlzTrigger#3' -- for debug
-- Variables to customize ------------------------------------------------
local usrPw = 'xxx' -- baseencoded username:password
local dtuIP = '192.168.xxx.xxx' -- the ip of the DTU device
local dimmerId = xxx -- device id of the dimmer created in first script
return {
    on =
    {
        devices = { dimmerId },
        httpResponses = {
			cbName -- must match with the callback passed to the openURL command
		}

    },  -- Switch
    logging = {
		level = domoticz.LOG_DEBUG,
		marker = 'BLZ SOLOAR INV',
	},
    execute = function(dz, item )


        if (item.isHTTPResponse) then
            -- dz.log("msg: "..item , dz.LOG_DEBUG)
			if (item.ok) then
				if (item.isJSON) then
				    dz.log("code:" .. item.json.code .. "msg: "..item.json.message , dz.LOG_DEBUG)
				end
		    else

			end

        elseif (item.isDevice ) then
            device = item
            local limit = device.level
            local descr = device.description
            local serial = string.match(descr, "serial: (.*)")
            -- alternative way to run script and do not store user:pw inside domoticz
            -- os.execute("sh /home/pi/domoticz/scripts/dtu_set_limit.sh  ' test ' ")
            -- JSON data to be sent in the POST request
            dz.log("forward " .. limit .. ' to *' .. serial ..'*' , dz.LOG_INFO)
            dz.openURL(
            {
                url  = dtuIP .. apiPath,
                method = 'POST',
                -- headers = { ['Content-Type'] = 'application/json' },
               postData = "data={serial:"..serial..",limit_type:1, limit_value:"..limit.."}",
                headers = {
                    ['content-Type'] = 'application/x-www-form-urlencoded',
                    Authorization = "Basic ".. usrPw
                },
            callback = cbName

            })
        end

    end
}
