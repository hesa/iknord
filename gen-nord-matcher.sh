#!/bin/bash


TEAMS_CONF=$(dirname $0)/teams.conf
LOGO=$(dirname $0)/ik-nord.png
if [ -f $TEAMS_CONF ] 
then
    . $TEAMS_CONF 
else
    echo $TEAMS_CONF not found
    exit 1
fi

if [ "$1" = "--debug" ]
then
    DEBUG=true
    shift
fi

FAKE_DATA_DIR=~/opt/iknord/nord-data-backup

#TEAMS="F01 P04 " 
declare -a MONTHS
declare -a MONTHS_NR
declare -a MONTHS_REGEXP


YEAR1_NR=14
YEAR2_NR=15
LONG_YEAR1_NR=2014
LONG_YEAR2_NR=2015

BACKUP_DIR=$(pwd)/results/$(date +%Y-%m-%d)

MYTMPDIR=tmp/match
HTML_PAGE=$(pwd)/index.html

fix_logo() 
{
    if [ -f $LOGO ] 
    then
	cp $LOGO ${MYTMPDIR}
	cp $LOGO ${MYTMPDIR}/../
	cp $LOGO ${MYTMPDIR}/../../
    else
	echo $LOGO not found
	exit 1
    fi
}

SQLITE=sqlite3
DB_DIR=$(pwd)

db_command() {
#    echo "db_command:   $*  [${DB_DIR}/IKNORD.sqlite]" ;
    echo "$*" | $SQLITE ${DB_DIR}/IKNORD.sqlite
}

clean_db() 
{
    if [ "$DEBUG" = "true" ]
    then
	echo not cleaning db
    else
	mkdir -p db-backup
	mv IKNORD.sqlite db-backup/IKNORD-$(date '+%y-%m-%d').sqlite
	DB_CREATE="CREATE TABLE matcher (date DATE, time TIME, team varchar(50), home varchar(50), away varchar(50));"
	
	db_command "$DB_CREATE"
    fi
}

insert_game() 
{
    DB_GAME="INSERT INTO matcher VALUES ('$1','$2','$3','$4','$5');"

    db_command "$DB_GAME"
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


#    CURRENT_MONTH_UK=$(date "+%B")
    CURRENT_MONTH_UK="Oktober"
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

	if [ "$(uname -n)" = "schnittke" ] || [ "$DEBUG" = "true" ]
	    then
	    # local if host 
	    fetch_file $i
	else
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

fetch_file() 
{
    TEAM=$1
    
    MATCH_DIR=$FAKE_DATA_DIR/${MYTMPDIR}

    if [ ! -d $MATCH_DIR ]
    then
	echo "No dir ($MATCH_DIR)/tmp/match with fake data"
	exit 1
    fi

#    if [ -f ${MATCH_DIR}/$1.txt ]
#    then
#	echo "FILE EXISTS :)   ${MATCH_DIR}/$1.txt"
#    else
#	echo "NO :()   ${MATCH_DIR}/$1.txt"
#    fi

    cp ${MATCH_DIR}/$1.txt .

    if [ ! -d $BACKUP_DIR ]
    then
	mkdir -p $BACKUP_DIR
    fi
    cp $1.txt $BACKUP_DIR/$1.html

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
    
    curl "$URL" -o $1.txt

    if [ "$?" != "0" ]
    then
	if [ -f $1.txt.save ]
	then
	    echo "Dwnload failed, restoring $i"
	    mv $1.txt.save $1.txt
	else
	    echo "Dwnload failed, creating empty file $i"
	    touch $1.txt
	fi
	
    elif [ "$(grep -i -e nord -e ammandrag $1.txt | wc -l)" = "0" ]
    then
	if [ -f $1.txt.save ]
	then
	    echo "URL seems wrong ..... bailing out"
	    echo ".... first restoring $1.txt"
	    mv $1.txt.save $1.txt
	    sleep 10
	else
	    echo "URL seems wrong ..... bailing out"
	    echo ".... creating empty $1.txt"
	    touch $1.txt
	fi
    fi

    if [ ! -d $BACKUP_DIR ]
    then
	mkdir -p $BACKUP_DIR
    fi
    cp $1.txt $BACKUP_DIR/$1.html

    if [ $? -ne 0 ]
    then
	return 1
    fi
    
    return 0
}


get_cafe()
{
    TEAM=$1
    
    export CAFE_RESP="$TEAM"

    grep -i -e masthuggshallen $TEAM.txt | grep "[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | \
	sed -e 's,<[a-zA-Z0-9 ]*=[0-9a-zA-Z#]*>[ \t]*[0-9]*[ \t]*[0-9]*,,g' \
        -e "s,</font>,,g" \
        -e "s,^[ \t]*,,g" | \
        awk '{ printf "%s %s %s\n" , $1,  $2, ENVIRON["CAFE_RESP"] } ' >> cafe-$TEAM.tmp
}

create_cafe() 
{
    start_file cafe.tmp "Cafe-arrangemang" "$MYTEAMS" "2014-2015"
    rm cafe.tmp2
    for i in $(ls cafe-*.tmp)
    do
	cat $i >> cafe.tmp2
    done 
    sort -n cafe.tmp2 > cafe.tmp3


    idx=0
    while (true) 
    do
	MO="${MONTHS[$idx]}"
	if [ "$MO" = "" ]; then break ; fi
	
	echo "#$MO" >> cafe.tmp
	grep -i "${MONTHS_REGEXP[$idx]}" cafe.tmp3| awk '{ print $0 "\n"}'  >> cafe.tmp
	echo "" >> cafe.tmp
	idx=$(( $idx + 1 ))

    done

    end_file cafe.tmp

    CAFE_MD=cafe.md
    PDF_FILE=${CAFE_MD%.md}.pdf
    HTML_FILE=${CAFE_MD%.md}.html
    iconv -f ISO-8859-15  -t UTF-8 cafe.tmp > $CAFE_MD

    cleanup_sv $CAFE_MD
    GENS=""
    pandoc   $CAFE_MD -o $PDF_FILE
    if [ $? != 0 ] ; then echo "Failed generating PDF ($PDF_FILE)" ; else GENS="$GENS $PDF_FILE"; fi
    pandoc   $CAFE_MD -o $HTML_FILE
    if [ $? != 0 ] ; then echo "Failed generating HTML ($HTML_FILE)" ; else GENS="$GENS $HTML_FILE"; fi
    cleanup_sv $HTML_FILE
}

get_games()
{

    if [ "$DEBUG" = "true" ]
    then
	return
    fi

#    echo "get_games($i)"

    TEAM=$1

    dos2unix $TEAM.txt >/dev/null  2>/dev/null

    html2text -width 200 $TEAM.txt > $TEAM.tmp1

    cat $TEAM.tmp1 | awk 'BEGIN { found=0; }  /^Omgång/ { found=1;} /Nyheter/ { found=0;} { if ( found==1) { print $0} } ' > $TEAM.tmp

    cat $TEAM.tmp | grep -v Omgång | while (true); 
    do
	oldline=$line
	read line
#	echo "line: $line"
	if [ "$line" = "" ]; then break ; fi

	if [[ "$line" =~ ^[a-zA-Z].* ]];
	then
#	    echo "NEW DATE FOUND..."
	    # New date
	    DAY=$(echo ${line:0:2} | sed 's,[ ]*$,,g')
	    DATE=$(echo ${line:3:5} | sed 's,[ ]*$,,g' | awk ' {print $1}')
	    TIME=$(echo ${line:8:6} | sed 's,[ ]*$,,g')
	 #   echo "time1: $DATE   '$line'"
	    PLAYING_TEAMS=$(echo ${line:26:100} | sed 's,[ ]*$,,g')
#	    FIELD=$(echo ${line:73:20} | sed 's,[ \t\r]*$,,g')
	    NEW_DAY=$(echo $DATE | sed 's,\([0-9]*\)/[0-9]*,\1,g')
	    NEW_MONTH=$(echo $DATE | sed 's,[0-9]*/\([0-9]*\),\1,g')
	else
#	    echo "FOUND, keeping date: $DATE"
	    TIME=$(echo ${line:0:5} | sed 's,[ ]*$,,g')
#	    echo "time2: $DATE   '$line'"
	    PLAYING_TEAMS=$(echo ${line:26:100} | sed 's,[ ]*$,,g')
	fi
	
	HOME1=(${PLAYING_TEAMS//-/ })
	HOME=$(echo ${HOME1} | sed 's,_, ,g' | sed 's,[ ]*$,,g' )
	
	SIZE=${#HOME}
	SIZE=$(( $SIZE + 2 ))
#	echo "SIZE: $SIZE"
	AWAY1=${PLAYING_TEAMS:$SIZE:100}
	AWAY2=(${AWAY1//-/ })
	AWAY=$(echo ${AWAY2} | sed 's,_, ,g' | sed 's,[ ]*$,,g')
	

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

	NEW_DATE=$(date -d "$NEW_MONTH/$NEW_DAY/$YEAR" '+%y-%m-%d' )

#	echo "DATE: '$DATE' => $NEW_DAY $NEW_MONTH => $NEW_DATE"

#	echo ""
#	echo "line: $line"
#	echo "  day:   $DAY"
#	echo "  date:  $DATE"
#	echo "  time:  $TIME '$DATE'"
#	echo "  teams: $PLAYING_TEAMS"
#	echo "  home:  $HOME"
#	echo "  away:  $AWAY"
#	echo "  field: $FIELD"
#	echo "NEW_DATE: $NEW_DATE  $DATE $line"
#	echo "$NEW_DATE $TIME $TEAM $HOME - $AWAY ($FIELD)"
        insert_game "$NEW_DATE"   "$TIME" "$TEAM" "$HOME"  "$AWAY"
    done
#   >  $TEAM.tmp2

#exit
#    echo " ==== get_games $1 ==> $TEAM-tmp2 "
#    ls -al  $TEAM.tmp
#    ls -al  $TEAM.tmp2

}

get_games_old()
{

    echo "get_games($i)"

    TEAM=$1

    dos2unix $TEAM.txt >/dev/null  2>/dev/null
#    file $TEAM.txt
#    sleep 20
    grep -i -e nord -e sammandrag $TEAM.txt | grep "[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | \
	sed -e 's,<[a-zA-Z0-9 ]*=[0-9a-zA-Z#]*>[ \t]*[0-9]*[ \t]*[0-9]*,,g' -e "s,</font>,,g" -e "s,^[ \t]*,,g" > $TEAM.tmp

#    echo " ==== get_games $1 "

#    echo "in here..... $(pwd)"

    cat $TEAM.tmp | while (true); 
    do
	read line
	echo "line: $line"
	if [ "$line" = "" ]; then break ; fi
	DATE=$(echo ${line:0:9} | sed 's,[ ]*$,,g')
	TIME=$(echo ${line:11:5} | sed 's,[ ]*$,,g')
	HOME=$(echo ${line:18:20} | sed 's,[ ]*$,,g')
	AWAY=$(echo ${line:41:20}| sed 's,[ ]*$,,g')
	FIELD=$(echo ${line:73:20} | sed 's,[ \t\r]*$,,g')

#	echo "line: $line"
#	echo "  date:  $DATE"
#	echo "  time:  $TIME"
#	echo "  home:  $HOME"
#	echo "  away:  $AWAY"
#	echo "  field: $FIELD"
	echo "$DATE $TIME $TEAM $HOME - $AWAY ($FIELD)"
    done  >  $TEAM.tmp2

#    echo " ==== get_games $1 ==> $TEAM-tmp2 "
#    ls -al  $TEAM.tmp
#    ls -al  $TEAM.tmp2

}


month_parser()
{
    MONTH=$1
    MONTH_RE=$2
    FILE=$3
    OUT_FILE=$4 
    REG=$5
    MONTH_FILE=$6
    
    echo "#$MONTH"  >> $OUT_FILE
    echo "#$MONTH"  >> $MONTH_FILE

#    echo "FIND $REG in $FILE"
#    grep 04 $FILE

    grep "$MONTH_RE" $FILE | while (true); do
	read newline
	if [ "$newline" = "" ]; then break ; fi

	if [ "$REG" != "all" ]
	then
	    echo "-----------------------------------------------------"
	    echo "#LINE1: $newline  \"$REG\"  "
	    echo "#  re: $REG"
#	    LINE=$(echo "$newline" | grep "[I]*[K]*[ ]*Nord -" | grep -e asthugg -e alhalla -e iseberg)
	    LINE=$(echo "$newline" | grep "[I]*[K]*[ ]*Nord[ \t]*-")
	    echo "#LINE2: '$LINE'"
	    echo "-----------------------------------------------------"
	    if [ "$LINE" != "" ] ; then
		echo "# SAVE '$LINE'"
		echo "$LINE"  >> $OUT_FILE
		echo "$LINE"  >> $MONTH_FILE
	    fi
	else
	    echo "$newline" >> $OUT_FILE
	    echo "$newline" >> $MONTH_FILE
	fi
	echo "" >> $OUT_FILE
	echo "" >> $MONTH_FILE
    done

}


start_file()
{
    TMP_FILE=$1
    TITLE=$2
    MYTEAMS=$3
    PERIOD=$4

    echo "![](ik-nord.png)   www.iknord.nu" > $TMP_FILE
    echo  >> $TMP_FILE
#    echo >$TMP_FILE
    echo "# $TITLE $PERIOD" >> $TMP_FILE
    echo "# Lag: $MYTEAMS" >> $TMP_FILE
#    echo "#Period: $PERIOD" >> $TMP_FILE
    echo "" >> $TMP_FILE
} 



end_file()
{
    TMP_FILE=$1

    echo  >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "<br>" >> $TMP_FILE
    echo "<br>" >> $TMP_FILE
    echo "<br>" >> $TMP_FILE
    echo "<br>" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "### Om dokumentet" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "URL: http://schema.iknord.nu/" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "K&auml;lla : http://www3.proteamonline.se/" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "Genererades fr&aring;n k&auml;llan ovan:    $(date)" >> $TMP_FILE
#    echo  >> $TMP_FILE
#    echo "Giltighet:   nja, ingen alls. Se detta dokument som en fingervisning" >> $TMP_FILE
#    echo  >> $TMP_FILE
#    echo "Fr&aring;gor:   helst inte, mvh Henrik Sandklef" >> $TMP_FILE
#    echo  >> $TMP_FILE
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

#Ã



create_month_file()
{
    echo;
}

create_all()
{
    MD_FILE=$1
    MYTEAMS="$(echo $2 | sed 's,[ ]*$,,g')"
    HOME=$3
    MONTH_MD_BASE=$4
    MONTH_ARG=$5

#    echo "===>  MONTH_ARG:  $MONTH_ARG"

    if [ "$MONTH_ARG" = "all" ] 
    then
	DATE_STRING="  "
	MONTH_STRING=''
	PERIOD="$LONG_YEAR1_NR-$LONG_YEAR2_NR"

	if [ "$MYTEAMS" != "all" ]
	then
	    MD_FILE=${MONTH_MD_BASE}${MONTH_STRING}.md
	fi

    else
	DATE_STRING=" AND DATE LIKE '${MONTHS_REGEXP[$MONTH_ARG]}%' "
	MONTH_STRING="${MONTHS[$MONTH_ARG]}"
	MD_FILE=${MONTH_MD_BASE}${MONTH_STRING}.md
	PERIOD=" i $MONTH_STRING ($LONG_YEAR1_NR-$LONG_YEAR2_NR)"
    fi


    if [ "$MYTEAMS" = "all" ]
    then
#	echo "GENERATING ALL TEAMS"
	SINGLE_TEAM_STRING=""
	TEAM_TITLE="$TEAMS"
	SOURCE_LINK="http://www.svenskhandboll.se/Handbollinfo/Tavling"
    else
#	echo "GENERATING SINGLE TEAM TEAM='$MYTEAMS'"
	SINGLE_TEAM_STRING=" AND TEAM='$MYTEAMS' "
	TEAM_TITLE="$MYTEAMS"
	SOURCE_LINK=${!MYTEAMS}
    fi
 
    NEW_PDF_FILE=${MD_FILE%.md}.pdf
    NEW_HTML_FILE=${MD_FILE%.md}.html

    TMP_FILE=$MD_FILE.tmp

    echo "![](ik-nord.png)   www.iknord.nu" > $TMP_FILE
    echo  >> $TMP_FILE
#    echo >$TMP_FILE

    SELECT_STMT_START="SELECT date, time, team, home, away FROM matcher "
    SELECT_STMT_END=" ORDER BY DATE "

    if [ "$HOME" != "all" ]
    then
	TITLE="Hemmamatcher"	
	TEAM_STRING=" HOME LIKE '%I%K%Nord%' "
    else
	TITLE="Matcher"
	TEAM_STRING=" ( HOME LIKE '%I%K%Nord%'  OR AWAY LIKE '%I%K%Nord%' ) "
    fi


    echo "# $TITLE $PERIOD" >> $TMP_FILE
    echo "# Lag: $TEAM_TITLE" >> $TMP_FILE


    SELECT_STMT="$SELECT_STMT_START WHERE $TEAM_STRING  $DATE_STRING $SINGLE_TEAM_STRING $SELECT_STMT_END ;"
#    echo "SELECT_STMT: $SELECT_STMT"
    
    db_command $SELECT_STMT  | while (true)
    do
	read LINE
	if [ "$LINE" = "" ] ; then break; fi
#	echo "DB:  $LINE"
	
#	echo "TEAM: $TEAM"

	DATE=$(echo $LINE | awk ' BEGIN {FS="|"} { print $1 ;}' )
	TIME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $2 ;}' )
	TEAM=$(echo $LINE | awk ' BEGIN {FS="|"} { print $3 ;}' )
	HOME=$(echo $LINE | awk ' BEGIN {FS="|"} { print $4 ;}' )
	AWAY=$(echo $LINE | awk ' BEGIN {FS="|"} { print $5 ;}' )
	echo "$DATE $TIME, $TEAM, $HOME - $AWAY" >> $TMP_FILE
	echo "" >> $TMP_FILE
    done

    echo "" >> $TMP_FILE
    echo "" >> $TMP_FILE
    echo "" >> $TMP_FILE
 

    echo "SOURCE_LINK: $SOURCE_LINK"
   
    echo "### Om dokumentet" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "URL: http://schema.iknord.nu/" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "K&auml;lla : $SOURCE_LINK" >> $TMP_FILE
    echo  >> $TMP_FILE
    echo "Genererades fr&aring;n k&auml;llan ovan:    $(date)" >> $TMP_FILE
    
    mv $TMP_FILE $MD_FILE

    cleanup_sv $MD_FILE
    
    pandoc   $MD_FILE -o $NEW_PDF_FILE
    pandoc   $MD_FILE -o $NEW_HTML_FILE

    cleanup_sv $NEW_HTML_FILE


#    echo $(pwd)/$MD_FILE
#    echo $(pwd)/$NEW_PDF_FILE
#    echo $(pwd)/$NEW_HTML_FILE

    if [ "$SINGLE_TEAM_STRING" = "" ]
    then
	echo "all teams, $MONTH_ARG, $HOME, ..."
	if [ "$HOME" != "all" ]
	then
	    if [ "$MONTH_STRING" = "" ]
	    then
		tohtml "Hemmamatcher: <a href=\"$NEW_PDF_FILE\">(pdf)</a> <a href=\"$NEW_HTML_FILE\">(html)</a>"
	    else
		tohtml "${MONTHS[$MONTH_ARG]} <a href=\"$NEW_PDF_FILE\">(pdf)</a> <a href=\"$NEW_HTML_FILE\">(html)</a>"
	    fi
	else
	    tohtml "Alla matcher: <a href=\"$NEW_PDF_FILE\">(pdf)</a> <a href=\"$NEW_HTML_FILE\">(html)</a>"
	fi
    else
	echo "single $SINGLE_TEAM_STRING ($MONTH_STRING) => $MD_FILE => $NEW_HTML_FILE   "
	if [ "$HOME" != "all" ]
	then
	    echo "  all $NEW_HTML_FILE"
	    tohtml "Hemmamatcher: <a href=\"$NEW_PDF_FILE\">(pdf)</a> <a href=\"$NEW_HTML_FILE\">(html)</a>"
	else
	    echo "  home $HTML_FILE"
	    tohtml "Samtliga matcher: <a href=\"$NEW_PDF_FILE\">(pdf)</a> <a href=\"$NEW_HTML_FILE\">(html)</a>"
	fi
    fi


}


create_all_old()
{
    MD_FILE=$1
    MYTEAMS="$2"
    HOME=$3
    MONTH_MD_BASE=$4

    rm -f all.tmp
    for team in $MYTEAMS
    do
	echo "ADDING $team.tmp2"
#	ls -al $team.tmp2
	cat $team.tmp2 >> all.tmp 
    done
    mv all.tmp all.tmp.tmp

#    MINIH=../../minihandboll.txt
#    if [ -f $MINIH ]
#    then
#	iconv -f ISO-8859-15  -t UTF-8  $MINIH > minihandboll.tmp
#	cat  minihandboll.tmp >> all.tmp.tmp 
#    fi
    sort all.tmp.tmp > all.tmp

#    echo "=== LOOK  all.tmp"
#    ls -al all.tmp
#    grep F04 all.tmp
#    echo "=== LOOK  all.tmp"

    NR_OF_TEAMS=$(echo "$MYTEAMS" | sed 's, ,\n,g' |  wc -l)
#    echo "NR_OF_TEAMS $NR_OF_TEAMS <==  $MYTEAMS"

    if [ "$HOME" != "all" ]
    then
	start_file games.tmp  "Hemmamatcher" "$MYTEAMS" "2014-2015"
    elif [ "$HOME" != "home" ]
    then
	start_file games.tmp  "Matcher" "$MYTEAMS" "2014-2015"
    fi

    idx=0
    while (true) 
    do
	MO="${MONTHS[$idx]}"
	if [ "$MO" = "" ]; then break ; fi

	if [ "$HOME" != "all" ]
	then
	    start_file month.tmp  "Hemmamatcher" "$MYTEAMS" "$MO / 2014-2015"
	elif [ "$HOME" != "home" ]
	then
	    start_file month.tmp  "Matcher" "$MYTEAMS" "$MO / 2014-2015"
	fi


#	echo "calling month_parser $HOME: $MYTEAMS"
	month_parser $MO ${MONTHS_REGEXP[$idx]} all.tmp games.tmp $HOME month.tmp
	idx=$(( $idx + 1 ))

	end_file month.tmp
	MONTH_MD=${MONTH_MD_BASE}$MO.md
	echo "iconving file:  month.tmp $(file  month.tmp)"
	iconv -f ISO-8859-15  -t UTF-8 month.tmp > $MONTH_MD
	MONTH_PDF_FILE=${MONTH_MD%.md}.pdf
	MONTH_HTML_FILE=${MONTH_MD%.md}.html

	cleanup_sv $MONTH_MD
	GENS=""
	pandoc   $MONTH_MD -o $MONTH_PDF_FILE
	if [ $? != 0 ] ; then echo "Failed generating PDF ($MONTH_PDF_FILE)" ; else GENS="$GENS $MONTH_PDF_FILE"; fi
	pandoc   $MONTH_MD -o $MONTH_HTML_FILE
	if [ $? != 0 ] ; then echo "Failed generating HTML ($MONTH_HTML_FILE)" ; else GENS="$GENS $MONTH_HTML_FILE"; fi
	cleanup_sv $MONTH_HTML_FILE
	
	
	echo "created:  $GENS (from $(file $MONTH_MD))"
    done
    

    end_file games.tmp
    iconv -f ISO-8859-15  -t UTF-8 games.tmp > $MD_FILE

    PDF_FILE=${MD_FILE%.md}.pdf
    HTML_FILE=${MD_FILE%.md}.html


    if [ $NR_OF_TEAMS -gt 1 ]
    then
	if [ "$HOME" != "all" ]
	then
	    tohtml "Hemmamatcher: <a href=\"$PDF_FILE\">(pdf)</a> <a href=\"$HTML_FILE\">(html)</a>"
	    
	    tohtml "<br><br>M&aring;nadsvis spelschema"
	    tohtml "<ul>"
	    idx=0
	    
	    while (true) 
	    do
		CMO="${MONTHS[$idx]}"
		if [ "$CMO" = "" ]; then break ; fi
		idx=$(( $idx + 1))
		tohtml "  <li>"
		tohtml "      $CMO / Samtliga: <a href=\"ik-nord-alla-$CMO.pdf\">(pdf)</a> <a href=\"ik-nord-alla-$CMO.html\">(html)</a>"
		tohtml " Hemma: <a href=\"ik-nord-hemma-$CMO.pdf\">(pdf)</a> <a href=\"ik-nord-hemma-$CMO.html\">(html)</a>"
		tohtml "  </li>"
		
	    done
	    tohtml "</ul>"
	else
	    tohtml "Samtliga matcher: <a href=\"$PDF_FILE\">(pdf)</a> <a href=\"$HTML_FILE\">(html)</a>"
	fi
	
	
	
    else
	if [ "$HOME" != "all" ]
	then
	    tohtml "Hemmamatcher: <a href=\"$PDF_FILE\">(pdf)</a> <a href=\"$HTML_FILE\">(html)</a>"
	else
	    tohtml "Samtliga matcher: <a href=\"$PDF_FILE\">(pdf)</a> <a href=\"$HTML_FILE\">(html)</a>"
	    tohtml "<br>"
	    if [ "$(echo ${!MYTEAMS} | grep -e 'txt$' | wc -l)" = "0" ]
	    then
		tohtml "L&auml;nk till seriesidan: <a href=\"${!MYTEAMS}\">${MYTEAMS}</a>"
	    else
		if [ "$(echo ${MYTEAMS} | grep F[0-9] | wc -l )" = "0" ]
		then
		    tohtml "L&auml;nk till nedladdade dokument: <a href=\"tmp/pojkar/\">${MYTEAMS}</a>"
		else
		    tohtml "L&auml;nk till nedladdade dokument: <a href=\"tmp/flickor/\">${MYTEAMS}</a>"
		fi
	    fi
	fi
    fi

    tohtml "<br>"

    cleanup_sv $MD_FILE

    pandoc   $MD_FILE -o $PDF_FILE
    pandoc   $MD_FILE -o $HTML_FILE

    cleanup_sv $HTML_FILE


    echo "created:  $PDF_FILE  $HTML_FILE"
} 


tohtml()
{
#    echo "In $(pwd) adding to: $HTML_PAGE"
    echo "$*" >> $HTML_PAGE
#    exit
}


start_html()
{
    rm -f $HTML_PAGE
    echo "creating $HTML_PAGE in $(pwd)"
    tohtml "<html xmlns=\""http://www.w3.org/1999/xhtml\"" xml:lang=\""sv\"" lang=\""sv\"">"
    tohtml "<head>"
    tohtml "<title>Spelschema f&ouml;r IK Nord 2014/2015 ($TEAMS)</title>"
    tohtml "<img src=\"ik-nord.png\">"
    tohtml "</head>"
    tohtml "<body>"
    tohtml "<h1>Spelschema f&ouml;r IK Nord 2014/2015</h1>"
}


stop_html()
{
    tohtml "generated at $(date)"
    tohtml "</body>"
    tohtml "</html>"
}

add_all()
{
    tohtml "<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>Alla filer:" 
    for i in $(ls *.pdf)
    do
	tohtml "<a href=\"$i\">$i</a>" 
    done
    for i in $(ls *.html)
    do
	tohtml "<a href=\"$i\">$i</a>" 
    done
}




########



init
clean_db
clean_up
mkdir -p   ${MYTMPDIR}
fix_logo
cd         ${MYTMPDIR}
set_up

start_html


for i in $TEAMS
do
     get_games $i
#    get_cafe  $i
done


tohtml "<h2>Spelschema f&ouml;r samtliga lag: $TEAMS</h2>"
create_all ik-nord-alla.md  "all" "all" ik-nord-alla- all
create_all ik-nord-hemma.md "all" "home" ik-nord-hemma- all


tohtml "<h2>Hemmamatcher per m&aringnad:</h2>"
MONTH_IDX=0
while [ "${MONTHS_REGEXP[$MONTH_IDX]}" != "" ]
do
#    tohtml "<h2>${MONTHS[$MONTH_IDX]}</h2>"
    create_all ik-nord-hemma.md "all" "home" ik-nord-hemma- "$MONTH_IDX"
    MONTH_IDX=$(( $MONTH_IDX + 1))
done


tohtml "<h2>Individuella spelschema f&ouml;r lagen: $TEAMS</h2>"
for i in $TEAMS
do
    tohtml "<h2>$i</h2>"
    create_all ik-nord-$i.md $i "all" ik-nord-$i-alla all
    tohtml "<br>"
    create_all ik-nord-$i.md $i "home" ik-nord-$i-hemma all
done

cp *.pdf ../../
cp *.html ../../


add_all

stop_html
