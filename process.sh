#!/bin/sh
# Archivo para procesar masivamente archivos MIBS via snmpttconvertmib 
# Author: Rafael Amador Galvan
# Year: 2013

MIB_SOURCE="source/"
MIB_PROCESSED="processed/"
CONF_PATCH="patch/"
MIB_REPO="/usr/share/snmp/mibs/"
ZABBIX_TMP_CONF="zabbix/"
SNMP_CONF_DIR="/etc/snmp/"
SNMPTRAPD_CONF_DIR=$SNMP_CONF_DIR"snmptt.conf.d/"

#Internal variables
CONF_TEMP_DIR=""
MIB_NEW_FILE=""
FILENAME=""

# Enabling this flag disables all write operations over production directories
declare -i IS_DEBUG=0
declare -i FILES_COPIED=0


# Make sure only root can run our script
if (( $EUID != 0 ))
then
   echo " Its Recommended executing this script as Root or sudo " 1>&2
   # exit 1
fi

echo " ------------------------------------- "
echo " MIB Automatic processor.              "
echo " Author: Rafael Amador Galvan - 2013   "
echo " ------------------------------------- "
echo " Source directory: $MIB_SOURCE         "

# Initilizae extended patterns
shopt -s extglob

# Copying MIB files to the base diectory in the server
if (( $EUID == 0 || $IS_DEBUG == 1 )) 
then	
	find $MIB_SOURCE -type f -print0 | while read -d '' -r file
	do
		MIB_NEW_FILE="$MIB_REPO${file##*/}"	
		MIB_NEW_FILE="${MIB_NEW_FILE%\.*}.txt"
		if [ ! -e "$MIB_NEW_FILE" ]
		then
			cp -f $file $MIB_NEW_FILE
			FILES_COPIED=$(($FILES_COPIED + 1)) 	
		fi
	done
	echo " $FILES_COPIED File(s) has been copied to $MIB_REPO."
else
	echo " Not enough privileges to copy files to $MIB_REPO."
fi

find $MIB_SOURCE -print0 | while read -d '' -r file 
do
	if [ -d $file ]
	then
		CONF_TEMP_DIR="$MIB_PROCESSED${file#$MIB_SOURCE}"
		if [ -d $CONF_TEMP_DIR ]; then 
  			if [ -L $CONF_TEMP_DIR ]; then
    				# It is a symlink!
				:
			else
				# It's a directory!
  				:
			fi
		else
			mkdir $CONF_TEMP_DIR
		fi
		# echo "directorio $CONF_TEMP_DIR"	
	else
		MIB_NEW_FILE="${file%\.*}.conf"  
		CONF_TEMP_DIR="$MIB_PROCESSED${MIB_NEW_FILE#$MIB_SOURCE}"
		# echo $MIB_NEW_FILE
		# echo $CONF_TEMP_DIR
		if [ -e $CONF_TEMP_DIR  ]
		then
			rm -f $CONF_TEMP_DIR
		fi
		snmpttconvertmib --in="$file" --out="$CONF_TEMP_DIR" 1>./convertmibs.txt 2>./error.log
		FILE_SIZE=$( stat -c %s $CONF_TEMP_DIR )
		if (( FILE_SIZE < 200 )) 
		then
			echo "[SKIP] $CONF_TEMP_DIR"
			rm -f $CONF_TEMP_DIR
		else
			echo "[OK]   $CONF_TEMP_DIR"
		fi
	fi
done

if (( $EUID == 0 || $IS_DEBUG == 1 ))
then
	echo "[INFO] Processing SNMP Traps to be used in Zabbix"
	if [ ! -d $ZABBIX_CONF_DIR ]
	then
		mkdir $ZABBIX_CONF_DIR
	fi
	find $MIB_PROCESSED'/' -type f -print0 -exec cp {} $ZABBIX_TMP_CONF  \;
	
	echo ""
	echo "--------------------------------------------------------"
	echo "[INFO] Applying patches to config files (snmptt)"
	find $CONF_PATCH -type f -print0 | while read -d '' -r file
	do
		FILENAME=$(basename "$file")
		FILENAME="${FILENAME%.*}"
		# echo "$ZABBIX_TMP_CONF$FILENAME"
		if [ -e "$ZABBIX_TMP_CONF$FILENAME" ]
		then
			if (( $IS_DEBUG == 1 ))
			then
				patch --dry-run "$ZABBIX_TMP_CONF$FILENAME" <"$file"
			else
				patch "$ZABBIX_TMP_CONF$FILENAME" <"$file"
			fi
		fi
	done

	find $ZABBIX_TMP_CONF -type f -print0 -exec sed -i 's,FORMAT,FORMAT ZBXTRAP \$aA,g' {} +
	cp -R -u -p $ZABBIX_TMP_CONF'.' $SNMPTRAPD_CONF_DIR

	echo ""
	echo "[INFO] Recopiling Info about the previously processed Files."
	ls $SNMPTRAPD_CONF_DIR >./zfiles.txt
	sed -i -e "s#^#$SNMPTRAPD_CONF_DIR#g" ./zfiles.txt	
	echo "[INFO] Reconfiguring SNMPTT "
	sed -i -e '/snmptt_conf_files = <<END/,/END/{ # for a here-doc block:
  		/^END$/b          		# if at the end skip rest
  		/<<END/!d         		# if not first line delete and skip rest... else insert file:
  		r ./zfiles.txt
	}' $SNMP_CONF_DIR./snmptt.ini
	echo "[INFO] Reconfiguring Zabbix "
fi
