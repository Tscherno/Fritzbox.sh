#!/bin/bash
# FritzBox.sh
# Version 0.5.0
# https://github.com/Tscherno/Fritzbox.sh
# ----------------------------------------------------------------------

CPWMD5=./cpwmd5
HOMEMATIC="localhost"

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
Debugmsg="FritzBox.sh 0.4  \n"

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
	Debugmsg=$Debugmsg"http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27"$1"%27%29.State%28"$2"%29 \n"
	
	$WEBCLIENT "http://$HOMEMATIC:8181/test.exe?Status=dom.GetObject%28%27"$1"%27%29.State%28"$2"%29"
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
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh UMTS [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh NACHTRUHE [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh KLINGELSPERRE [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh ANRUFEN [(Telefonnummer z.B. **610)] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh RUFUMLEITUNG [0|1|2|3(Rufumleistung)] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Diversity [0|1|2|3(Rufumleistung)] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT200 [16|17|18|19] [0|1] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh DECT200Energie [Nummer des Aktors:16|17|18|19] [Name der Variable in der CCU] - Beispiel: FritzBox.sh DECT200Energie 16 DECT200 \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Anrufliste \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh Anrufliste2CCU [0000(HOMEMATIC Webmatic SYSVAR ID)] [Anzahl Eintraege] \n"
					Debugmsg=$Debugmsg"        ./FritzBox.sh reboot \n"
					EndFritzBoxSkript 4 "Falscher-Parameter-Aufruf-$1-$2-$3-$4";;
esac
EndFritzBoxSkript 0 "Erfolgreich"
