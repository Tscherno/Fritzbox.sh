
Installation:
0. Vorraussetzung:
   cuxd ist auf der Homematic installiert (min 0.58)
   Die FritzBox hat min Version Fritz!OS 5.50 (neuen Loginverfahren)
1. Konfiguration anpassen:
   cuxdextra/FritzBox.conf mit einem Texteditor editieren und dein FritzBox Passwort eintragen
2. Die drei Dateien:
   cuxdextra/FritzBox.conf
   cuxdextra/FritzBox.sh
   cuxdextra/cpwmd5
   in das Verzeichnis /usr/local/addons/cuxd/extra kopieren.
3. Per Putty folgende Befehle eingeben:
   chmod 755 /usr/local/addons/cuxd/extra/FritzBox.sh
   chmod 755 /usr/local/addons/cuxd/extra/cpwmd5
4. überprüfen ob alles funktioniert:
   z.B.: mit sh /usr/local/addons/cuxd/extra/FritzBox.sh DECT200 16 0
Ausgabe ist dann wie folgt:

/usr/local/addons/cuxd/extra/FritzBox.sh EndFritzBoxSkript()
EXITCODE: 0
MESSAGE : Erfolgreich
LOGGING : Messages so far captured:
Parameter CPWMD5      = ./cpwmd5
Parameter HOMEMATIC   = localhost
Parameter ADDONDIR    = /usr/local/addons/cuxd
Parameter CONFIGFILE  = /usr/local/addons/cuxd/extra/FritzBox.conf
Parameter FRITZLOGIN  = /login_sid.lua
Parameter FRITZWEBCM  = /cgi-bin/webcm
Parameter FRITZHOME   = /home/home.lua
Parameter TEMPFile    = /var/tmp/FritzBox_tempfile.txt=
Parameter CURLFile    = /var/tmp/FritzBox_curlfile.html=
Parameter ANRUFLIST   = /var/tmp/FritzBox_anruferliste.csv
Parameter Debug       = /var/tmp/FritzBox.log
Parameter FritzBoxURL = http://fritz.box
Parameter Username    = BoxAdmin
Parameter Passwd      = XXXXXXXXX
INFO:  Befehl DECT200 16 0
LOGIN: Challenge XXXXXXXXX
LOGIN: SID       0000000000000000
LOGIN: Keine gueltige SID - login aufbauen
LOGIN: login senden und SID herausfischen
LOGIN: ?username=BoxAdmin&response=XXXXXXXXXXXXXXXX
LOGIN: Gueltige SID: XXXXXXXXXXXXXXXXX
GET/POST wind protokolliert in /var/tmp/FritzBox_curlfile.html=
POST : sid=59e95f541c13a2f6&command=SwitchOnOff&id=16&value_to_set=0&xhr=1
POST : http://fritz.box/net/home_auto_query.lua
POST : Abgesendet

5. Sollte alles soweit funktionieren empfehle ich das Logging wieder zu deaktivieren
   Hierzu in der FritzBox.conf der Parameter
   Debug: 
   Eingetragen werden (also /var/tmp/FritzBox.log löschen)
6. Am besten lässt sich das Skript in die Homematic einbinden über 
   Cuxd Gerätetyp: (28) System
   Function:       Exec
   Control:        Schalter
   Nachdem das Gerät erstellt wurde muss für den jeweiligen Kanäle jeweils folgendes eingetragen werden:
   (Am Beispiel GästeWLAN)
   SWITCH|CMD_SHORT     sh /usr/local/addons/cuxd/extra/FritzBox.sh WLANGast 0			 	 
   SWITCH|CMD_LONG      sh /usr/local/addons/cuxd/extra/FritzBox.sh WLANGast 1	 	 
   SWITCH|EXEC_TIMEOUT  5

7. Für die Anruflistenanzeige in Webmatic die Dateien aus dem Verzeichnis webmatic
   nach /usr/local/etc/config/addons/www/webmatic_user/ kopieren


Folgende Befehle stehen zur Verfügung:

./FritzBox.sh WLAN [0|1]
./FritzBox.sh WLAN5 [0|1]
./FritzBox.sh WLANGast [0|1]
./FritzBox.sh WLANNacht [0|1]
./FritzBox.sh DECT [0|1]
./FritzBox.sh NACHTRUHE [0|1]
./FritzBox.sh KLINGELSPERRE [0|1]
./FritzBox.sh ANRUFEN [(Telefonnummer z.B. **610)]
./FritzBox.sh RUFUMLEITUNG [0|1|2|3(Rufumleistung)] [0|1]
./FritzBox.sh Diversity [0|1|2|3(Rufumleistung)] [0|1]
./FritzBox.sh DECT200 [16|17|18|19] [0|1]
./FritzBox.sh Anrufliste
./FritzBox.sh Anrufliste2CCU [0000(HOMEMATIC Webmatic SYSVAR ID)] [Anzahl Eintraege]
./FritzBox.sh reboot