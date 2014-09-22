#!/bin/bash


#
# If you've ever seen a really (I mean really) dirty hack 
#   - this script will beat it 
#

Damer="http://www.svenskhandboll.se/Handbollinfo/Tavling/SerierResultat/?t=1400201&s=2014"
Herrar="http://www.svenskhandboll.se/Handbollinfo/Tavling/SerierResultat/?t=1400101&s=2014"
TEAMS=" Damer Herrar"

LOCAL=false

TEAMS_CONF=$(dirname $0)/teams.conf

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
    elif [ "$1" = "--teams" ]
    then
	TEAMS="$2"
	shift
    elif [ "$1" = "--check-db" ]
    then
	MODE="check"
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

#TEAMS="F01 P04 " 
declare -a MONTHS
declare -a MONTHS_NR
declare -a MONTHS_REGEXP


YEAR1_NR=14
YEAR2_NR=15
LONG_YEAR1_NR=2014
LONG_YEAR2_NR=2015

BACKUP_DIR=$(pwd)/results/$(date +%Y-%m-%d)

MYTMPDIR=tmp/elitserien
HTML_PAGE=$(pwd)/index.html


SQLITE=sqlite3
DB_DIR=$(pwd)

db_command() {
    if [ "$DEBUG" = "true" ]
    then
	echo "db_command:   $*  [${DB_DIR}/IKNORD.sqlite]" ;
    fi
    echo "$*" | $SQLITE ${DB_DIR}/ELITSERIEN.sqlite
}

clean_db() 
{
    if [ "$DEBUG" = "true" ]
    then
	echo not cleaning db
    else
	mkdir -p db-backup
	mv ELITSERIEN.sqlite db-backup/ELITSERIEN-$(date '+%y-%m-%d').sqlite
	DB_CREATE="CREATE TABLE matcher (date DATE NOT NULL, time TIME NOT NULL, updatedate DATE NOT NULL, updatetime TIME NOT NULL, location varchar(50) NOT NULL, team varchar(50) NOT NULL, home varchar(50) NOT NULL, away varchar(50) NOT NULL, matchid varchar(100) NOT NULL, url varchar(200), result varchar(200), PRIMARY KEY (matchid));"
	
	db_command "$DB_CREATE"
    fi
}

insert_game() 
{
    MATCH_ID="$7"

    printf "Match id: %10s" $MATCH_ID
   
 #   echo "MATCH_ID=$MATCH_ID"
    
    NEW_DATE="$1"
    NEW_TIME="$2"
    NEW_LOCATION="$3"
    NEW_TEAM="$4"
    NEW_HOME="$5"
    NEW_AWAY="$6"
    NEW_ID="$7"
    NEW_URL="$8"
    NEW_RESULT="$9"

    UTC_DATE_NOW=$(TZ=UTC date  '+%Y-%m-%d')
    UTC_TIME_NOW=$(TZ=UTC date  '+%H:%M:%S')
    

    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE matchid='$MATCH_ID';"

    COUNT=$(db_command $SELECT_STMT)
    echo "------------ $5 $6 : COUNT: $COUNT"

    if [ $COUNT -gt 1 ] 
    then
	echo "Shit..... $SELECT_STMT returned $COUNT occ"
	sleep 2
	exit 0
    elif [ $COUNT -ne 0 ] 
    then
	SELECT_STMT="SELECT date, time, team, home, away, matchid, url, location, result FROM matcher WHERE matchid='$MATCH_ID' ;"
	
	LINE=$(db_command $SELECT_STMT)

#	echo "------------>"
#	echo  " $LINE  "
	COUNT=$(( $COUNT + 1 ))
	if [ "$LINE" = "" ] ; then break; fi
	LAST_DATE=$DATE
	DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $1 ;}' )
	TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $2 ;}' )
	TEAM=$(echo $LINE | awk ' BEGIN {FS="|"} { print $3 ;}' )
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
	    echo "DIFF"
	    echo "RESULT: '$RESULT'   '$NEW_RESULT'"
	    echo "--------------------------"
	    echo "'$NEW_DATE' '$NEW_TIME' '$NEW_LOCATION' '$NEW_HOME' '$NEW_AWAY'"  
	    echo "'$DATE' '$TIME' '$LOCATION' '$HOME' '$AWAY'" 
	    echo "update"
####	    db_command "SELECT updatedate, updatetime, home, away  FROM matcher WHERE matchid='$MATCH_ID';"
#	    echo "NOW: '$UTC_DATE_NOW', '$UTC_TIME_NOW"

#	    sleep 5

	    UPDATE_GAME="UPDATE matcher SET date='$NEW_DATE', time='$NEW_TIME', updatedate='$UTC_DATE_NOW', updatetime='$UTC_TIME_NOW' , result='$NEW_RESULT' WHERE matchid='$MATCH_ID' ;"

	    db_command "$UPDATE_GAME"	

#	    db_command "SELECT updatedate, updatetime, home, away  FROM matcher WHERE matchid='$MATCH_ID';"

#	    exit

	else
#	echo "=============================================================== $5 vs. $6 NO DIFF"
	    echo "NO DIFF... $AWAY $HOME"
	fi

    else
#	echo "=============================================================== $5 vs. $6 AS Roma"

	DB_GAME="INSERT INTO matcher VALUES ('$1','$2', '$UTC_DATE_NOW', '$UTC_TIME_NOW', '$3','$4','$5','$6', '$7', '$8' , '$9' );"
	echo "$DB_GAME"
	db_command "$DB_GAME"
    fi

#	echo "=============================================================== $5 vs. $6 LIVERPOOOLLLL"

    TMP=0
    while [ $TMP -lt 20 ]
    do
	printf "\b"
	TMP=$(( $TMP + 1 ))
    done

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
    
    for i in $TEAMS
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

    echo " -- $1 -- \"$URL\""
    
    if [ "$URL" = "" ]
    then
	exit 1
    fi
    


    echo " -- FETCH \"$URL\"  in $(pwd)"

    if [ -f $1.txt ]
    then
	echo "Backup $i"
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

    TEAM=$1
    URL=${!1}
    echo "GET GAMES for $TEAM"

    if [ -f $BASE_DIR/$URL ]
    then
	URL_BASED=false
    else
	URL_BASED=true
    fi

    if [  "$URL_BASED" = "true" ] 
    then
	#    echo "get_games($i)"
	
	dos2unix $TEAM.txt >/dev/null  2>/dev/null
	
	cp $TEAM.txt $TEAM.html
	w3m -dump -cols 500  $TEAM.html > $TEAM.tmp1
#html2text -width 200 $TEAM.txt > $TEAM.tmp1
	
	cat $TEAM.tmp1 | awk 'BEGIN { found=0; }  /^Omgång/ { found=1;} /Nyheter/ { found=0;} { if ( found==1) { print $0} } ' > $TEAM.tmp
	
	COL=$(cat $TEAM.tmp1 | grep "Tid"  | grep Matchnummer | grep Match | grep Resultat | grep -b -o Resultat | awk ' BEGIN{FS=":"}{ print $1}')
	COL_START=29
	COL_STOP=$(($COL - $COL_START))

#	echo "COL: $COL  $COL_START  $COL_STOP"
#	exit
	
	cat $TEAM.tmp | grep -v Omgång | while (true)
	do
	    oldline=$line
	    read line
	    RESULT=""
	    #	    echo "line: ($team) => $line"
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
		echo "DAY ERROR, DATE: $DATE"
		echo "  line: $line"
		echo "  line: $oldline"
	    fi
	    
	    if [ "$NEW_MONTH" = "" ]
	    then
		echo "MONTH ERROR, DATE: $DATE"
		echo "  line: $line"
		echo "  line: $oldline"
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
#		echo insert_game "$NEW_DATE"   "$TIME" "$LOCATION" "$TEAM" "$HOMET"  "$AWAY" "$URL_TMP" "$URL"
#		echo "DEBUG '$DATE' '$HOMET' '$AWAY' " 
#		echo insert_game "'$NEW_DATE'   '$TIME' '$LOCATION' '$TEAM' '$HOMET'  '$AWAY' '$URL_TMP' 'URL'"
#		echo insert_game "'$URL_TMP'    '$NEW_DATE'   '$TIME' '$LOCATION' '$TEAM' '$HOMET'  '$AWAY' "
		insert_game "$NEW_DATE"   "$TIME" "$LOCATION" "$TEAM" "$HOMET"  "$AWAY" "$URL_TMP" "$URL" "$RESULT"
	    else
		echo "NOT_INSERT:" "$NEW_DATE"   "$TIME" "$LOCATION" "$TEAM" "'$HOMET'"  "'$AWAY'" 
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
    mkdir -p   ${MYTMPDIR}
    cd         ${MYTMPDIR}
    set_up

    for i in $TEAMS
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
    TEAM="$1"
    SINGLE_TEAM="$2"

    SAVE_DIR=$(pwd)
    cd  ${MYTMPDIR}


    echo "BEGIN:VCALENDAR"
    echo "VERSION:2.0"
    echo "METHOD:PUBLISH"
    echo "CALSCALE:GREGORIAN"
    echo "PRODID:-//Sandklef-GNU-Labs v1.0//EN"


    if [ "$SINGLE_TEAM" = "" ]
    then
	SELECT_STMT="SELECT date, time, team, home, away, matchid, url, location, result FROM matcher WHERE team='$TEAM' ORDER BY DATE;"
    else
	SELECT_STMT="SELECT date, time, team, home, away, matchid, url, location, result FROM matcher WHERE team='$TEAM' AND (home='$SINGLE_TEAM' OR away='$SINGLE_TEAM' ) ORDER BY DATE;"
    fi


    db_command $SELECT_STMT  | while (true)
    do
	read LINE
	if [ "$LINE" = "" ] ; then break; fi
	LAST_DATE=$DATE
	DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $1 ;}' )
	TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $2 ;}' )
	TEAM=$(echo $LINE | awk ' BEGIN {FS="|"} { print $3 ;}' )
	HOME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $4 ;}' )
	AWAY=$(echo $LINE | awk ' BEGIN {FS="|"} { print $5 ;}' )
	MATCHID=$(echo $LINE | awk ' BEGIN {FS="|"} { print $6 ;}' )
	URL=$(echo $LINE | awk ' BEGIN {FS="|"} { print $7 ;}' )
	LOCATION=$(echo $LINE | awk ' BEGIN {FS="|"} { print $8 ;}' )
	RESULT=$(echo $LINE | awk ' BEGIN {FS="|"} { print $9 ;}' )

#echo "DATE:  $DATE $TIME  <----- $LINE"
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

#	echo "$DATE $TIME ($UTC_DATE) , $TEAM, $HOME - $AWAY $LOCATION_LINK $URL_LINK" 

	echo "BEGIN:VEVENT"
	echo "DTSTART:${UTC_DATE_START}T${UTC_TIME_START}Z"
	echo "DTEND:${UTC_DATE_STOP}T${UTC_TIME_STOP}Z"
	echo "UID:Elitserie-$MATCHID@sandklef.com"
	echo "DTSTAMP:${UTC_DATE_NOW}T${UTC_TIME_NOW}Z"
	echo "LAST-MODIFIED:${UTC_DATE_NOW}T${UTC_TIME_NOW}Z"
#	echo "ORGANIZER;CN=SEH, www.svenskhandboll.se"
	if [ "$RESULT" = "" ] || [ "$RESULT" = " " ] 
	then
	    RES_STRING=""
	else
	    RES_STRING="($RESULT)"
	fi
#echo "RESULT: '$RESULT'   => $RES_STRING"
	echo "SUMMARY;ENCODING=QUOTED-PRINTABLE: $HOME - $AWAY $RES_STRING ($TEAM)"
	echo "DESCRIPTION;ENCODING=QUOTED-PRINTABLE:Elitserien $TEAM: $HOME - $AWAY, $LOCATION / $URL_LINK"
	echo "END:VEVENT"

    done

    echo "END:VCALENDAR"

    cd $SAVE_DIR
}


find_clubs() 
{
    TEAM=$1
    SELECT_STMT="SELECT DISTINCT home FROM matcher where team='$TEAM' ;" 
    CLUB_STR=$(db_command $SELECT_STMT | sed 's,[ \t],##,g')
#    echo "CS: $CLUB_STR -<<   $SELECT_STMT"
}

check_db()
{
    RET=0
    for i in $TEAMS
    do
	echo "TEAM: $i"
	find_clubs $i
	for club in $CLUB_STR 
	do
	    CLUB=$(echo $club | sed 's,##, ,g')
	    # DEBUG
	    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE team='$TEAM' AND (home='$CLUB' OR away='$CLUB') ORDER BY DATE;"
	    COUNT=$(db_command $SELECT_STMT)
	    ICS_COUNT=$(grep "$CLUB" "$i.ics"  | grep SUMMARY | wc -l)
            echo "    CLUB: $CLUB ($COUNT/$ICS_COUNT)"

	    if [ "$i" = "Herrar" ] 
		then
		if [ $COUNT -ne 32 ] || [ $ICS_COUNT -ne 32 ] 
		    then
		    echo "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    elif [ "$i" = "Damer" ] 
	    then
		if [ $COUNT -ne 22 ] || [ $ICS_COUNT -ne 22 ] 
		    then
		    echo "ERROR: wrong number of matches ($COUNT) for $i"
		    RET=1
		fi
	    fi

	done
    done
    exit $RET
}

generate() 
{

    for i in $TEAMS
    do
	echo "TEAM: $i"
	generate_single $i > $i.ics
	unix2dos $i.ics
	find_clubs $i
	for club in $CLUB_STR 
	do
	    CLUB=$(echo $club | sed 's,##, ,g')
	    # DEBUG
	    SELECT_STMT="SELECT COUNT (*) FROM matcher WHERE team='$TEAM' AND (home='$CLUB' OR away='$CLUB') ORDER BY DATE;"
	    COUNT=$(db_command $SELECT_STMT)
            echo "    CLUB: $CLUB ($COUNT)"

	    FILE_NAME=$(echo "$i-$CLUB.ics" | sed 's,[ \t],-,g')
            generate_single $i "$CLUB" > $FILE_NAME
	    unix2dos $FILE_NAME
	done
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
else
#    echo "GENERATE"
    generate
fi


