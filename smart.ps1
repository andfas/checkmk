#########################################################################################
## Smartscan Script 
## for Windows Systems
## Requires smartmontools to be installed
## available from https://sourceforge.net/projects/smartmontools/
## Published under GPL V2
## Initial Version
## 
## Andreas Fassl
## proGIS Software & Beratung
## https://www.progis.de
## afassl@progis.de
## 20.2.2020
#########################################################################################

#########################################################################################
# General Approach
# This checks delivers same results as the smart local plugin for linux systems
# Script is using the output delivered by smartclt in JSON format
# and parsing the results into a checkmk compatible format
# Being stored in the local plugin directory on a given windows system
# it will deliver all the information required to update
# the probing inventory
#########################################################################################


## announce to Check_MK
echo '<<<smart>>>'

## Get all smart devices into JSON List
## 
## Caveat - if smartmontools aren't installed into the standard directory, please change the path accordingly
##
$scan_result = Invoke-Expression "& 'C:\Program Files\smartmontools\bin\smartctl.exe' --scan --json=c" | ConvertFrom-Json

## 
## Loop over available devices
## 

foreach ($device in $scan_result.devices.name) {

## Scan Devices -> smart_result - one device per line
    $smart_result = Invoke-Expression "c:\smartctl.exe -d ata -a $device --json=c" | ConvertFrom-Json
## Remove Blanks from Devicename
	$namestrip=$smart_result.model_name.replace(' ','')

  ## Loop - Results per device
  foreach ($id in $smart_result.ata_smart_attributes.table.id)
	{
	# query values from JSON output
	# Attribute name e.g. "Raw_Read_Error_Rate"
        $smartname =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object name
	# Flag - to be converted to hex e.g. 0x00f
        $smartflag =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object flags
	# Value - e.g. 108
        $smartvalue =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object value
	# Worst - e.g. 95
        $smartworst =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object worst
	# Treshhold - e.g. 6
        $smartthresh =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object thresh
	# Type (prefail) - e.g. Pre-fail
	# Output is true/false, doesn't like checkmk is using this, but for the sake of identical output
        $smarttype =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object flags
	if ($smarttype.flags.prefailure -match "true")
		{ $prefail="Pre-fail" }
	else
		{ $prefail="Old-age" }
	# Update - e.g. Always
        $smartupdate =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object flags
	# When Failed
        $smartwhen =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object flags
	# Raw Value as string - e.g. 18552756
        $smartraw =  $smart_result.ata_smart_attributes.table | where id -eq $id | select-object raw

	# Build string for output (one line per attribute)
	# Will deliver output as required : example
	# ST31000520AS5VX2GZSR ATA ST31000520AS 1 Raw_Read_Error_Rate 0x000f 108 95 6 Pre-fail  Always  -  18552756
	#
	$output=$namestrip +
		$smart_result.serial_number + " "  + 
		$smart_result.device.protocol + " " +
		$namestrip + " " +
		$id + " " +
		$smartname.name + " " +
		"0x" + "{0:x4}" -f $smartflag.flags.value  + " " +
		$smartvalue.value + " " +
		$smartworst.worst + " " +
		$smartthresh.thresh + " " +
		$prefail + " " +

# todo		$smartupdate.flags.updated_online + " " + (not sure, if this is required - dummy result)
		" Always " + 
# todo - 		$smartwhen.flag + " " + (not sure, if this is required - dummy result)
		" - " + " " +
		$smartraw.raw.string 
		
echo $output	
	}
## End of device loop
}
#########################################################################################
# end of script
#########################################################################################
