--[[
This script reads openDtu api in real-time some usefull solar data and brings it to domoticz:
info:
as inverter only works with sunlight, we should run shortly before sunrise and a bit after sunset
hardware:
- create a dummy hardware
devices on dtu
- dtu -> inverters 1..x
           -> ac
           -> Dc 1..x
      -> total

-- Contributors  ----------------------------------------------------------------
	V0.8  - belzetrigger - init / POC
    V1.0  - belzetrigger - reset Watt if inverter is not producing energy
    V2.0  - belzetrigger - rework to have better comments and config and dimmer

--]]

local scriptName = 'solarReadOpenDtu'
local scriptVersion = '2.0'

-- Variables to customize ------------------------------------------------
local solarHardwareId = xxx  -- id of dumy hardware used for devices
local intervalMins = 1	    -- The interval of running this script. No need to be faster than the data source. (For example it is 10 min)
local dtuIP = '192.168.xxx.xxx' -- the ip of the DTU device

local apiPath = '/api/livedata/status' -- path to fetch data from
local cbName = 'OpenDtuBlzTrigger' -- used for find correct callback
local createMissing = True         -- if true we create missing devices

local MAX_INVERTER = 2 -- maximum of inverters
local MAX_PANELS = 2 -- maximum of panels per inverter
local currentPanels = 0



return {
	on = {
		timer = {
			'every 1 minutes' -- just an example to trigger the request
			--'every '..tostring(intervalMins)..' minutes between 20 minutes before sunset and 30 minutes after sunrise'
		},
		httpResponses = {
			cbName -- must match with the callback passed to the openURL command
		}
	},
	logging = {
		level = domoticz.LOG_DEBUG,
		marker = 'BLZ SOLOAR DTU',
	},
	execute = function(domoticz, item)
	    -- from domoticz forum
	    function deepdump( tbl )
            local checklist = {}

            local function innerdump( tbl, indent )
                checklist[ tostring(tbl) ] = true
                for k,v in pairs(tbl) do
                        print (indent .. tostring(k) .. " ===> value: ".. tostring(v)  )
                    if (type(v) == "table" and not checklist[ tostring(v) ]) then
                        innerdump(v,indent .. tostring(k) .. ".")
                    end
                end
            end
            checklist[ tostring(tbl) ] = true
            innerdump( tbl, "Key: " )
        end

         -- based on ideas for engpass solar see https://www.domoticz.com/forum/viewtopic.php?f=59&t=29516&p=224764&hilit=enphase#p224764
        local function createDevice(deviceName)
            -- FIXME rawcommand should work with create as well
            -- domoticz.sendCommand('command','param=createdevice;idx='..solarHardwareId..';sensorname='..deviceName..';devicetype=243;devicesubtype=29')
            -- fallback old style
            -- FIXME 2:  domoticz.settings['Domoticz url'] vs 127.0.0.1
            -- with 23.2 new style of parameters!
            domoticz.log('create '..deviceName)
            url = domoticz.settings['Domoticz url'] ..
                  '/json.htm?type=command&param=createdevice&idx='..solarHardwareId ..
                  '&sensorname=' .. domoticz.utils.urlEncode(deviceName) ..
                  '&sensormappedtype=0xF31D'
            domoticz.openURL(url)
            -- Maybe wait a bit beofore creating to much
            -- domoticz.openURL(url).afterSec(url2)

        end

        local function createDeviceWatt(deviceName)
            domoticz.log('create '..deviceName)
            url = domoticz.settings['Domoticz url'] ..
                  '/json.htm?type=command&param=createdevice&idx='..solarHardwareId ..
                  '&sensorname=' .. domoticz.utils.urlEncode(deviceName) ..
                  '&sensormappedtype=0xF31F' ..
                  '&sensoroptions=1;Watt'
            domoticz.openURL(url)

        end

       --https://dom-pi/json.htm?type=command&param=createdevice&idx=44&sensorname=scal&sensormappedtype=0xF449
       local function createDeviceDimmer(deviceName)
            domoticz.log('create '..deviceName)
            url = domoticz.settings['Domoticz url'] ..
                  '/json.htm?type=command&param=createdevice&idx='..solarHardwareId ..
                  '&sensorname=' .. domoticz.utils.urlEncode(deviceName) ..
                  '&sensormappedtype=0xF449'
            domoticz.openURL(url)

        end

        local function correctDeviceDimmer(idx, name, description)
            domoticz.log('update '.. name)
            --https://dom-pi/json.htm?addjvalue=0&addjvalue2=0&customimage=0&description=sdsdsd&idx=651&name=inv&options=&param=setused&protected=false&strparam1=aHR0cDovL2Zvbw%3D%3D&strparam2=aHR0cDovL2Jhcg%3D%3D&switchtype=7&type=command&used=tru3
            url =   domoticz.settings['Domoticz url'] .. '/json.htm?'..
                    'type=command&param=setused&switchtype=7' ..
                    '&strparam1=aHR0cDovL2Zvbw%3D%3D&strparam2=aHR0cDovL2Jhcg%3D%3D' ..
                    '&used=true' ..
                    '&idx=' ..  idx  ..
                    '&name=' .. domoticz.utils.urlEncode(name) ..
                    '&description=' .. domoticz.utils.urlEncode(description)
            domoticz.openURL(url).afterSec(1)
            domoticz.log('Changing switch ' .. name ..' to dimmer type: \n' .. url,domoticz.LOG_FORCE)

        end


        -- adpat usage type
        local function correctDevice(idx, name, description)
            domoticz.log('update '.. name)
            --https://dom-pi/json.htm?type=command&param=setused&idx=643&name=deviceName&description=aaaa&switchtype=4&EnergyMeterMode=0&customimage=0&used=true
            url =   domoticz.settings['Domoticz url'] .. '/json.htm?type=command&param=setused&switchtype=4&EnergyMeterMode=0&used=true' ..
                    '&idx=' ..  idx  ..
                    '&name=' .. domoticz.utils.urlEncode(name) ..
                    '&description=' .. domoticz.utils.urlEncode(description)
            domoticz.openURL(url).afterSec(1)
            domoticz.log('Changing inverter ' .. name ..' to delivery type: \n' .. url,domoticz.LOG_FORCE)
            --Enphase.openURLDelay = Enphase.openURLDelay + 1
        end

        local function checkHardware()
            local hardware=domoticz.hardware(solarHardwareId)
            if hardware == nil then
                domoticz.log('Hardware '.. tostring(solarHardwareId) .. ' does not exist, check configuration in script and hardware settings', domoticz.LOG_ERROR)
    			return	false
            else
               return true
            end
        end



        local function printData(data)
            if data == nil then return end

            local powerV = data.Power.v  -- Watt
            if powerV ~= nil then
                domoticz.log('power W: ' .. powerV )
            end
			local yieldDay = data.YieldDay.v  -- in Wh
			if yieldDay ~= nil then
                domoticz.log('yieldDay Wh: ' .. yieldDay )
            end
			local yieldTotal = data.YieldTotal.v -- in kWh
			if yieldTotal ~= nil then
                domoticz.log('YieldTotal kWh: ' .. yieldTotal )
            end

        end

        local function printDC(data)
            if data.name ~= nil then
                local name = data.name.u
                if name ~= nil then
                    domoticz.log('name: ' .. name )

                end
            else
                domoticz.log('no name ' )
            end
            printData(data)
        end

        local function printInverter(data)
            local name = data.name
            if name ~= nil then
                domoticz.log('name: ' .. name )
            end
            local serial = data.serial
            if serial ~= nil then
                domoticz.log('serial: ' .. serial )
            end
        end

        local function readDataFromDtu(json)
            dcTab = {}
            for i = 0,MAX_PANELS do
                value =  json[tostring(i)]
                if value == nil then
                    domoticz.log('data: ' .. i .. ' is EMPTY', domoticz.LOG_INFO)
                else
                    domoticz.log('data: ' .. i .. ' has value', domoticz.LOG_INFO)
                    --domoticz.log('dc: ' .. i .. ' ' .. tostring(value), domoticz.LOG_DEBUG)
                    dcTab[i+1] = value
                    --domoticz.log('dc: ' .. i .. ' ' .. tostring(dcTab[i+1]), domoticz.LOG_DEBUG)
                    printDC(value)
                    currentPanels = i
                end
            end
            return dcTab
        end

        local function readInvertersFromDtu(json)
            invTab = {}
            for i = 1,MAX_INVERTER do
                value =  json[i]
                if value == nil then
                    domoticz.log('inv: ' .. i .. ' is EMPTY', domoticz.LOG_INFO)
                else
                    domoticz.log('inv: ' .. i .. ' has value', domoticz.LOG_INFO)
                    --domoticz.log('dc: ' .. i .. ' ' .. tostring(value), domoticz.LOG_DEBUG)
                    invTab[i] = value
                    --domoticz.log('dc: ' .. i .. ' ' .. tostring(dcTab[i+1]), domoticz.LOG_DEBUG)
                    --printInverter(value)
                end
            end
            return invTab
        end

        -- search for name, if missing create
        -- also check return type
        -- finaly set values
        local function updateElectricity(name, descr, data, producing)
            local hardware=domoticz.hardware(solarHardwareId)
            local myDevice = hardware.devices().find(function(device)
                return device.name == name
                end)

            if myDevice == nil then
                domoticz.log('device missing: ' , domoticz.LOG_ERROR)
                if createMissing == True then
                    createDevice(name)
                end
            else
                domoticz.log('Id: ' .. myDevice.id, domoticz.LOG_INFO)
                if myDevice.switchTypeValue ~= 4 then
                    correctDevice(myDevice.id, name, descr)
                end
                --(dc0PowerV,dc0YieldTotal*1000)
                if( producing == false ) then
                     myDevice.updateElectricity(0, data.YieldTotal.v*1000 )
                else
                    myDevice.updateElectricity(data.Power.v, data.YieldTotal.v*1000 )
                end

            end

        end

        local function updateWatt(name, descr, data,producing)
            local hardware=domoticz.hardware(solarHardwareId)
            local myDevice = hardware.devices().find(function(device)
                return device.name == name
                end)

            if myDevice == nil then
                domoticz.log('device missing: ' , domoticz.LOG_ERROR)
                if createMissing == True then
                    createDeviceWatt(name)
                end
            else
                domoticz.log('Id: ' .. myDevice.id, domoticz.LOG_INFO)
                if( producing == false ) then
                    myDevice.updateCustomSensor(0)
                else
                    myDevice.updateCustomSensor(data.Power.v)
                end
            end

        end

        local function updateDimmer(name, descr, value, producing)
            domoticz.log('update dimmer: ' .. name .. ' to ' .. value, domoticz.LOG_DEBUG)
            -- check that max 100
            dimLevel = math.min(math.max(value, 0), 100)
            local hardware=domoticz.hardware(solarHardwareId)
            local myDevice = hardware.devices().find(function(device)
                return device.name == name
                end)

            if myDevice == nil then
                domoticz.log('device dimmer missing: ' , domoticz.LOG_ERROR)
                if createMissing == True then
                    createDeviceDimmer(name)
                end
            else
                local state =  myDevice.state
                if state == nil or state == "" then
                    domoticz.log('device dimmer no state?: ' , domoticz.LOG_ERROR)
                    state = 'Off'
                else
                    domoticz.log('device dimmer state?: "' .. state .. '"' , domoticz.LOG_DEBUG)
                end
                domoticz.log('update dimmer Id: ' .. myDevice.id ..
                    ' status: ' .. myDevice.state ..
                    ' limit: ' .. myDevice.level , domoticz.LOG_INFO)
                if myDevice.switchTypeValue ~= 7 then
                    correctDeviceDimmer(myDevice.id, name, descr)
                end
                -- Avoid trigger action script
                -- see https://www.domoticz.com/forum/viewtopic.php?t=8495&start=20
                local newState = 'On'
                if producing == false then newState = 'Off' end

                if myDevice.level ~= dimLevel then
                    domoticz.log('dimmer update level from '.. myDevice.level .. ' to ' .. dimLevel , domoticz.LOG_DEBUG)
                    -- working code, but forces / triggers action
                    -- myDevice.setLevel(dimLevel)
                    --myDevice.update(dimLevel, dimLevel)
                    myDevice.dimTo(dimLevel)
                end
                if producing == false and myDevice.state == 'On'then
                    myDevice.switchOff()
                    domoticz.log('dimmer turn off' , domoticz.LOG_INFO)
                elseif producing == true and myDevice.state == 'Off' then
                    myDevice.switchOn()
                    domoticz.log('dimmer turn on' , domoticz.LOG_INFO)
                end

                --if myDevice.level ~= dimLevel then
                --   myDevice.update(88, 88)
                --end
                --[[if producing == false and state == 'On' then
                    myDevice.switchOff()
                    domoticz.log('dimmer turn off' , domoticz.LOG_INFO)
                elseif state == 'Off' then
                    myDevice.switchOn()
                    domoticz.log('dimmer turn on' , domoticz.LOG_INFO)
                end
                ]]--
            end

        end


		if (item.isTimer) then
		    local apiUrl = 'http://'..dtuIP..apiPath
		    domoticz.log('call api under ' ..apiUrl,domoticz.LOG_INFO)
			domoticz.openURL({
				url = apiUrl,
				method = 'GET',
				callback = cbName, -- see httpResponses above.
			})
		end

        if checkHardware() == false then return end



		if (item.isHTTPResponse) then

			if (item.ok) then
				if (item.isJSON) then


                    if item.json.inverters[1] == nil then
                        domoticz.log('Empty return from dtu. Go check it out', domoticz.LOG_ERROR)
                        return
                    end


                    local inverters = readInvertersFromDtu(item.json.inverters)
                    for i, inv in ipairs(inverters) do
                        domoticz.log('check inverter: ' .. i)
                        local iName = inv.name
                        local prefix = 'INV#' .. i
                        local serial = inv.serial
                        local producing = inv.producing
                        if producing == false then
                           domoticz.log('not producing at the moment ',domoticz.LOG_INFO)
                        end
                        printInverter(inv)
                        -- now get data, atm only one AC supported
                        local ac = readDataFromDtu(inv.AC)
                        updateElectricity(prefix ..' ' .. iName, prefix .. 'serial: ' .. serial , ac[1], producing)
                        updateWatt(prefix  ..' ' .. iName ..'-Current', prefix .. ' serial: ' .. serial , ac[1], producing)

                        -- inv wirkungsgrade
                        local limitR = inv.limit_relative
                        local limitA =inv.limit_absolute
                        updateDimmer(prefix  ..' ' .. iName ..'-Limit', prefix .. ' serial: ' .. serial , limitR, producing)

                        -- scan for panels
                        local panels = readDataFromDtu(inv.DC)

                        for k, panel in ipairs(panels) do
                            domoticz.log('check panels: ' .. k)
                            local prefix = 'INV#' .. i ..'#' .. k
                            local pName =  panel.name.u
                            printDC(panel)
                            updateElectricity(prefix, pName, panel, producing)
                            updateWatt(prefix .. '-Current', pName ..'-Current', panel, producing)

                        end

                    end

                    local inv = readDataFromDtu(item.json.inverters[1].AC)

					-- turn on for debug
                    -- deepdump(item.json.inverters[1])
                    -- deepdump(item.json.inverters[1].DC)


					-- clockTime = os.date("%x %X")
                    -- local newName= domoticz.utils.urlEncode("Solar total: "..ac0YieldDay.." Wh "  ..  clockTime)
                    -- test.updateText(clockTime)
                    --  domoticz.settings["Domoticz url"]
                    -- url = "https://192.168.176.16/json.htm?type=command&param=renamedevice&idx=" .. dvTotal.id .."&name="  .. newName
                    -- domoticz.openURL( url)

				else
				    domoticz.log('BLZ#2 There was a problem response is no json', domoticz.LOG_ERROR)
				end
			else
				domoticz.log('BLZ#3 There was a problem handling the request', domoticz.LOG_ERROR)
				domoticz.log(item, domoticz.LOG_ERROR)
			end

        --else
            --domoticz.log('BLZ#4 There was a problem getting the response', domoticz.LOG_ERROR)
		end

	end
}
