# domoticz-openDTU

## Summary
Scripts to integrate live data from [OpenDtu](https://github.com/tbnobody/OpenDTU) API into domoticz. So easily show your Hoymiles inverter and panels/trackers as devices.

There are two script.
1. ```solarReadOpenDtu```
will create needed devices and keep track of data changes

2. ```solarInverterForwardLimit```
for support on the fly changes to the limit of the inverter. Keep in mind it might take a couple of minutes to take effect.



| device | image | comment |
| ------ | ------ |-------- |
| inverter | ![Inverter Energy](https://raw.githubusercontent.com/belzetrigger/domoticz-openDTU/main/resources/dev_inverter_energy.png)      | for each inverter listed in openDTU, shows total as energy device - this is the AC value
| inverter current | ![Inverter Custom](https://raw.githubusercontent.com/belzetrigger/domoticz-openDTU/main/resources/dev_inverter_custom.png)       | for each inverter listed in openDTU slightly other device kind (custom sensor)  |
| tracker | ![Tracker Energy](https://raw.githubusercontent.com/belzetrigger/domoticz-openDTU/main/resources/dev_tracker_energy.png)  | for each tracker listed in openDTU for that inverter, shows data as energy sensor  - this is the DC value|
| tracker current | ![Tracker Custom](https://raw.githubusercontent.com/belzetrigger/domoticz-openDTU/main/resources/dev_tracker_custom.png) | for each tracker listed in openDTU for that inverter, again as custom sensor |
| dimmer | ![Inverter Dimmer](https://raw.githubusercontent.com/belzetrigger/domoticz-openDTU/main/resources/dev_inverter_dimmer.png)  | for each inverter listed in openDTU a dimmer to show status of % and if 2nd script is active, also to change it |


## Prepare & Install
* a running Domoticz :)
  - as there were some changes in the used json commands it should be domoticz 2023
  * also check settings for local network security: Einrichtung > Einstellungen > Security: Trusted Networks (no username/password) add 127.0.0.1 and make sure there is no whitespace in between
* a running openDTU
  - check that you can access data
  - check that you can login as admin
  - as we use name of inverter from openDTU, change it there
* create a hardware inside domoticz, this is will be used for adding needed devices
* script ```solarReadOpenDtu```<br>
  this script reads the public live data api, so no password needed
  - copy to script/lua or just create new dzVent-script via menu and copy past content of the script
  - you need to adapt inside this script
    ```
    local solarHardwareId = xx  -- id of dumy hardware used for devices
    local dtuIP = '192.168.x.x' -- the ip of the DTU device
    ```
  - this script will connect with openDTU and create inverter and tracker / panels as domoticz device

* script ```solarInverterForwardLimit```<br>
  to change values via openDTU we need to use our admin with regarding password
  - copy script
  - have username:password ready and base encode it, you can use: <https://www.base64encode.org>
  - adapt inside

    ```
    local usrPw = 'xxxxx' -- base encoded username:password
    local dtuIP = '192.168.xxx.xxx' -- the ip of the DTU device
    local dimmerId = xx -- device id of the dimmer created in first script
    ```
   - keep in mind encoding is no encryption. So if u care about security  lot, use not the inner dzVent script use a external one.


## Known Issues / ToDos
* Do not change names, as we scan devices for matching names
* Do not change description of inverter, as we us serial number from there for the dimmer
* 1st script, it would be enough to just run during day light times <br> ```timer = { 'between 10 minutes before sunset and 10 minutes after sunrise' }```
* 2nd script needs to know device id of dimmer


## Links
- project for OpenDtu <https://github.com/tbnobody/OpenDTU>
- project for Enphase that inspired me <https://www.domoticz.com/forum/viewtopic.php?f=59&t=29516&p=224764&hilit=enphase#p224764>
- see forecast for your local panel - nice to compare a bit <https://forecast.solar>
- script to calculate depending on weather forecast sun power <https://www.domoticz.com/forum/viewtopic.php?t=39668> and <https://www.domoticz.com/wiki/index.php?title=Lua_dzVents_-_Solar_Data:_Azimuth_Altitude_Lux>
* check what is possible <https://pvpublic.com/pvgis/> and <http://re.jrc.ec.europa.eu/pvg_tools/en/tools.html>

## Version
| Version | Note                                       |
| ------- | ------------------------------------------ |
| 2.0  | added action to dimmer to change % via dimmer           |
| 1.0   | if producing of inverter is off, set Watt to 0.0, as openDTU will list last known values              |
| 0.8   | First version of scripts                |
