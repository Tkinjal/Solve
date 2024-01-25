 

/*
Q1. Controller Status Report -> You are required to write the SQL query with the following output fields for all installed devices. 
1.Device Id
2.Device Type
3.GPS Coordinates: The device_installation_data table has the following format - [Longitude, Latitude, Altitude] however in the report we need [Latitude, Longitude]
4.Signal Strength: Use the following logic -
WHEN (rssi_snr<-80 and rssi_snr>-100) THEN Network Strength = "Excellent"
WHEN (rssi_snr<-100 and rssi_snr>-115) THEN Network Strength = "Good"
WHEN (rssi_snr<-115 and rssi_snr>-125) THEN Network Strength = "Average" ELSE "Poor" 
5.Controller Status
“On” WHEN device_type = “Dual” AND active_power is > 0.05 ELSE “Off”
“On” WHEN device_type = “Group” AND active_power is > 0.1 ELSE “Off”
6.Power Status
“On” if the latest energy meter data packet was received in the last 60 minutes otherwise “Off" 
7.OverLoad
“Yes” if active_power is > 20% of attached_load else “No” 
A few things you need to take into account while solving this question - 
1. Some devices are not sending meter data but the final report should contain all devices in the device_installation_data. 
2. The device_meter_data has almost 100 Million records now so needs to be restricted to only the last 24 hours of data while running the query. 
3. For every device, you need to consider the latest row of energy meter data only. 
*/

with latestdata  as (
select 
dm.device_id, dm.em_reading, dm.active_power, dm.em_timestamp
from  device_meter_data  dm inner join (
select 
device_id, max(em_timestamp) as  latest_timestamp
 from device_meter_data
 where em_timestamp >= date_sub(now(), interval 24 hour)
 group by device_id ) as latest 
on  dm.device_id = latest.device_id  and  dm.em_timestamp = latest.latest_timestamp
)

select 
di.device_id as Device_Id, di.device_type as Device_Type,
concat(substring_index(di.gps_coordinates, ',', -1), ', ', substring_index(di.gps_coordinates, ',', 1)) as GPS_Coordinates,
case
when di.rssi_snr between -80 and -100 then 'Excellent'
when di.rssi_snr between -100 and -115 then 'Good'
when di.rssi_snr between -115 and -125 then 'Average'
else  'Poor'
end as Signal_Strength,
case
when di.device_type = 'Dual' and lm.active_power > 0.05 then 'On'
when di.device_type = 'Group' and lm.active_power > 0.1 then 'On'
else  'Off'
end as Controller_Status,
case
when lm.em_timestamp >= date_sub(now() - interval 60 minute) then 'On'
else  'Off'
end as Power_Status,
case
 when lm.active_power > 0.2 * di.attached_load then 'Yes'
 else 'No'
 end as OverLoad
from
device_installation_data di left join latestdata lm on di.device_id = lm.device_id







/*
Q2. EM Consumption Report -> You are required to write the SQL query with the following output fields for all installed devices. This has to be written in the most optimized way given the size of the table. 
a. Device Id
b. Device Type
c. Date
d. EM Consumed -> EM for a day is the maximum value of em_reading for the device subtracted from the consumed maximum value of em_reading from the previous day. 
*/


with  dmaxconsumption as (
 select 
 device_id, date(em_timestamp) as Date, max(em_reading) AS max_reading
 from device_meter_data
group by device_id, date(em_timestamp)
)
select 
di.device_id as Device_Id, di.device_type as Device_type, dmc.Date, coalesce(max(dmc.max_reading) - lag(max(dmc.max_reading)) over (partition by dmc.device_id order by dmc.Date), 0) as EM_Consumed
from device_installation_data di left join dmaxconsumption dmc on di.device_id = dmc.device_id
group by di.device_id, di.device_type, dmc.Date;
