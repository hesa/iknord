#!/bin/bash


#
# If you've ever seen a really (I mean really) dirty hack 
#   - this script will beat it 
#


RUN_DIR=/var/run/handboll
LOCAL=false

SERIES_CONF=$(dirname $0)/series.conf
if [ -f $SERIES_CONF ] 
then
    . $SERIES_CONF 
else
    echo $SERIES_CONF not found
    exit 1
fi

MODE=all
while [ "$1" != "" ]
do
    if [ "$1" = "--debug" ]
    then
	DEBUG=true
    elif [ "$1" = "--generate" ]
    then
	MODE=generate
    elif [ "$1" = "--get-data" ]
    then
	MODE=get
    elif [ "$1" = "--clean-db" ]
    then
	MODE=clean
    elif [ "$1" = "--series" ]
    then
	SERIES="$2"
	shift
    elif [ "$1" = "--check-db" ]
    then
	MODE="check"
    elif [ "$1" = "--separate" ]
    then
	MODE="separate"
    elif [ "$1" = "--local" ]
    then
	LOCAL=true
    else
	MODE=unknown
    fi
    shift
done



BASE_DIR=$(pwd)
FAKE_DATA_DIR=~/opt/iknord/elit-data-backup

#SERIES="F01 P04 " 
declare -a MONTHS
declare -a MONTHS_NR
declare -a MONTHS_REGEXP

SILENT=false

YEAR1_NR=14
YEAR2_NR=15
LONG_YEAR1_NR=2014
LONG_YEAR2_NR=2015

BACKUP_DIR=$(pwd)/results/$(date +%Y-%m-%d)

MYTMPDIR=tmp/elitserien
LOG_DIR=/tmp/handboll
LOG_FILE=${LOG_DIR}/handboll-ics.log
HTML_PAGE=$(pwd)/index.html

if [ ! -d ${MYTMPDIR} ]
then
    mkdir -p ${MYTMPDIR}
fi
if [ ! -d ${RUN_DIR} ]
then
    mkdir -p ${RUN_DIR}
fi




SQLITE=sqlite3
DB_DIR=$(pwd)

DB_FILE=HANDBOLL-SEH.sqlite
DB=${DB_DIR}/${DB_FILE}


log()
{
    if [ "$SILENT" = "true" ]
    then
	return
    fi

    if [ ! -d ${LOG_DIR} ]
	then
	mkdir -p  ${LOG_DIR}
    fi

    echo "[$(basename $0)  $(date '+%y-%m-%d %H:%M:%S') ] $*" >> $LOG_FILE
}

db_command() {
    if [ ! -f ${DB} ]
    then
	log "DB ${DB} not present, creating it"
    fi

    if [ "$DEBUG" = "true" ]
    then
	echo "db_command:   $*  [${DB}]" ;
    fi
    log "$* | $SQLITE ${DB}"
    echo "$*" | $SQLITE ${DB}
}

clean_db() 
{
    if [ "$DEBUG" = "true" ]
    then
	echo not cleaning db
    else
	mkdir -p db-backup
	mv $DB_FILE db-backup/$DB_FILE-$(date '+%y-%m-%d')
	DB_CREATE="CREATE TABLE matcher (date DATE NOT NULL, time TIME NOT NULL, updatedate DATE NOT NULL, updatetime TIME NOT NULL, location varchar(50) NOT NULL, serie varchar(50) NOT NULL, home varchar(50) NOT NULL, away varchar(50) NOT NULL, matchid varchar(100) NOT NULL, url varchar(200), result varchar(200), PRIMARY KEY (matchid));"
	
	db_command "$DB_CREATE"
    fi
}

insert_game() 
{
    MATCH_ID="$7"

    if [ "$DEBUG" = "true" ]
    then
	printf "Match id: %10s" $MATCH_ID
    fi
    #   echo "MATCH_ID=$MATCH_ID"
    
    NEW_DATE="$1"
    NEW_TIME="$2"
    NEW_LOCATION="$3"
    NEW_SERIE="$4"
    NEW_HOME="$5"
    NEW_AWAY="$6"
    NEW_ID="$7"
    NEW_URL="$8"
    NEW_RESULT="$9"

    UTC_DATE_NOW=$(TZ=UTC date  '+%Y-%m-%d')
    UTC_TIME_NOW=$(TZ=UTC date  '+%H:%M:%S')
    

    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE matchid='$MATCH_ID';"

    COUNT=$(db_command $SELECT_STMT)
    #    echo "------------ $5 $6 : COUNT: $COUNT"

    if [ $COUNT -gt 1 ] 
    then
	echo "Shit..... $SELECT_STMT returned $COUNT occ"
	sleep 2
	exit 0
    elif [ $COUNT -ne 0 ] 
    then
	SELECT_STMT="SELECT date, time, serie, home, away, matchid, url, location, result FROM matcher WHERE matchid='$MATCH_ID' ;"
	
	LINE=$(db_command $SELECT_STMT)

	#	echo "------------>"
	#	echo  " $LINE  "
	COUNT=$(( $COUNT + 1 ))
	if [ "$LINE" = "" ] ; then break; fi
	LAST_DATE=$DATE
	DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $1 ;}' )
	TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $2 ;}' )
	SERIE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $3 ;}' )
	HOME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $4 ;}' )
	AWAY=$(echo $LINE | awk ' BEGIN {FS="|"} { print $5 ;}' )
	MATCHID=$(echo $LINE | awk ' BEGIN {FS="|"} { print $6 ;}' )
	URL=$(echo $LINE | awk ' BEGIN {FS="|"} { print $7 ;}' )
	LOCATION=$(echo $LINE | awk ' BEGIN {FS="|"} { print $8 ;}' )
	RESULT=$(echo $LINE | awk ' BEGIN {FS="|"} { print $9 ;}' )
	
	
	#	echo "------------------- DATE:$DATE / $TIME"
	#  | $(date '+%Y%m%d' --date '$DATE')"
	
	URL_LINK=""
	if [ "$URL" != "--" ]
	then
	    URL_LINK="(<a href=\"$URL\">more info</a>)"
	fi
	
	LOCATION_LINK=""
	if [ "$LOCATION" != "--" ]
	then
	    LOCATION_LINK="($LOCATION)"
	fi
	#	echo "<------------"
	
	
	if [ "$NEW_DATE" != "$DATE" ] || [ "$NEW_TIME" != "$TIME" ] || [ "$NEW_LOCATION" != "$LOCATION" ] || [ "$NEW_HOME" != "$HOME" ] || [ "$NEW_AWAY" != "$AWAY" ]  || [ "$NEW_RESULT" != "$RESULT" ] 
	then
	    log "DIFF"
	    log "RESULT: '$RESULT'   '$NEW_RESULT'"
	    log "--------------------------"
	    log "'$NEW_DATE' '$NEW_TIME' '$NEW_LOCATION' '$NEW_HOME' '$NEW_AWAY'"  
	    log "'$DATE' '$TIME' '$LOCATION' '$HOME' '$AWAY'" 
	    log "update"
	    ####	    db_command "SELECT updatedate, updatetime, home, away  FROM matcher WHERE matchid='$MATCH_ID';"
	    log "NOW: '$UTC_DATE_NOW', '$UTC_TIME_NOW"

	    #	    sleep 5

	    UPDATE_GAME="UPDATE matcher SET date='$NEW_DATE', time='$NEW_TIME', updatedate='$UTC_DATE_NOW', updatetime='$UTC_TIME_NOW' , result='$NEW_RESULT' WHERE matchid='$MATCH_ID' ;"

	    db_command "$UPDATE_GAME"	

	    #	    db_command "SELECT updatedate, updatetime, home, away  FROM matcher WHERE matchid='$MATCH_ID';"

	    #	    exit

#	else
	    #	echo "=============================================================== $5 vs. $6 NO DIFF"
	    #	    echo "NO DIFF... $AWAY $HOME"
#	    echo -n " . "
	fi

    else
	#	echo "=============================================================== $5 vs. $6 AS Roma"

	DB_GAME="INSERT INTO matcher VALUES ('$1','$2', '$UTC_DATE_NOW', '$UTC_TIME_NOW', '$3','$4','$5','$6', '$7', '$8' , '$9' );"
	log "$DB_GAME"
	db_command "$DB_GAME"
    fi

    #	echo "=============================================================== $5 vs. $6 LIVERPOOOLLLL"

    if [ "$DEBUG" = "true" ]
    then
	TMP=0
	while [ $TMP -lt 20 ]
	do
	    printf "\b"
	    TMP=$(( $TMP + 1 ))
	done
    fi

}


init()
{
    idx=0
    for i in September Oktober November December Januari Februari Mars April
    do
	MONTHS[$idx]=$i
	idx=$(( $idx + 1))
    done
    idx=0

    for i in $YEAR1_NR-09- $YEAR1_NR-10- $YEAR1_NR-11- $YEAR1_NR-12- $YEAR2_NR-01- $YEAR2_NR-02- $YEAR2_NR-03- $YEAR2_NR-04- 
    do
	MONTHS_REGEXP[$idx]=$i
	idx=$(( $idx + 1))
    done


    CURRENT_MONTH_UK=$(date "+%B")
    #    CURRENT_MONTH_UK="Oktober"
    CURRENT_MONTH=$CURRENT_MONTH_UK
    case $CURRENT_MONTH_UK in
	"October")
	    CURRENT_MONTH="Oktober"
	    ;;
	"January")
	    CURRENT_MONTH="Januari"
	    ;;
	"February")
	    CURRENT_MONTH="Februari"
	    ;;
	"March")
	    CURRENT_MONTH="Mars"
	    ;;
    esac
}


clean_up()
{
    rm -fr   ${MYTMPDIR}
}


set_up()
{
    
    for i in $SERIES
    do

	if [ "$(uname -n)" = "schnittke2" ] || [ "$DEBUG" = "true" ] || [ "$LOCAL" = "true" ]
	then
	    # local if host 
	    #	    echo LOCAL
	    cp  ../../elitserie-backup/$i.txt .
	else
	    #	    echo URL
	    fetch_url $i
	fi

	if [ $? -ne 0 ]
	then
	    exit 0
	fi
	
	diff $i.txt ../../$i.txt >/dev/null 2>/dev/null
	RET=$?
	#    if [ $RET -ne 0 ]
	#	then
	#	echo "Lag: $i $(date)" >> ../../nytt-schema.txt
	#    fi
	cp $i.txt ../../
	
    done

}


fetch_url()
{
    URL=${!1}

    #   echo " -- $1 -- \"$URL\""
    
    if [ "$URL" = "" ]
    then
	exit 1
    fi
    


    #    echo " -- FETCH \"$URL\"  in $(pwd)"

    if [ -f $1.txt ]
    then
	log "Backup $i"
	mv $1.txt $1.txt.save
    fi
    
    
    URL_BASED=true
    curl "$URL" -o $1.txt 2>/dev/null

    
    return 0
}


get_games()
{

    if [ "$DEBUG" = "true" ]
    then
	return
    fi

    SERIE=$1
    URL=${!1}
    log "GET GAMES for $SERIE"

    if [ -f $BASE_DIR/$URL ]
    then
	URL_BASED=false
    else
	URL_BASED=true
    fi

    if [  "$URL_BASED" = "true" ] 
    then
	#    echo "get_games($i)"
	
	dos2unix $SERIE.txt >/dev/null  2>/dev/null
	
	cp $SERIE.txt $SERIE.html
	w3m -dump -cols 500  $SERIE.html > $SERIE.tmp1
	#html2text -width 200 $SERIE.txt > $SERIE.tmp1
	
	cat $SERIE.tmp1 | awk 'BEGIN { found=0; }  /^Omgång/ { found=1;} /Nyheter/ { found=0;} { if ( found==1) { print $0} } ' > $SERIE.tmp
	
	COL=$(cat $SERIE.tmp1 | grep "Tid"  | grep Matchnummer | grep Match | grep Resultat | grep -b -o Resultat | awk ' BEGIN{FS=":"}{ print $1}')
	COL_START=29
	COL_STOP=$(($COL - $COL_START))

	#	echo "COL: $COL  $COL_START  $COL_STOP"
	#	exit
	#	echo "Working with:  $(pwd)/$SERIE.tmp"
	cat $SERIE.tmp | grep -v Omgång | while (true)
	do
	    oldline=$line
	    read line
	    RESULT=""
	    if [ "$line" = "" ]; then break ; fi
	    #	    echo
	    #	    echo
	    #	    echo "LINE: $line"
	    if [[ "$line" =~ ^[a-zA-Z].* ]];
	    then
		#		echo "NEW DATE FOUND...:  $line"
		# New date
		DAY=$(echo ${line:0:2} | sed 's,[ ]*$,,g')
		DATETIME=$(echo ${line:3:10} | sed 's,[ ]*$,,g' | awk ' {printf "%s %s\n",  $1 , $2 }')
		DATE=$(echo "$DATETIME" |  cut -d' ' -f 1 )
		TIME=$(echo "$DATETIME" |  cut -d' ' -f 2 )
		#		echo "DATE: '$DATE' , '$TIME' <--- '$DATETIME' <-------------------- '$line'"
		RESULT=$(echo ${line:$COL} |  sed 's,\[pdf\],,g' | sed 's,[ ]*$,,g'  )
		
		#		echo "RESULT: $RESULT"
		#		echo
		URL_TMP=$(echo ${line:16:12} | awk '{ print $1}' | sed -e 's,[ ]*$,,g' -e 's,^[ ]*,,g')
		#		echo "URL: $URL_TMP   http://www.svenskhandboll.se/Handbollinfo/Tavling/SerierResultat/?m=${URL_TMP}&s=2014   <---- $line"
		#   echo "time1: $DATE   '$line'"
		PLAYING_TEAMS=$(echo ${line:$COL_START:$COL_STOP} | sed 's,[ ]*$,,g')
		#	    FIELD=$(echo ${line:73:20} | sed 's,[ \t\r]*$,,g')
		NEW_DAY=$(echo $DATE | sed 's,\([0-9]*\)/[0-9]*,\1,g')
		NEW_MONTH=$(echo $DATE | sed 's,[0-9]*/\([0-9]*\),\1,g')
	    else
		#		echo "FOUND, keeping date: $DATE"
		TIME=$(echo ${line:0:5} | sed 's,[ ]*$,,g')
		URL_TMP=$(echo ${line:16:12} | awk '{ print $1}' | sed -e 's,[ ]*$,,g' -e 's,^[ ]*,,g')
		#	    echo "time2: $DATE   '$line'"
		PLAYING_TEAMS=$(echo ${line:$COL_START:$COL_STOP} | sed 's,[ ]*$,,g')
		RESULT=$(echo ${line:$COL} |  sed 's,\[pdf\],,g' | sed 's,[ ]*$,,g'  )
	    fi
	    
	    HOMET=$(echo "$PLAYING_TEAMS" |  cut -d'-' -f 1 | sed -e 's,[ ]*$,,g' -e 's,^[ ]*,,g')
	    AWAY=$(echo "$PLAYING_TEAMS" |  cut -d'-' -f 2 | sed -e 's,[ ]*$,,g' -e 's,^[ ]*,,g' -e 's,[\t][ ]*[0-9][0-9 ]*,,g')

	    #	    echo "SPLIT: '$DAY'  '$DATE'  '$TIME' id:'$URL_TMP'  teams:'$PLAYING_TEAMS' => '$HOMET' '$AWAY' "

	    
	    #	    SIZE=${#HOMET}
	    #	    SIZE=$(( $SIZE + 2 ))
	    #	echo "SIZE: $SIZE"
	    #           echo "DEBUG0: '$PLAYING_TEAMS'   $SIZE"
	    #          AWAY1=${PLAYING_TEAMS:$SIZE:100}
	    #         echo "DEBUG1: '$AWAY1'"
	    #        AWAY2=(${AWAY1//-/ })
	    #       echo "DEBUG2: '$AWAY2'"
	    #      AWAY=$(echo ${AWAY2} | sed 's,_, ,g' | sed -e 's,[ ]*$,,g'  -e 's,^[ ]*,,g')
	    #     echo "DEBUG3: '$AWAY'"
	    #    echo "                          '$AWAY'"
	    
	    
	    if [ "$NEW_DAY" = "" ]
	    then
		log "DAY ERROR, DATE: $DATE"
		log "  line: $line"
		log "  line: $oldline"
	    fi
	    
	    if [ "$NEW_MONTH" = "" ]
	    then
		log "MONTH ERROR, DATE: $DATE"
		log "  line: $line"
		log "  line: $oldline"
	    fi
	    
	    
	    YEAR=$YEAR1_NR
	    if [ $NEW_MONTH -lt 09 ]
	    then
		YEAR=$YEAR2_NR
	    fi
	    
	    LOCATION="--"
	    SAVE=true
	    
	    if [ "$SAVE" = "true" ]
	    then
		if [ "$URL_TMP" != "" ]
		then
		    URL="http://www.svenskhandboll.se/Handbollinfo/Tavling/SerierResultat/?m=${URL_TMP}&s=2014"
		    #		    echo "URL_CHECK:  $HOMET - $AWAY [$URL]"
		    #		    curl "$URL" -o game-tmp.html 2>/dev/null
		    #		    html2text  -o game-tmp.txt game-tmp.html
		    #		    if [ "$LOCATION" != "--" ]
		    #		    then
		    #			echo -n "LOCATION: $LOCATION => "
		    #		    fi			
		    #		    LOCATION=$(grep "Arena:" game-tmp.txt | awk ' { print $2}' | sed -e 's,^[ ]*,,g' -e 's,[ ]*$,,g')
		    #		    echo "LOCATION: $LOCATION"

		    LOCATION="--"
		    #		    rm game-tmp.*
		else
		    URL="--"
		fi

		NEW_DATE=$(date -d "$NEW_MONTH/$NEW_DAY/$YEAR" '+%y-%m-%d' )
		log	"insert_game '$NEW_DATE'   '$TIME' '$LOCATION' '$SERIE' '$HOMET'  '$AWAY' '$URL_TMP' '$URL' '$RESULT'"
		insert_game "$NEW_DATE"   "$TIME" "$LOCATION" "$SERIE" "$HOMET"  "$AWAY" "$URL_TMP" "$URL" "$RESULT"
	    else
		log "NOT_INSERT:" "$NEW_DATE"   "$TIME" "$LOCATION" "$SERIE" "'$HOMET'"  "'$AWAY'" 
		# >> /tmp/not-insert.log
	    fi
	    
	done
    fi

}






########


get_data() 
{
    SAVE_DIR=$(pwd)

    init
    clean_up
    cd         ${RUN_DIR}
    set_up

    for i in $SERIES
    do
	get_games $i
    done

    cd $SAVE_DIR
}

cleanup_sv()
{
    FILE_TO_CLEAN=$1

    #    echo "  ---> cleaning up $1"

    #    dos2unix $FILE_TO_CLEAN

    #   echo "  ---  cleaning up $1"

    #export LC_COLLATE="sv_SE.UTF-8"
    mv  $FILE_TO_CLEAN ${FILE_TO_CLEAN}.tmp
    cat $FILE_TO_CLEAN.tmp | \
	sed -e "s,ö,\&ouml;,g" \
	-e "s,Ö,\&Ouml;,g" \
	-e "s,Ä,\&Auml;,g" \
	-e "s,ä,\&auml;,g" \
	-e "s,Å,\&Aring;,g" \
	-e "s,å,\&aring;,g" \
	-e "s,Ã€,\&auml;,g" \
	| LC_ALL="POSIX" 	 sed  -e  "s/[\d128-\d255]//g" \
	> ${FILE_TO_CLEAN} 
    #   echo "   --- cleaning up $1"

    #  echo "  <--- cleaning up $1"


}




generate_single() 
{
    SERIE="$1"
    SINGLE_TEAM="$2"

    SAVE_DIR=$(pwd)
    cd         ${RUN_DIR}
#    cd  ${MYTMPDIR}


    echo "BEGIN:VCALENDAR"
    echo "VERSION:2.0"
    echo "METHOD:PUBLISH"
    echo "CALSCALE:GREGORIAN"
    echo "PRODID:-//Sandklef-GNU-Labs v1.0//EN"


    if [ "$SINGLE_TEAM" = "" ]
    then
	SELECT_STMT="SELECT date, time, serie, home, away, matchid, url, location, result, updatedate, updatetime FROM matcher WHERE serie='$SERIE' ORDER BY DATE;"
    else
	SELECT_STMT="SELECT date, time, serie, home, away, matchid, url, location, result, updatedate, updatetime FROM matcher WHERE serie='$SERIE' AND (home='$SINGLE_TEAM' OR away='$SINGLE_TEAM' ) ORDER BY DATE;"
    fi


    db_command $SELECT_STMT  | while (true)
    do
	read LINE
	if [ "$LINE" = "" ] ; then break; fi
	LAST_DATE=$DATE
	DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $1 ;}' )
	TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $2 ;}' )
	SERIE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $3 ;}' )
	HOME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $4 ;}' )
	AWAY=$(echo $LINE | awk ' BEGIN {FS="|"} { print $5 ;}' )
	MATCHID=$(echo $LINE | awk ' BEGIN {FS="|"} { print $6 ;}' )
	URL=$(echo $LINE | awk ' BEGIN {FS="|"} { print $7 ;}' )
	LOCATION=$(echo $LINE | awk ' BEGIN {FS="|"} { print $8 ;}' )
	RESULT=$(echo $LINE | awk ' BEGIN {FS="|"} { print $9 ;}' )
	UPDATE_DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $10 ;}' )
	UPDATE_TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $11 ;}' )
	


#	echo "DATE:  $DATE $TIME '$UPDATE_DATE' '$UPDATE_TIME'  <----- $LINE"
	UTC_DATE_START=$(date -u --date "CEST $DATE $TIME"  '+%Y%m%d' )
	UTC_TIME_START=$(date -u --date "CEST $DATE $TIME" '+%H%M%S' )

	secs=$(date '+%s' -u --date="CEST $DATE $TIME")
	UTC_DATE_STOP=$(date -u  --date="@$((secs + 7200))" '+%Y%m%d')
	UTC_TIME_STOP=$(date -u  --date="@$((secs + 7200))" '+%H%M%S')


	#
	# NOW dates
	#
	UTC_DATE_NOW=$(TZ=UTC date  '+%Y%m%d')
	UTC_TIME_NOW=$(TZ=UTC date  '+%H%M%S')


	#	echo "NOW: date  $(date '+%H%M%S') => $UTC_TIME_NOW"
	#	echo "     $DATE $TIME"
	#	echo " => ${UTC_DATE_START} || ${UTC_TIME_START}"
	#	echo " => ${UTC_DATE_STOP} || ${UTC_TIME_STOP}"


	URL_LINK=""
	if [ "$URL" != "--" ]
	then
	    URL_LINK="(<a href=\"$URL\">more info</a>)"
	fi

	LOCATION_LINK=""
	if [ "$LOCATION" != "--" ]
	then
	    LOCATION_LINK="($LOCATION)"
	fi

	#	echo "$DATE $TIME ($UTC_DATE) , $SERIE, $HOME - $AWAY $LOCATION_LINK $URL_LINK" 

	echo "BEGIN:VEVENT"
	echo "DTSTART:${UTC_DATE_START}T${UTC_TIME_START}Z"
	echo "DTEND:${UTC_DATE_STOP}T${UTC_TIME_STOP}Z"
	echo "UID:Elitserie-$MATCHID@sandklef.com"
#	echo "DTSTAMP:${UTC_DATE_NOW}T${UTC_TIME_NOW}Z"
	echo "DTSTAMP:${UPDATE_DATE}T${UPDATE_TIME}Z"
	#echo "LAST-MODIFIED:${UTC_DATE_NOW}T${UTC_TIME_NOW}Z"
	echo "LAST-MODIFIED:${UPDATE_DATE}T${UPDATE_TIME}Z"

	#	echo "ORGANIZER;CN=SEH, www.svenskhandboll.se"
	if [ "$RESULT" = "" ] || [ "$RESULT" = " " ]  || [ "$RESULT" = "-" ] 
	then
	    RES_STRING=""
	else
	    RES_STRING="($RESULT)"
	fi
	#echo "RESULT: '$RESULT'   => $RES_STRING"
	echo "SUMMARY;ENCODING=QUOTED-PRINTABLE: $HOME - $AWAY $RES_STRING ($SERIE)"
	echo "DESCRIPTION;ENCODING=QUOTED-PRINTABLE:$SERIE: $HOME - $AWAY, $LOCATION / $URL_LINK"
	echo "END:VEVENT"

    done

    echo "END:VCALENDAR"

    cd $SAVE_DIR
}


find_clubs() 
{
    SERIE=$1
    SELECT_STMT="SELECT DISTINCT home FROM matcher where serie='$SERIE' ;" 
    CLUB_STR=$(db_command $SELECT_STMT | sed 's,[ \t],##,g')
    #    echo "CS: $CLUB_STR -<<   $SELECT_STMT"
}

check_db()
{
    RET=0
    for i in $SERIES
    do
	log "SERIE: $i"
	find_clubs $i
	for club in $CLUB_STR 
	do
	    CLUB=$(echo $club | sed 's,##, ,g')
	    # DEBUG
	    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE serie='$SERIE' AND (home='$CLUB' OR away='$CLUB') ORDER BY DATE;"
	    COUNT=$(db_command $SELECT_STMT)
	    ICS_COUNT=$(grep "$CLUB" "$i.ics"  | grep SUMMARY | wc -l)
            log "    CLUB: $CLUB ($COUNT/$ICS_COUNT)"

	    if [ "$i" = "Elitserien_Herrar" ] 
	    then
		if [ $COUNT -ne 32 ] || [ $ICS_COUNT -ne 32 ] 
		then
		    log "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    elif [ "$i" = "Elitserien_Damer" ] 
	    then
		if [ $COUNT -ne 22 ] || [ $ICS_COUNT -ne 22 ] 
		then
		    log "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    elif [ "$i" = "Damallsvenskan" ] 
	    then
		if [ $COUNT -ne 20 ] || [ $ICS_COUNT -ne 20 ] 
		then
		    log "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    elif [ "$i" = "Herrallsvenskan" ] 
	    then
		if [ $COUNT -ne 26 ] || [ $ICS_COUNT -ne 26 ] 
		then
		    log "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    fi

	done
    done
    exit $RET
}

generate() 
{

    for i in $SERIES
    do
	log "SERIE: $i"
	generate_single $i > $i.ics
	unix2dos $i.ics 2> /dev/null > /dev/null
	find_clubs $i
	for club in $CLUB_STR 
	do
	    CLUB=$(echo $club | sed 's,##, ,g')
	    # DEBUG
	    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE serie='$SERIE' AND (home='$CLUB' OR away='$CLUB') ORDER BY DATE;"
	    COUNT=$(db_command $SELECT_STMT)
            log "    CLUB: $CLUB ($COUNT)"

	    FILE_NAME=$(echo "$i-$CLUB.ics" | sed 's,[ \t],-,g')
            generate_single $i "$CLUB" > $FILE_NAME
	    unix2dos $FILE_NAME  2> /dev/null > /dev/null
	done
    done
}

report_error()
{
    echo "ERROR: $*"
}

separate_runs()
{
    if [ ! -d $INSTALL_DIR ]
    then
	mkdir -p $INSTALL_DIR    
    fi

    for i in $SERIES
    do
	SERIE_INSTALL_DIR=$INSTALL_DIR/$i/
	if [ ! -d $SERIE_INSTALL_DIR ]
	then
	    mkdir -p $SERIE_INSTALL_DIR/
	fi
	
	rm -f $i.ics $i-*.ics
	$0 --series $i --get-data >> /tmp/elit.txt
	$0 --series $i --generate >> /tmp/elit.txt
	$0 --series $i --check-db >> /tmp/elit.txt
	RET=$?
	log "Serie $i finished: $RET"
	if [ "$RET" = "0" ]
	then
	    cp $i*.ics  $SERIE_INSTALL_DIR/
	else
	    report_error "Failed generating calendar for $SERIE"
	    report_error "----------------------------------------"
	    report_error "  DATE: $(date) on $(uname -n)"
	    report_error "$($0 --series $i --check-db)"
	fi
    done
}

if [ "$MODE" = "all" ]
then
    #    echo "DO ALL"
    get_data
    generate
elif  [ "$MODE" = "get" ] 
then
    #    echo "GET DATA"
    get_data
elif  [ "$MODE" = "clean" ] 
then
    #    echo "GET DATA"
    clean_db
elif  [ "$MODE" = "check" ] 
then
    #    echo "GET DATA"
    check_db
elif  [ "$MODE" = "separate" ] 
then
    #    echo "SEPARATE"
    separate_runs
else
    #echo "GENERATE"
    generate
fi

