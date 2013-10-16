#About
Das Script Fritzbox.sh ist dazu gedacht eine eQ3 Homematic CCU mit ein AVM Fritz!Box kommunzieren zu lassen. Es läuft dazu direkt auf der CCU. Denkbar ist auch ein Einsatz auf einem Linux-basierten NAS, auch ohne Homematic.

Es basiert auf dem Script das im Homematic-Forum hier gepostet wurde:
http://homematic-forum.de/forum/viewtopic.php?f=37&t=13242

##Voraussetzung

   + cuxd ist auf der Homematic installiert (min 0.58)
   + Die FritzBox hat min Version Fritz!OS 5.50 (neuen Loginverfahren)
   

##Installation

1. Konfiguration anpassen:

   cuxdextra/FritzBox.conf mit einem Texteditor editieren und dein FritzBox Passwort eintragen
  
2. Die drei Dateien:

   + cuxdextra/FritzBox.conf
   + cuxdextra/FritzBox.sh
   + cuxdextra/cpwmd5
   
in das Verzeichnis /usr/local/addons/cuxd/extra kopieren.

3. Per Putty folgende Befehle eingeben:

   `chmod 755 /usr/local/addons/cuxd/extra/FritzBox.sh`
   
   `chmod 755 /usr/local/addons/cuxd/extra/cpwmd5`
   
4. überprüfen ob alles funktioniert:

   z.B.: mit `sh /usr/local/addons/cuxd/extra/FritzBox.sh DECT200 16 0`
   Ausgabe ist dann wie folgt:
   
    `/usr/local/addons/cuxd/extra/FritzBox.sh EndFritzBoxSkript()`   
    `EXITCODE: 0`   
    `MESSAGE : Erfolgreich`   
    `...`    
    `POST : Abgesendet`    


5. Sollte alles soweit funktionieren empfehle ich das Logging wieder zu deaktivieren   
   Hierzu in der FritzBox.conf der Parameter   
   `Debug:`   
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

7. Für die Anruflistenanzeige in Webmatic die Dateien aus dem Verzeichnis `webmatic` 
   nach `/usr/local/etc/config/addons/www/webmatic_user` kopieren

##Funktionen
Folgende Funktionen stehen momentan zur Verfügung:   

     ./FritzBox.sh [AKTION] [PARAMETER]
        WLAN [0|1]  Schaltet WLAN ein bzw. aus 
        WLAN5 [0|1]   Schaltet 5GHz-WLAN ein bzw. aus
        WLANGast [0|1]    Schaltet Gast-WLAN ein bzw. aus
        WLANNacht [0|1]     Schaltet den Nachmodus vom WLAN ein bzw. aus
        WLANAnwesend [Name des WLAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh WLANAnwesend Geraet CCUVariable    
        LANAnwesend [Name des LAN Geraetes] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh LANAnwesend Geraet CCUVariable   
        WakeOnLan [Name des LAN Geraetes] - Beispiel: FritzBox.sh WakeOnLan Geraetename   
        DECT [0|1]    Schaltet DECT ein bzw. aus 
        UMTS [0|1]    Schaltet UMTS ein bzw. aus 
        NACHTRUHE [0|1]   Schaltet Nachruhe ein bzw. aus 
        KLINGELSPERRE [0|1]    Schaltet KLINGELSPERRE ein bzw. aus
        ANRUFEN [(Telefonnummer z.B. **610)]   Ruf diese Nummer über das Telefon an  
        RUFUMLEITUNG [0|1|2|3(Rufumleistung)] [0|1]   Konfiguriert eine Rufumleitung  
        Diversity [0|1|2|3(Rufumleistung)] [0|1]     Konfiguriert eine Rufumleitung
        DECT200 [16|17|18|19] [0|1]     Schaltet DECT200 Geraete ein bzw. aus
        DECT200Energie [Nummer des Aktors:16|17|18|19] [Name der Variable in der CCU] - Beispiel: FritzBox.sh DECT200Energie 16 DECT200     
        AB [0|1|2...-9] [0|1] - Beispiel schaltet den 2. AB ein: FritzBox.sh AB 1 1
        Anrufliste     Erstellt eine Anrufliste fuer Webmatic
        Anrufliste2CCU [0000(HOMEMATIC Webmatic SYSVAR ID)] [Anzahl Eintraege]    Erstellt eine Anrufliste in eine CCU-Variable
        Status-Rufumleitung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Rufumleitung RufumleitungVariableCCU 
        Status-DECT [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT DECTanausVariableCCU 
        Status-DECT200 [16|17|18|19] [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-DECT200 16 DECT16VariableCCU  
        Status-IP [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-IP ExterneIPVariableCCU 
        Status-KLINGELSPERRE [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-KLINGELSPERRE KLINGELSPERREVariableCCU 
        Status-Verbindung [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-Verbindung InternetverbundenVariableCCU 
        Status-Verbindungszeit [Name der logischen Variable (Zeichenkette)in der CCU] Beispiel: FritzBox.sh Status-Verbindungszeit InternetVerbindungszeitVariableCCU 
        Status-WLAN [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLAN WLANanausVariableCCU 
        Status-WLANGast [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh SStatus-WLANGast WLANGastanausVariableCCU 
        Status-WLANZeitschaltung  [Name der logischen Variable (Bool)in der CCU] Beispiel: FritzBox.sh Status-WLANZeitschaltung WLANZeitschaltungVariableCCU  
        Weckruf [0|1|2] [0|1] - Beispiel: Schaltet den ersten Weckruf ein  FritzBox.sh Weckruf 0 1  
        Status-Weckruf [0|1|2] [Name der logischen Variable (Bool)in der CCU] - Beispiel: FritzBox.sh Status-Weckruf 0 CCUvarWeckruf1
        reboot    Startet die Fritzbox neu  
	
	
