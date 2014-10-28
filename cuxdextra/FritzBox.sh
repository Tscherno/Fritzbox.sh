#!/bin/bash
# FritzBox.sh
# Version 0.7.6
# https://github.com/Tscherno/Fritzbox.sh
# Anwesend Fritz.box Firmware 6.20
# ----------------------------------------------------------------------

CPWMD5=./cpwmd5
HOMEMATIC="127.0.0.1"

ADDONDIR="/usr/local/addons/cuxd"
CONFIGFILE="/usr/local/addons/cuxd/extra/FritzBox.conf"
FRITZLOGIN="/login_sid.lua"
FRITZWEBCM="/cgi-bin/webcm"
FRITZHOME="/home/home.lua"

TEMPFile="/var/tmp/FritzBox_tempfile.txt"
CURLFile=""
ANRUFLIST="/var/tmp/FritzBox_anruferliste.csv"

# Wie werden die Webseiten aufgerufen
WEBCLIENT="../curl -s"

# Wohin soll geloggt werden
Debug=""
# Alle Debugnachrichten Nachrichten
Debugmsg="FritzBox.sh 0.6.1  \n"

FritzBoxURL="http://fritz.box"
Username=""
Passwd=""

# Parameter 1: POST/GET Daten 
# Parameter 2: (default POST) GET -> Get request
# Parameter 3: Servlet (default FRITZWEBCM) 
PerformPOST(){
	local loggingfile="/dev/null"
	if [ "$Debug" != "" ]; then
		loggingfile=$CURLFile
		Debugmsg=$Debugmsg"GET/POST wind protokolliert in $CURLFile \n"
	fi
	# Parameter 3 ueberpruefen (URL)
	if [ "$3" = "" ]; then
		local URL=$FritzBoxURL$FRITZWEBCM
	else
		local URL=$FritzBoxURL$3
	fi
	# Parameter 2 ueberpruefen (POST oder GET)
	if [ "$2" = "GET" ]; then
		Debugmsg=$Debugmsg"GET  : $1 \n"
		Debugmsg=$Debugmsg"GET  : URL $URL?$1 \n"
		$WEBCLIENT "$URL?$1" >$loggingfile
		Debugmsg=$Debugmsg"GET : Abgesendet \n"
	else
		Debugmsg=$Debugmsg"POST : $1 \n"
		Debugmsg=$Debugmsg"POST : $URL \n"
		$WEBCLIENT -d "$1" "$URL" >$loggingfile
		Debugmsg=$Debugmsg"POST : Abgesendet \n"
	fi
}

EndFritzBoxSkript() {
	local exitcode=$1
	local debugmessage=$2
	if [ "$Debug" != "" ]; then
# Ausgabe in Komandozeile
echo -e "$0 EndFritzBoxSkript() 
EXITCODE: $exitcode
MESSAGE : $debugmessage
LOGGING : Messages so far captured:
$Debugmsg"
# Logging in Debugfile
echo -e "$0 EndFritzBoxSkript() 
EXITCODE: $exitcode
MESSAGE : $debugmessage
LOGGING Messages so far captured: 
$Debugmsg" > $Debug
	fi
	echo $exitcode $debugmessage
	exit $exitcode
}

LOGIN(){
	# Downlod Login XML nach TempFile
	$WEBCLIENT "$FritzBoxURL$FRITZLOGIN">$TEMPFile
	SessionInfoChallenge=$(sed -n '/.*<Challenge>\([^<]*\)<.*/s//\1/p' $TEMPFile)
	SessionInfoSID=$(sed -n '/.*<SID>\([^<]*\)<.*/s//\1/p' $TEMPFile)
	Debugmsg=$Debugmsg"LOGIN: Challenge $SessionInfoChallenge \n"
	Debugmsg=$Debugmsg"LOGIN: SID       $SessionInfoSID \n"
		if [ "$SessionInfoSID" = "0000000000000000" ]; then
		Debugmsg=$Debugmsg"LOGIN: Keine gueltige SID - login aufbauen \n"
		CPSTR="$SessionInfoChallenge-$Passwd"
		MD5=`$CPWMD5 $CPSTR`
		RESPONSE="$SessionInfoChallenge-$MD5" 
		Debugmsg=$Debugmsg"LOGIN: login senden und SID herausfischen \n"
		GETDATA="?username=$Username&response=$RESPONSE"
		Debugmsg=$Debugmsg"LOGIN: $GETDATA \n"
		$WEBCLIENT "$FritzBoxURL$FRITZLOGIN$GETDATA">$TEMPFile
		SID=$(sed -n '/.*<SID>\([^<]*\)<.*/s//\1/p' $TEMPFile)
		rm $TEMPFile
	else
		SID=$SessionInfoSID
		Debugmsg=$Debugmsg"LOGIN: Bereits erfolgreiche SID: $SID \n"
	fi
	if [ "$SID" = "0000000000000000" ]; then
		Debugmsg=$Debugmsg"LOGIN: ERROR - Konnte keine gueltige SID ermitteln \n"
		EndFritzBoxSkript 3 "Keine-gueltige-Anmeldung-moeglich-PassWortoderUser-falsch"
	else
		Debugmsg=$Debugmsg"LOGIN: Gueltige SID: $SID \n"
	fi
}

SetCCUVariable(){
	Debugmsg=$Debugmsg"SetCCUVariable $1 $2 \n"
	if [ "$2" != "" ]; then
		Debugmsg=$Debugmsg"http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27$1%27%29.State%28%22$2%22%29 \n"
		$WEBCLIENT "http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27$1%27%29.State%28%22$2%22%29"	
	else
		Debugmsg=$Debugmsg"SetCCUVariable: Variable nicht gesetzt\n"
	fi
	
	
}

# Lese CONFIGFILE und ersetzen KEY: Value
eval `sed '/^ *#/d;s/:/ /;' < "$CONFIGFILE" | while read key val
do
    str="$key='$val'"
    echo "$str"
done`

# Debug Setzte alle Parameter für Logfile
Debugmsg=$Debugmsg"Parameter CPWMD5      = $CPWMD5 \n"
Debugmsg=$Debugmsg"Parameter HOMEMATIC   = $HOMEMATIC \n"
Debugmsg=$Debugmsg"Parameter ADDONDIR    = $ADDONDIR \n"
Debugmsg=$Debugmsg"Parameter CONFIGFILE  = $CONFIGFILE \n"
Debugmsg=$Debugmsg"Parameter FRITZLOGIN  = $FRITZLOGIN\n"
Debugmsg=$Debugmsg"Parameter FRITZWEBCM  = $FRITZWEBCM \n"
Debugmsg=$Debugmsg"Parameter FRITZHOME   = $FRITZHOME \n"
Debugmsg=$Debugmsg"Parameter TEMPFile    = $TEMPFile \n"
Debugmsg=$Debugmsg"Parameter CURLFile    = $CURLFile \n"
Debugmsg=$Debugmsg"Parameter WEBCLIENT    = $WEBCLIENT \n"
Debugmsg=$Debugmsg"Parameter ANRUFLIST   = $ANRUFLIST \n"
Debugmsg=$Debugmsg"Parameter Debug       = $Debug \n"
Debugmsg=$Debugmsg"Parameter FritzBoxURL = $FritzBoxURL \n"
Debugmsg=$Debugmsg"Parameter Username    = $Username \n"
Debugmsg=$Debugmsg"Parameter Passwd      = $Passwd \n"

if [ "$Passwd" = "" ]; then
	EndFritzBoxSkript 1 "Passwort-nicht-gesetzt-CONF-Datei-pruefen"
fi	

# Wechsle in das Addonverzeichnis
export LD_LIBRARY_PATH=$ADDONDIR
cd $ADDONDIR/extra

Debugmsg=$Debugmsg"INFO:  Befehl $1 $2 $3 \n"
case $1 in
	"test")  		LOGIN
					suche="true"
					linie=\"DECT\"
					string=$($WEBCLIENT "$FritzBoxURL$FRITZHOME?sid=$SID" 2>/dev/null | grep $linie )
					if echo "$string" | egrep -q "true" ; then
						echo "TRUE: $string"
					else
						echo "FALSE: $string"
					fi
					;;
	"WLAN")  		LOGIN
					PerformPOST "wlan:settings/ap_enabled=$2&sid=$SID" "POST";;
	"WLAN5")		LOGIN
					PerformPOST "wlan:settings/ap_enabled_scnd=$2&sid=$SID" "POST";;
	"WLANGast")		LOGIN
					PerformPOST "wlan:settings/guest_ap_enabled=$2&sid=$SID" "POST";;
	"WLANNacht")	LOGIN
					PerformPOST "wlan:settings/night_time_control_no_forced_off=$2&sid=$SID" "POST";;
	"WLANAnwesend") LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
					anwesenheit=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"_node"] = "landevice' -A27 -B2 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "wlan = 1" -B15 | grep "active = 1" -A15 |grep name | sed -e 's/name =//' -e 's/,//')
					anwesenheit1=$(echo $anwesenheit | grep "$2" )
					if [ "$anwesenheit1" != "" ]; then
						Debugmsg=$Debugmsg"WLAN-Anwesend: $2 erkannt\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"WLAN-Anwesend: $2 nicht erkannt\n"
						SetCCUVariable $3 "0"
					fi
					Debugmsg=$Debugmsg"Alle WLAN-Geräte: $anwesenheit \n"
					;;
	"WLANOnline") LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
					anwesenheit=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"_node"] = "landevice' -A27 -B2 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "wlan = 1" -B15 | grep "online = 1" -B1 |grep name | sed -e 's/name =//' -e 's/,//')
					anwesenheit1=$(echo $anwesenheit | grep "$2" )
					if [ "$anwesenheit1" != "" ]; then
						Debugmsg=$Debugmsg"WLAN-Anwesend: $2 erkannt\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"WLAN-Anwesend: $2 nicht erkannt\n"
						SetCCUVariable $3 "0"
					fi
					Debugmsg=$Debugmsg"Alle WLAN-Geräte: $anwesenheit \n"
					;;
	"LANAnwesend") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
					anwesenheit=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"_node"] = "landevice' -A27 -B2 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "wlan = 0" -B15 | grep "active = 1" -A15 | grep name | sed -e 's/name =//' -e 's/,//')
					anwesenheit1=$(echo $anwesenheit | grep "$2" )
					if [ "$anwesenheit1" != "" ]; then
						Debugmsg=$Debugmsg"LAN-Anwesend: $2 erkannt\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"LAN-Anwesend: $2 nicht erkannt\n"
						SetCCUVariable $3 "0"
					fi
					Debugmsg=$Debugmsg"Alle LAN-Geräte: $anwesenheit \n"
					;;
	"LANOnline") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
					anwesenheit=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"_node"] = "landevice' -A27 -B2 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "wlan = 0" -B15 | grep "online = 1" -B1 | grep name | sed -e 's/name =//' -e 's/,//')
					anwesenheit1=$(echo $anwesenheit | grep "$2" )
					if [ "$anwesenheit1" != "" ]; then
						Debugmsg=$Debugmsg"LAN-Anwesend: $2 erkannt\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"LAN-Anwesend: $2 nicht erkannt\n"
						SetCCUVariable $3 "0"
					fi
					Debugmsg=$Debugmsg"Alle LAN-Geräte: $anwesenheit \n"
					;;
	"WakeOnLan")	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
					wol=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"name"] = ' -B2 | grep $2 -B2 |grep mac | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' -e 's/mac =//' -e 's/,//' -e 's/^[ \t]*//;s/[ \t]*$//')
					Debugmsg=$Debugmsg"Debug:"$wol"\n"
					if [ "$wol" != "" ]; then
						Debugmsg=$Debugmsg"WOL-MAC: $2 erkannt: $wol\n"
						./ether-wake $wol
					else
						Debugmsg=$Debugmsg"WOL-MAC: $2 nicht erkannt\n"
					fi
					;;
	"DECT")			LOGIN
					PerformPOST "dect:settings/enabled=$2&sid=$SID" "POST";;	
	"NACHTRUHE") 	LOGIN
					PerformPOST "box:settings/night_time_control_enabled=$2&sid=$SID" "POST";;
	"KLINGELSPERRE") LOGIN
					PerformPOST "box:settings/night_time_control_ring_blocked=$2&sid=$SID" "POST";;
	"RUFUMLEITUNG") LOGIN 
					PerformPOST "telcfg:settings/CallerIDActions$2/Active=$3&sid=$SID" "POST";;
	"Diversity")	LOGIN 
					PerformPOST "telcfg:settings/Diversity$2/Active=$3&sid=$SID" "POST";;	
	"ANRUFEN") 		LOGIN 
					PerformPOST "telcfg:command/Dial=$2&sid=$SID" "POST";;
	"UMTS") 		LOGIN 
					PerformPOST "umts:settings/enabled=$2&sid=$SID" "POST";;	
	"DECT200")		LOGIN
					PerformPOST "sid=$SID&command=SwitchOnOff&id=$2&value_to_set=$3&xhr=1" "POST" "/net/home_auto_query.lua" "DECTCOMMAND0.txt";;
	"DECT200Status") LOGIN
					PerformPOST "sid=$SID&command=AllOutletStates&xhr=0" "POST" "/net/home_auto_query.lua" "DECT200Status0.txt"
					PerformPOST "sid=$SID&command=EnergyStats_10&id=$2&xhr=0" "POST" "/net/home_auto_query.lua" "DECT200ENERGIE0.txt";;
	"DECT200Energie") LOGIN
					Debugmsg=$Debugmsg"DECT200Energie $2 \n"
					Debugmsg=$Debugmsg"$FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=EnergyStats_10&id=$2&xhr=0 \n"
					MM_Value_Power=$($WEBCLIENT "$FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=EnergyStats_10&id=$2&xhr=0" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^MM_Value_Power/ {print $2}' | sed -e 's/"//g' | sed -e 's/ //g')
					Debugmsg=$Debugmsg"MM_Value_Power von $2 = $MM_Value_Power \n"
					SetCCUVariable $3 $MM_Value_Power
					;;
	 "AB") 			LOGIN 
					PerformPOST "tam:settings/TAM$2/Active=$3&sid=$SID" "POST";;
	"Status-AB") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/fon_devices/tam_list.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/fon_devices/tam_list.lua?sid=$SID" | grep '"Active"' -B1 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "\[$2\]" -A1)
					if echo $status | grep -q "Active = 1" ; then 
						Debugmsg=$Debugmsg"Status-AB: $2 aktiv\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"Status-AB: $2 deaktiviert\n"
						SetCCUVariable $3 "0"
					fi
					;;
	"Anrufliste") 	LOGIN
					$WEBCLIENT "$FritzBoxURL/fon_num/foncalls_list.lua?sid=$SID&csv="  "$FritzBoxU RL/fon_num/foncalls_list.lua?sid=$SID&csv=" >$ANRUFLIST 
					;;
	"Anrufliste2CCU")
					LOGIN
					$WEBCLIENT "$FritzBoxURL/fon_num/foncalls_list.lua?sid=$SID&csv=" >$ANRUFLIST 
					out="<table id='fritz'>"
					count=0
					anzahl=`expr $3 + 1`
					while read line; do
						if [ $count -eq $anzahl ]; then
							break       	   
						fi
						if [ "$count" -gt "0" ]; then
							typ=`echo "$line" | cut -f1 -d';'`
							datum=`echo "$line" | cut -f2 -d';'`
							name=`echo "$line" | cut -f3 -d';'`
							rufnummer=`echo "$line" | cut -f4 -d';'`
							nebenstelle=`echo "$line" | cut -f5 -d';'`
							eigene=`echo "$line" | cut -f6 -d';'`
							dauer=`echo "$line" | cut -f7 -d';'`
							out=$out"<tr><td class='fritz_"$typ"'/><td>"$datum"</td><td>"$name"</td><td>"$rufnummer"</td><td>"$nebenstelle"</td><!--<td>"$eigene"</td>--><td>"$dauer"</td></tr>"
						fi
						count=`expr $count + 1` 
					done < $ANRUFLIST
					out=$out"</table>"
					urlencode=$(echo "$out" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/!/%21/g' -e 's/"/%22/g' -e 's/#/%23/g' -e 's/\$/%24/g' -e 's/\&/%26/g' -e 's/'\''/%27/g' -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\*/%2a/g' -e 's/+/%2b/g' -e 's/,/%2c/g' -e 's/-/%2d/g' -e 's/\./%2e/g' -e 's/\//%2f/g' -e 's/:/%3a/g' -e 's/;/%3b/g' -e 's//%3e/g' -e 's/?/%3f/g' -e 's/@/%40/g' -e 's/\[/%5b/g' -e 's/\\/%5c/g' -e 's/\]/%5d/g' -e 's/\^/%5e/g' -e 's/_/%5f/g' -e 's/`/%60/g' -e 's/{/%7b/g' -e 's/|/%7c/g' -e 's/}/%7d/g' -e 's/~/%7e/g')
					$WEBCLIENT "http://$HOMEMATIC/addons/webmatic/cgi/set.cgi?id=$2&value=$urlencode"
					;;
	"Status-DECT") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/dect/dect_settings.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/dect/dect_settings.lua?sid=$SID" | grep 'name="dect_activ" onclick="onDectActiv()"')
					if echo $status | grep -q 'name="dect_activ" onclick="onDectActiv()" checked>' ; then 
						Debugmsg=$Debugmsg"Status-DECT: Dect an\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-DECT: Dect aus\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Status-DECT200") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=AllOutletStates&xhr=0 \n"
					status=$($WEBCLIENT "$FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=AllOutletStates&xhr=0" | grep 'DeviceSwitchState' | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' -e 's/,//' -e 's/^[ \t]*//;s/[ \t]*$//' | grep -Eo "$2.{52}" | grep -Eo "DeviceSwitchState_*.{5}" | grep -Eo ":.{2}" | sed -e 's/: //')
					if [ "$status" = "1" ] ; then 
						Debugmsg=$Debugmsg"Status-DECT: Dect $2 an\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"Status-DECT: Dect $2 aus\n"
						SetCCUVariable $3 "0"
					fi
					;;
	"Status-IP") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID" | grep 'connection0:status/ip')
					if echo $status | grep -q '"-"' ; then 
						Debugmsg=$Debugmsg"Status-IP: - \n"
						SetCCUVariable $2 "-"
					else
						ip=$(echo $status |  sed -e 's/= //;s/",//g;s/"*//g;s/\[connection0:status\/ip\]//g')
						Debugmsg=$Debugmsg"Status-IP: $ip \n"
						SetCCUVariable $2 $ip
					fi
					Debugmsg=$Debugmsg"Status-IP: $ip\n"
					;;										
	"Status-KLINGELSPERRE") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/system/ring_block.lua?sid=$SID\n"
					status=$($WEBCLIENT "$FritzBoxURL/system/ring_block.lua?sid=$SID" | grep 'night_time_control_enabled' | grep -Eo "=.{3}" | sed -e 's/\"//g' -e 's/= //')
					if [ "$status" = "1" ] ; then 
						Debugmsg=$Debugmsg"Status-KLINGELSPERRE: an\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-KLINGELSPERRE: aus\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Status-Verbindung") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID" | grep 'connection0:status/ip')
					if echo $status | grep -q '"-"' ; then 
						Debugmsg=$Debugmsg"Status-Verbindung: nicht verbunden\n"
						SetCCUVariable $2 "0"
					else
						Debugmsg=$Debugmsg"Status-Verbindung: verbunden\n"
						SetCCUVariable $2 "1"
					fi
					;;
	"Status-Verbindungszeit") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID" | grep "connection0:status/conntime_date" -A1)
					status2=$(echo -e $status | sed -e 's/"connection0:status\/conntime_date"//;s/"connection0:status\/conntime_time"//;s/\[\] =//g;s/"//g;s/,//g;s/\n//g;s/^ //g;s/ / /g;s/\./-/g;s/ /%20/g' | sed ':a;N;$!ba;s/\n//g')
					if echo $status2 | grep -q '\"-\"' ; then 
						Debugmsg=$Debugmsg"Status-Verbundindungszeit: - \n"
						SetCCUVariable $2 "-"
					else
						Debugmsg=$Debugmsg"Status-Verbundindungszeit: $status2 \n"
						SetCCUVariable $2 "$status2"
					fi
					Debugmsg=$Debugmsg"Status-Verbundindungszeit: $status2\n"					
					;;					
	"Status-WLAN") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/wlan/wlan_settings.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID" | grep 'id="uiView_Active" name="active"')
					if echo $status | grep -q 'name="active" checked>' ; then
						Debugmsg=$Debugmsg"Status-WLAN: WLAN an\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-WLAN: WLAN aus\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Status-WLANGast") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/wlan/wlan_settings.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID" | grep 'wlan:settings/guest_ap_enabled')
					if echo $status | grep -q '= "1"' ; then
						Debugmsg=$Debugmsg"Status-WLANGast: an\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-WLANGast: aus\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Status-WLANZeitschaltung") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/system/wlan_night.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/system/wlan_night.lua?sid=$SID" | grep 'name="active" id="uiActive"')
					if echo $status | grep -q 'id="uiActive" checked>' ; then
						Debugmsg=$Debugmsg"Status-WLANZeitschaltung: an\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-WLANZeitschaltung: aus\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Status-Rufumleitung") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/fon_num/rul_list.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/fon_num/rul_list.lua?sid=$SID" | grep '"telcfg:settings/CallerIDActions' -A1)
					if echo $status | grep -q '\[1\]' ; then
						Debugmsg=$Debugmsg"Status-Rufumleitung: aktiv\n"
						SetCCUVariable $2 "1"
					else
						Debugmsg=$Debugmsg"Status-Rufumleitung: inaktiv\n"
						SetCCUVariable $2 "0"
					fi
					;;
	"Weckruf") 		LOGIN 
					PerformPOST "telcfg:settings/AlarmClock$2/Active=$3&sid=$SID" "POST";;	
	"Status-Weckruf") 	LOGIN
					Debugmsg=$Debugmsg"URL: $FritzBoxURL/fon_devices/alarm.lua?sid=$SID \n"
					status=$($WEBCLIENT "$FritzBoxURL/fon_devices/alarm.lua?sid=$SID&tab=$2" | grep "telcfg:settings/AlarmClock$2/Active")
					if echo $status | grep -q '"1"' ; then
						Debugmsg=$Debugmsg"Status-Weckruf: aktiv\n"
						SetCCUVariable $3 "1"
					else
						Debugmsg=$Debugmsg"Status-Weckruf: inaktiv\n"
						SetCCUVariable $3 "0"
					fi
					;;
	"reboot") 		LOGIN
					PerformPOST "logic:command/reboot=../gateway/commands/saveconfig.html&sid=$SID" "POST" 
					PerformPOST "security:command/logout=1&sid=$SID" "POST";;
	*) 				Debugmsg=$Debugmsg"MAIN :  ERROR - Bitte wie folgt aufrufen: \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh BEFEHL WERT (0=aus|1=ein) \n"
					Debugmsg=$Debugmsg"        Verfuegbar:  \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLAN [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLAN5 [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLANGast [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLANNacht [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLANAnwesend [Name des WLAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh WLANAnwesend Geraet CCUVariable \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WLANOnline [Name des WLAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh WLANOnline Geraet CCUVariable \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh LANAnwesend [Name des LAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh LANAnwesend Geraet CCUVariable \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh LANOnline [Name des LAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh LANOnline Geraet CCUVariable \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh WakeOnLan [Name des LAN Geraetes] - Beispiel: FritzBox.sh WakeOnLan Geraetename \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh UMTS [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh NACHTRUHE [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh KLINGELSPERRE [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh ANRUFEN [(Telefonnummer z.B. **610)] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh RUFUMLEITUNG [0|1|2|3(Rufumleistung)] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Diversity [0|1|2|3(Rufumleistung)] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT200 [16|17|18|19] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT200Energie [Nummer des Aktors:16|17|18|19] [Name der Variable in der CCU] - Beispiel: FritzBox.sh DECT200Energie 16 DECT200 \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh AB [0|1|2...-9] [0|1] - Beispiel schaltet den 2. AB ein: FritzBox.sh AB 1 1\n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-AB [1|2...-10] [Name der logischen Variable (Bool)in der CCU] - Beispiel Status 2. AB : FritzBox.sh Status-AB 2 CCUVariableAB2 \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Anrufliste \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Anrufliste2CCU [0000(HOMEMATIC Webmatic SYSVAR ID)] [Anzahl Eintraege] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Rufumleitung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Rufumleitung RufumleitungVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-DECT [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT DECTanausVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-DECT200 [16|17|18|19] [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT200 16 DECT16VariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-IP [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-IP ExterneIPVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-KLINGELSPERRE [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-KLINGELSPERRE KLINGELSPERREVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Verbindung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Verbindung InternetverbundenVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Verbindungszeit [Name der logischen Variable (Zeichenkette)in der CCU] Beispiel: FritzBox.sh Status-Verbindungszeit InternetVerbindungszeitVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLAN [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLAN WLANanausVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLANGast [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-WLANGast WLANGastanausVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLANZeitschaltung  [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLANZeitschaltung WLANZeitschaltungVariableCCU \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Weckruf [0|1|2] [0|1] - Beispiel: Schaltet den ersten Weckruf ein  FritzBox.sh Weckruf 0 1 \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Weckruf [0|1|2] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh Status-Weckruf 0 CCUvarWeckruf1 \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh reboot \n"
					EndFritzBoxSkript 4 "Falscher-Parameter-Aufruf-$1-$2-$3-$4";;
esac
EndFritzBoxSkript 0 "Erfolgreich"
