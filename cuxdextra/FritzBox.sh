#!/bin/bash
# FritzBox.sh
# https://github.com/Tscherno/Fritzbox.sh
# compatible with Fritz.box Firmware 6.50 and higher, Horst Schmid, 2016-01-05
# /usr/local/addons/cuxd/user/FritzBox.sh
# ----------------------------------------------------------------------
Version="0.7.91"

HOMEMATIC="127.0.0.1"

ADDONDIR="/usr/local/addons/cuxd"
CPWMD5=$ADDONDIR/user/cpwmd5
CONFIGFILE="$ADDONDIR/extra/FritzBox.conf"
FRITZLOGIN="/login_sid.lua"
FRITZWEBCM="/cgi-bin/webcm"
FRITZHOME="/home/home.lua"
CURLFILE="/var/tmp/FritzBoxCurl.txt"
#CURLFILE=""
ANRUFLIST="/var/tmp/FritzBox_anruferliste.csv"

# Wie werden die Webseiten aufgerufen
WEBCLIENT="$ADDONDIR/curl -s"

# Wohin soll geg. geloggt werden 
#DEBUGLOGFILE="/var/tmp/FritzBox.txt"
DEBUGLOGFILE=""

# Alle Debugnachrichten Nachrichten
Debugmsg="FritzBox.sh $Version\n"

FritzBoxURL="http://fritz.box"
Username="" # see CONFIGFILE !
Passwd="" # see CONFIGFILE !

# Parameter 1: POST/GET Daten 
# Parameter 2: (default POST) GET -> Get request
# Parameter 3: Servlet (default FRITZWEBCM="/cgi-bin/webcm") 
PerformPOST(){
	local loggingfile="/dev/null"
	if [ "$DEBUGLOGFILE" != "" ]; then
		loggingfile=$CURLFILE
		Debugmsg=$Debugmsg"GET/POST wird protokolliert in $loggingfile\n"
	fi
	# Parameter 3 ueberpruefen (URL)
	if [ "$3" = "" ]; then
		local URL=$FritzBoxURL$FRITZWEBCM
	else
		local URL=$FritzBoxURL$3
	fi
	# Parameter 2 ueberpruefen (POST oder GET)
	if [ "$2" = "GET" ]; then
		Debugmsg=$Debugmsg"GET URL: $URL?$1 \n"
		$WEBCLIENT "$URL?$1" >>$loggingfile
		Debugmsg=$Debugmsg"GET : Abgesendet \n"
	else
		Debugmsg=$Debugmsg"POST DATA: $1 \n"
		Debugmsg=$Debugmsg"POST URL: $URL \n"
		$WEBCLIENT -d "$1" "$URL" >>$loggingfile
		Debugmsg=$Debugmsg"POST abgesendet, result: $loggingfile\n"
	fi
}

EndFritzBoxSkript() {
	local exitcode=$1
	local debugmessage=$2
	if [ "$DEBUGLOGFILE" != "" ]; then
# Ausgabe in Komandozeile
echo -e "Output of $0 EndFritzBoxSkript() 
EXITCODE: $exitcode
MESSAGE : $debugmessage
Messages so far captured:
$Debugmsg
see also in file $DEBUGLOGFILE"

# Logging in Debugfile
echo -e "Output of $0 EndFritzBoxSkript() 
EXITCODE: $exitcode
MESSAGE : $debugmessage
Messages so far captured: 
$Debugmsg" >> $DEBUGLOGFILE
	fi
	echo $exitcode $debugmessage
	exit $exitcode
}

LOGIN(){
	# We need an SessionInfoChallenge SID from the FB. Combined with the PW an 
	# MD5-Checksum needs to be calculated and send back.
	# 1. Are we already logged in?
	htmlLoginPage=$($WEBCLIENT "$FritzBoxURL$FRITZLOGIN")
	SessionInfoChallenge=$(echo "$htmlLoginPage" | sed -n '/.*<Challenge>\([^<]*\)<.*/s//\1/p')
	SessionInfoSID=$(echo "$htmlLoginPage" | sed -n '/.*<SID>\([^<]*\)<.*/s//\1/p')
	Debugmsg=$Debugmsg"LOGIN: Challenge $SessionInfoChallenge \n"
	if [ "$SessionInfoSID" = "0000000000000000" ]; then
		Debugmsg=$Debugmsg"LOGIN: Keine gueltige SID - login aufbauen \n"
		CPSTR="$SessionInfoChallenge-$Passwd"  # Combine Challenge and Passwd 
		#Debugmsg=$Debugmsg"LOGIN: CPSTR: $CPSTR -> MD5\n"
		MD5=`$CPWMD5 $CPSTR`  # here the MD5 checksum is calculated
		RESPONSE="$SessionInfoChallenge-$MD5" 
		Debugmsg=$Debugmsg"LOGIN: login senden und SID herausfischen, MD5: $MD5\n"
		GETDATA="?username=$Username&response=$RESPONSE"
		Debugmsg=$Debugmsg"LOGIN: $GETDATA \n"
		SID=$($WEBCLIENT "$FritzBoxURL$FRITZLOGIN$GETDATA" | sed -n '/.*<SID>\([^<]*\)<.*/s//\1/p')
		Debugmsg=$Debugmsg"Logged in with SID=$SID\n"
	else
		SID=$SessionInfoSID
		Debugmsg=$Debugmsg"LOGIN: Bereits erfolgreiche SID: $SID \n"
	fi
	if [ "$SID" = "0000000000000000" ]; then
		Debugmsg=$Debugmsg"LOGIN: ERROR - Konnte keine gueltige SID ermitteln \n"
		EndFritzBoxSkript 3 "Keine-gueltige-Anmeldung-moeglich-PassWort oder User-falsch"
	fi
}

SetCCUVariable(){
	Debugmsg=$Debugmsg"SetCCUVariable $1 $2 \n"
	if [ "$2" != "" ]; then
		#Achtung: Trotz Anführungszeichen müssen Leerzeichen in $2 in %20 umgesetzt werden:
		txt=$(echo "$2" | sed 's/ /%20/g' | sed 's/,/%2C/g' | sed 's/:/%3A/g' | sed 's/\n/%0A/g') 
		Debugmsg=$Debugmsg"http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27$1%27%29.Variable%28%22$txt%22%29 \n"
		#$WEBCLIENT "http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27$1%27%29.State%28%22$2%22%29"  
		$WEBCLIENT "http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27$1%27%29.Variable%28%22$txt%22%29"  
		# .State() und .Variable(): Unterschied unklar
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
Debugmsg=$Debugmsg"\nCOMMAND PARAMETERS: $1 $2 $3 \n"
#Debugmsg=$Debugmsg"Parameter CPWMD5      = $CPWMD5 \n"
#Debugmsg=$Debugmsg"Parameter HOMEMATIC   = $HOMEMATIC \n"
#Debugmsg=$Debugmsg"Parameter ADDONDIR    = $ADDONDIR \n"
#Debugmsg=$Debugmsg"Parameter CONFIGFILE  = $CONFIGFILE \n"
#Debugmsg=$Debugmsg"Parameter FRITZLOGIN  = $FRITZLOGIN\n"
#Debugmsg=$Debugmsg"Parameter FRITZWEBCM  = $FRITZWEBCM \n"
#Debugmsg=$Debugmsg"Parameter FRITZHOME   = $FRITZHOME \n"
#Debugmsg=$Debugmsg"Parameter CURLFILE    = $CURLFile \n"
#Debugmsg=$Debugmsg"Parameter WEBCLIENT   = $WEBCLIENT \n"
#Debugmsg=$Debugmsg"Parameter ANRUFLIST   = $ANRUFLIST \n"
Debugmsg=$Debugmsg"Parameter DEBUGLOGFILE= $DEBUGLOGFILE \n"
Debugmsg=$Debugmsg"Parameter FritzBoxURL = $FritzBoxURL \n"
Debugmsg=$Debugmsg"Parameter Username    = $Username \n"
if [ "$Passwd" = "" ]; then
	Debugmsg=$Debugmsg"Parameter Passwd      = <none> \n"
	EndFritzBoxSkript 1 "Passwort-nicht-gesetzt-CONF-Datei-pruefen"
else
	Debugmsg=$Debugmsg"Parameter Passwd      = ****** \n"  # $Passwd
fi  

# Wechsle in das Addonverzeichnis
export LD_LIBRARY_PATH=$ADDONDIR #required by curl to work without "Inconsistency detected by ld.so: dl-deps.c: 622: _dl_map_object_deps: Assertion `nlist > 1' failed!"
cd $ADDONDIR/extra

if [ "$3" = "" ]; then
	if [ "$1"="WLANAnwesend" || "$1"="WLANOnline" || "$1"="LANAnwesend" || "$1"="LANOnline" ]; then
		Debugmsg=$Debugmsg"kein 3. Param, CCUVariable Name fuer WLANAnwesend, WLANOnline, LANAnwesend, LANOnline\n"
	fi
	if [ "$1" = "RUFUMLEITUNG" || "$1" = "Diversity" || "$1" = "DECT200" || "$1" = "AB" ]; then
		Debugmsg=$Debugmsg"kein 3. Param, Rufnummer fuer RUFUMLEITUNG, ?? fuer Diversity, Wert fuer DECT200, ?? fuer AB\n"
	fi
fi

jBoxInfo=$($WEBCLIENT "$FritzBoxURL/jason_boxinfo.xml") # Without Login: Type (Name) of the Box, Firmware-Version, Language, ...)
fbVersion1=$(echo "$jBoxInfo" | grep 'j:Version' | sed -n 's,.*>\(.*\)</.*,\1,p') # s,...,...,p instead of usual s/.../..../p due to "</...>"
# e.g. "113.06.50"
fbVersion2=$(echo "$fbVersion1" | sed -n 's/\(.*\)[.]\(.*\)[.]\(.*\)/\2.\3/p')
Debugmsg=$Debugmsg"FB Firmware Vers: $fbVersion1, $fbVersion2\n"

#status=$(echo "$jBoxInfo" | grep 'j:Name' | sed -n 's,.*>\(.*\)</.*,\1,p')
#Debugmsg=$Debugmsg"FB Type: $status\n"
# May be usefull for further branches for different OS or FritzBox types

#auch ohne login aufrufbar: http://fritz.box/cgi-bin/system_status

# For changeing one WLAN setting we need 1st to get all the WLAN settings: 
case $1 in
	"WLAN24"|"WLAN50"|"WLAN"|"Status-WLAN24"|"Status-WLAN50"|"Status-WLAN"|"Status-WLANGast")
	LOGIN
	htmlPage=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID")
	#Debugmsg=$Debugmsg"\n\n/wlan/wlan_settings.lua\n$htmlPage\nEND-HTML-PAGE\n\n"
	double=$(echo "$htmlPage" | grep -c 'var g_isDoubleWlan =true;')      # var g_isDoubleWlan =true;
	status24=$(echo "$htmlPage" | grep -c 'var g_active =true;')
	sidWLAN24=$(echo "$htmlPage" | grep '.*id="uiView_SSID_24" name="SSID_24".*' | sed -n 's/.*value="\(.*\)".*/\1/p')
	sidHidden=$(echo "$htmlPage" | grep -c '.*id="uiView_HiddenSSID" name="hidden_ssid" checked.*')  
	Debugmsg=$Debugmsg"double: $double\n"
	Debugmsg=$Debugmsg"WLAN old: 2.4GHz: On=$status24, SSID=$sidWLAN24"
	if [ "$double" = '1' ]; then
		status50=$(echo "$htmlPage" | grep -c 'var g_active_scnd =true;')
		sidWLAN50=$(echo "$htmlPage" | grep '.*id="uiView_SSID_5" name="SSID_5".*' | sed -n 's/.*value="\(.*\)".*/\1/p')
		Debugmsg=$Debugmsg"; 5GHz: On:$status50, SSID:$sidWLAN50"
	fi
	Debugmsg=$Debugmsg"\nSID visible: $sidHidden\n"
	;;
esac

case $1 in
	"WLAN24")
		if [ "$sidHidden" = '0' ]; then
			cmdHidden=""
		else
			cmdHidden="&hidden_ssid=on"  # checked = not hidden
		fi
		if [ "$status50" == '1' ]; then
			cmd50="&active_5=on&SSID_5=$sidWLAN50"
		else
			cmd50=""
		fi
		Debugmsg=$Debugmsg"WLAN24: actual:$status24, requested:$2; WLAN50:$cmd50, hidden:$cmdHidden\n"
		if [ "$2" == '0' ]; then # WLAN 2.4GHz off is requested
			if [ "$status24" != '0' ]; then # not yet off
				PerformPOST "active=on&SSID=$sidWLAN24$cmd50$cmdHidden&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
				Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24$cmd50$cmdHidden&sid=$SID&apply=\n"            
			else
				Debugmsg=$Debugmsg"WLAN24 already OFF!\n"            
			fi  
		else # on is requested
			if [ "$status24" != '1' ]; then # not yet on
				PerformPOST "active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24$cmd50$cmdHidden&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
				Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24$cmd50$cmdHidden&sid=$SID&apply=\n"            
			else
				Debugmsg=$Debugmsg"WLAN24 already ON!\n"            
			fi  
		fi
		# optional: Check now again the status: 
		htmlPage=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID")
		status=$(echo "$htmlPage" | grep -c 'var g_active =true;')
		if [ "$2" == '0' ]; then
			if [ "$status" = '1' ]; then
				Debugmsg=$Debugmsg"FAILURE to switch OFF 2.4GHz WLAN\n"
				EndFritzBoxSkript 5 "FAILURE to switch OFF 2.4GHz WLAN"
			else
				Debugmsg=$Debugmsg"2.4GHz WLAN OFF\n"
			fi
		else
			if [ "$status" = '1' ]; then
				Debugmsg=$Debugmsg"2.4GHz WLAN ON\n"
			else
				Debugmsg=$Debugmsg"FAILURE to switch ON 2.4GHz WLAN\n"
				EndFritzBoxSkript 5 "FAILURE to switch ON 2.4GHz WLAN"
			fi
		fi
		;;
	"WLAN50")
		if [ "$double" = '1' ]; then
			if [ "$sidHidden" = '0' ]; then
				cmdHidden=""
			else
				cmdHidden="&hidden_ssid=on"
			fi
			if [ "$status24" == '0' ]; then
				cmd24=''
			else
				cmd24="&active_24=on&SSID_24=$sidWLAN24"
			fi
			Debugmsg=$Debugmsg"WLAN50: actual:$status50, requested:$2; WLAN24:$cmd24\n"
			if [ "$2" == '0' ]; then
				if [ "$status50" != '0' ]; then
					PerformPOST "active=on&SSID=$sidWLAN24$cmd24$cmdHidden&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
					Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24$cmd24$cmdHidden&sid=$SID&apply=\n"            
				else
					Debugmsg=$Debugmsg"WLAN50 already OFF!\n"            
				fi  
			else
				if [ "$status50" != '1' ]; then
					PerformPOST "active=on&SSID=$sidWLAN24$cmd24&active_5=on&SSID_5=$sidWLAN50$cmdHidden&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
					Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24$cmd24&active_5=on&SSID_5=$sidWLAN50$cmdHidden&sid=$SID&apply=\n"            
				else
					Debugmsg=$Debugmsg"WLAN50 already ON!\n"            
				fi  
			fi
			htmlPage=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID")
			status=$(echo "$htmlPage" | grep -c 'var g_active_scnd =true;')
			if [ "$2" == '0' ]; then
				if [ "$status" = '1' ]; then
					Debugmsg=$Debugmsg"FAILURE to switch OFF 5GHz WLAN\n"
					EndFritzBoxSkript 5 "FAILURE to switch OFF 5GHz WLAN"
				else
					Debugmsg=$Debugmsg"5GHz WLAN OFF\n"
				fi
			else
				if [ "$status" = '1' ]; then
					Debugmsg=$Debugmsg"5GHz WLAN ON\n"
				else
					Debugmsg=$Debugmsg"FAILURE to switch ON 5GHz WLAN\n"
					EndFritzBoxSkript 5 "FAILURE to switch ON 5GHz WLAN"
				fi
			fi
		else
			status=$(echo "$jBoxInfo" | grep 'j:Name' | sed -n 's,.*>\(.*\)</.*,\1,p')
			EndFritzBoxSkript 5 "FAILURE: No 5GHz WLAN in $status"
		fi
		;;
	"WLAN")
		if [ "$2" == '0' ]; then
			PerformPOST "active=on&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
			Debugmsg=$Debugmsg"active=on&sid=$SID&apply=\n"
		else
			if [ "$double" = '1' ]; then
				PerformPOST "active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24&active_5=on&SSID_5=$sidWLAN50&hidden_ssid=on&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"         
				Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24&active_5=on&SSID_5=$sidWLAN50&hidden_ssid=on&sid=$SID&apply=\n"
			else
				PerformPOST "active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24&hidden_ssid=on&sid=$SID&apply=" "POST" "/wlan/wlan_settings.lua?sid=$SID"
				Debugmsg=$Debugmsg"active=on&SSID=$sidWLAN24&active_24=on&SSID_24=$sidWLAN24&hidden_ssid=on&sid=$SID&apply=\n"
			fi
		fi
		htmlPage=$($WEBCLIENT "$FritzBoxURL/wlan/wlan_settings.lua?sid=$SID")
		status24=$(echo "$htmlPage" | grep '\["wlan:settings/ap_enabled"\]' | sed -n 's/.*=.*"\(.*\)".*/\1/p')
		status50=$(echo "$htmlPage" | grep '\["wlan:settings/ap_enabled_scnd"\]' | sed -n 's/.*=.*"\(.*\)".*/\1/p')
		if [ "$2" == '0' ]; then
			if [ "$status24" = '1' ]; then
				Debugmsg=$Debugmsg"FAILURE to switch OFF 2.4GHz WLAN\n"
				EndFritzBoxSkript 5 "FAILURE to switch OFF 2.4GHz WLAN"
			else
				if [ "$double" = '1' ]; then
					if [ "$status50" = '1' ]; then
						Debugmsg=$Debugmsg"FAILURE to switch OFF 5GHz WLAN\n"
						EndFritzBoxSkript 5 "FAILURE to switch OFF 5GHz WLAN"
					fi
				fi
				Debugmsg=$Debugmsg"WLAN (2.4 and 5 GHz) OFF\n"
			fi
		else #tried to switch on
			if [ "$status24" = '0' ]; then
				Debugmsg=$Debugmsg"FAILURE to switch ON 2.4GHz WLAN\n"
				EndFritzBoxSkript 5 "FAILURE to switch ON 2.4GHz WLAN"
			else
				if [ "$double" = '1' ]; then
					if [ "$status50" = '0' ]; then
						Debugmsg=$Debugmsg"FAILURE to switch ON 5GHz WLAN\n"
						EndFritzBoxSkript 5 "FAILURE to switch ON 5GHz WLAN"
					fi
				fi
				Debugmsg=$Debugmsg"WLAN (2.4 and 5 GHz) ON\n"
			fi
		fi
		;;
	"WLANGast")		LOGIN
		# nicht verfügbar, falls WLAN nicht eingeschaltet ist
		PerformPOST "wlan:settings/guest_ap_enabled=$2&sid=$SID" "POST" "/wlan/wlan_settings.lua" #/wlan/guest_access.lua.lua ??
		;;
	"WLANNacht")	LOGIN
		PerformPOST "wlan:settings/night_time_control_no_forced_off=$2&sid=$SID" "POST" "/wlan/wlan_settings.lua"
		;;
	"WLANOnline") LOGIN
	  # berücksichtigt noch nicht die richtige tabelle <table id="uiLanActive" ...>...</table>!!
		Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
		htmlPage=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID")
		#Debugmsg=$Debugmsg"$htmlPage\nEND-HTML\n\n"
		active=$(echo "$htmlPage" | sed -n 's/.*<table id="uiLanActive"\(.*\)<\/table>.*/\1/p')
		Debugmsg=$Debugmsg"$active\nEND-uiLanActive\n\n"
		#<td title='Xperia-Horst-14b7aaa58a5d20d0' datalabel='' class='cut_overflow name'>Xperia-Horst-14b7aaa58a5d20d0</td>
	 anwesenheit1=$(echo "$active" | grep -c ".*title=\"$2\".*" )
	 if [ "$anwesenheit1" = '1' ]; then
		 Debugmsg=$Debugmsg"WLAN-Online: $2 erkannt\n"
		 SetCCUVariable $3 "1"
	 else
		 Debugmsg=$Debugmsg"WLAN-Online: $2 nicht erkannt\n"
		 SetCCUVariable $3 "0"
	 fi
		;;
	"LANOnline") 	LOGIN
		Debugmsg=$Debugmsg"URL: $FritzBoxURL/net/network_user_devices.lua?sid=$SID \n"
		anwesenheit=$($WEBCLIENT "$FritzBoxURL/net/network_user_devices.lua?sid=$SID" | grep '"_node"] = "landevice' -A27 -B2 | sed -e 's/\["//g' -e 's/\"]//g' -e 's/\"//g' | grep "wlan = 0" -B26 | grep "online = 1" -B1 | grep name | sed -e 's/name =//' -e 's/,//')
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
		PerformPOST "dect:settings/enabled=$2&sid=$SID" "POST"
		;;  
	"NACHTRUHE") 	LOGIN
		PerformPOST "box:settings/night_time_control_enabled=$2&sid=$SID" "POST"
		;;
	"KLINGELSPERRE") LOGIN
		PerformPOST "box:settings/night_time_control_ring_blocked=$2&sid=$SID" "POST"
		;;
	"RUFUMLEITUNG") LOGIN 
		PerformPOST "telcfg:settings/CallerIDActions$2/Active=$3&sid=$SID" "POST"
		;;
	"Diversity")	LOGIN 
		PerformPOST "telcfg:settings/Diversity$2/Active=$3&sid=$SID" "POST"
		;;  
	"ANRUFEN") 		LOGIN 
		PerformPOST "telcfg:command/Dial=$2&sid=$SID" "POST"
		;;
	"UMTS") 		LOGIN 
		PerformPOST "umts:settings/enabled=$2&sid=$SID" "POST"
		;;  
	"DECT200")		LOGIN
		PerformPOST "sid=$SID&command=SwitchOnOff&id=$2&value_to_set=$3&xhr=1" "POST" "/net/home_auto_query.lua" "DECTCOMMAND0.txt"
		;;
	"DECT200Status") LOGIN
		PerformPOST "sid=$SID&command=AllOutletStates&xhr=0" "POST" "/net/home_auto_query.lua" "DECT200Status0.txt"
		PerformPOST "sid=$SID&command=EnergyStats_10&id=$2&xhr=0" "POST" "/net/home_auto_query.lua" "DECT200ENERGIE0.txt"
		;;
	"DECT200Energie") LOGIN
		Debugmsg=$Debugmsg"DECT200Energie $2 \n"
		Debugmsg=$Debugmsg"$FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=EnergyStats_10&id=$2&xhr=0 \n"
		MM_Value_Power=$($WEBCLIENT "$FritzBoxURL/net/home_auto_query.lua?sid=$SID&command=EnergyStats_10&id=$2&xhr=0" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^MM_Value_Power/ {print $2}' | sed -e 's/"//g' | sed -e 's/ //g')
		Debugmsg=$Debugmsg"MM_Value_Power von $2 = $MM_Value_Power \n"
		SetCCUVariable $3 $MM_Value_Power
		;;
	 "AB") 			LOGIN 
		 PerformPOST "tam:settings/TAM$2/Active=$3&sid=$SID" "POST"
		 ;;
	"Status-AB") 	LOGIN
		# Number of AB is ignored, any activated AB is reported as on
		Debugmsg=$Debugmsg"URL: $FritzBoxURL/fon_devices/tam_list.lua?sid=$SID \n"
		htmlPage=$($WEBCLIENT "$FritzBoxURL/fon_devices/tam_list.lua?sid=$SID")
		#Debugmsg=$Debugmsg"$htmlPage\nHTML-END\n\n"
		#<div id="uiSwitch1" class="switch_on left">
		status=$(echo "$htmlPage" | grep -c '<div id="uiSwitch1" class="switch_on left">')
		if [ "$status" = "1" ] ; then 
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
	"Status-Anrufe") # Datum und Uhrzeit letzter Anruf (e.g. 2015-03-13 17:59)
		LOGIN
		$WEBCLIENT "$FritzBoxURL/fon_num/foncalls_list.lua?sid=$SID&csv=" >$ANRUFLIST 
		out=""
		count=0
		anzahl=`expr $2 + 1`
		#anzahl=2 # 1.Zeile = Überschrift
		while read line; do
			if [ $count -gt $anzahl ]; then
				break            
			fi
			if [ "$count" -gt "0" ]; then
				typ=`echo "$line" | cut -f1 -d';'`
				datum=`echo "$line" | cut -f2 -d';'` # e.g. 19.03.15 17:30
				datumISO=$(echo "$datum" | sed -n 's/\(..\).\(..\).\(..\)/20\3-\2-\1/p') # e.g. 2015-03-19 17:30
				name=`echo "$line" | cut -f3 -d';'`
				rufnummer=`echo "$line" | cut -f4 -d';'`
				nebenstelle=`echo "$line" | cut -f5 -d';'`
				eigene=`echo "$line" | cut -f6 -d';'`
				dauer=`echo "$line" | cut -f7 -d';'`
				if [ "$count" -gt '0' ]; then
					out=$out"$datumISO $typ $dauer $rufnummer $name $nebenstelle $eigene"
				fi
			fi
			count=`expr $count + 1`
		done < $ANRUFLIST
		Debugmsg=$Debugmsg"$out\n"
		SetCCUVariable $3 "$datumISO"           
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
	"Status-FirmwareVersion")
		status=$(echo "$jBoxInfo" | grep 'j:Version' | sed -n 's,.*>\(.*\)</.*,\1,p') # s,...,...,p instead of usual s/.../..../p due to "</...>"
		Debugmsg=$Debugmsg"FB SW Vers: $status\n"
		SetCCUVariable $2 "$status"
		;;
	"Status-BoxType")
		status=$(echo "$jBoxInfo" | grep 'j:Name' | sed -n 's,.*>\(.*\)</.*,\1,p')
		Debugmsg=$Debugmsg"FB Type: $status\n"
		SetCCUVariable $2 "$status"
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
		#not yet adapted to 06.50!!
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
		htmlPage=$($WEBCLIENT "$FritzBoxURL/internet/inetstat_monitor.lua?sid=$SID")
		#Debugmsg=$Debugmsg"$htmlPage\nEND-HTML\n\n"
		#<br>IP-Adresse: 84.57.242.161</span>
		ip=$(echo "$htmlPage" | sed -n 's/.*<br>IP-Adresse: \(.*\)<\/span>.*/\1/p')
		Debugmsg=$Debugmsg"Status-IP: $ip \n"
		SetCCUVariable $2 $ip
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
	"Status-WLAN24")
		if [ "$2" != "" ]; then
			SetCCUVariable $2 $status24
		fi
		if [ "$status24" = "1" ]; then
			Debugmsg=$Debugmsg"Status-WLAN 2.4GHz: an, SID=$sidWLAN24\n"
		else
			Debugmsg=$Debugmsg"Status-WLAN 2.4GHz: aus, SID=$sidWLAN24\n"
		fi
		;;
	"Status-WLAN50")
		if [ "$2" != "" ]; then
			SetCCUVariable $2 $status50
		fi
		if [ "$status50" = "1" ]; then
			Debugmsg=$Debugmsg"Status-WLAN 5GHz: an, SID=$sidWLAN50\n"
		else
			Debugmsg=$Debugmsg"Status-WLAN 5GHz: aus, SID=$sidWLAN50\n"
		fi
		;;
	"Status-WLAN")
		if [ "$2" = ""]; then
			Debugmsg=$Debugmsg"2nd Param not given => no SetCCUVariable!\n"
		else
			SetCCUVariable $2 "$status24" + "status50"
		fi
		if [ "$status24" = "1" ]; then
			Debugmsg=$Debugmsg"Status-WLAN 2.4GHz: an, SID=$sidWLAN24\n"
		else
			Debugmsg=$Debugmsg"Status-WLAN 2.4GHz: aus, SID=$sidWLAN24\n"
		fi
		if [ "$status50" = "1" ]; then
			Debugmsg=$Debugmsg"Status-WLAN 5GHz: an, SID=$sidWLAN50\n"
		else
			Debugmsg=$Debugmsg"Status-WLAN 5GHz: aus, SID=$sidWLAN50\n"
		fi
		;;
	"Status-WLANGast")
		# nicht verfügbar, falls WLAN nicht eingeschaltet ist
		if ["$status24" = "1" || "$status50" = "1" ]; then
			#Debugmsg=$Debugmsg"URL: $FritzBoxURL/wlan/guest_access.lua?sid=$SID \n"
			# data.lua xhr=1, sid=<sid>, lang="de", no_sidrenew="", page="wGuest"
			htmlPage=$($WEBCLIENT "$FritzBoxURL/wlan/guest_access.lua?sid=$SID")
			#Debugmsg=$Debugmsg"$htmlPage\nEND_HTML\n\n"
			#<input id="uiViewActivateGuestAccess" name="activate_guest_access" onclick="onGuestWlanActiv()" checked="" type="checkbox">
			#<input size="33" maxlength="32" id="uiViewGuestSsid" name="guest_ssid" onpaste="valuesChanged()" oninput="valuesChanged()" value="fb7490SdGast" type="text">
			#<input id="uiViewActivateGuestAccess" name="activate_guest_access" onclick="onGuestWlanActiv()" checked="" type="checkbox">
			status=$(echo "$htmlPage" | grep -c '.*name="activate_guest_access" onclick="onGuestWlanActiv()" checked="".*')
		else
			Debugmsg=$Debugmsg"WLAN-Gast nicht verfügbar da WLAN aus!\n"
			status="0"
		fi
		if [ "$status" ='1' ]; then
			Debugmsg=$Debugmsg"Status-WLANGast: an\n"
			SetCCUVariable $2 "1"
		else
			Debugmsg=$Debugmsg"Status-WLANGast: aus\n"
			SetCCUVariable $2 "0"
		fi
		;;
	"Status-WLANZeitschaltung") 	LOGIN
		Debugmsg=$Debugmsg"URL: $FritzBoxURL/system/wlan_night.lua?sid=$SID \n"
		htmlPage=$($WEBCLIENT "$FritzBoxURL/system/wlan_night.lua?sid=$SID")
		#Debugmsg=$Debugmsg"$htmlPage\nEND_HTML\n\n"
		#<input type="checkbox" name="active" id="uiActive" >
		status=$(echo "$htmlPage" | grep 'name="active" id="uiActive"')
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
		PerformPOST "telcfg:settings/AlarmClock$2/Active=$3&sid=$SID" "POST"
		;;  
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
		PerformPOST "security:command/logout=1&sid=$SID" "POST"
		;;
	*)
		Debugmsg=$Debugmsg"MAIN :  ERROR - Bitte wie folgt aufrufen: \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh BEFEHL WERT (0=aus|1=ein) \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh BEFEHL [item] SystemVariable \n"
		Debugmsg=$Debugmsg"        Verfuegbar:  \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLAN24 [0|1] \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLAN50 [0|1] \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLAN [0|1] \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLANGast [0|1] \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLANNacht [0|1] \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh WLANOnline [Name des WLAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh WLANOnline Geraet CCUVariable \n"
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
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Anrufe [Nummer] [Name der logischen Variable (String) in der CCU] Beispiel: FritzBox.sh Status-Anrufe 1 FB_FW_VERS \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-FirmwareVersion [Name der logischen Variable (String) in der CCU] Beispiel: FritzBox.sh Status_FirmwareVersion FB_FW_VERS \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-BoxType [Name der logischen Variable (String) in der CCU] Beispiel: FritzBox.sh Status_BoxType FB_TYPE \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Rufumleitung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Rufumleitung RufumleitungVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-DECT [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT DECTanausVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-DECT200 [16|17|18|19] [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT200 16 DECT16VariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-IP [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-IP ExterneIPVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-KLINGELSPERRE [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-KLINGELSPERRE KLINGELSPERREVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Verbindung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Verbindung InternetverbundenVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Verbindungszeit [Name der logischen Variable (Zeichenkette)in der CCU] Beispiel: FritzBox.sh Status-Verbindungszeit InternetVerbindungszeitVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLAN24 [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLAN WLANanausVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLAN50 [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLAN WLANanausVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLANGast [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-WLANGast WLANGastanausVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-WLANZeitschaltung  [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLANZeitschaltung WLANZeitschaltungVariableCCU \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Weckruf [0|1|2] [0|1] - Beispiel: Schaltet den ersten Weckruf ein  FritzBox.sh Weckruf 0 1 \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh Status-Weckruf [0|1|2] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh Status-Weckruf 0 CCUvarWeckruf1 \n"
		Debugmsg=$Debugmsg"        ./FritzBox.sh reboot \n"
		EndFritzBoxSkript 4 "Falscher-Parameter-Aufruf-$1-$2-$3"
		;;
esac
EndFritzBoxSkript 0 "Erfolgreich"
