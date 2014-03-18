#!/bin/bash


TEAMS_CONF=$(dirname $0)/teams.conf
if [ -f $TEAMS_CONF ] 
then
    . $TEAMS_CONF 
else
    echo $TEAMS_CONF not found
    exit 1
fi

#TEAMS="F01 P04 " 
declare -a MONTHS
declare -a MONTHS_REGEXP


BACKUP_DIR=$(pwd)/results/$(date +%Y-%m-%d)

MYTMPDIR=tmp/match
HTML_PAGE=$(pwd)/index.html


init()
{
    idx=0
    for i in September Oktober November December Januari Februari Mars April
    do
	MONTHS[$idx]=$i
	idx=$(( $idx + 1))
    done
    idx=0
    for i in ^13-09- ^13-10- ^13-11- ^13-12- ^14-01- ^14-02- ^14-03- ^14-04- 
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
    mkdir -p        ${MYTMPDIR}
    cp ik-nord.png  ${MYTMPDIR}
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


get_games()
{

 #   echo "get_games($i)"

    TEAM=$1

    dos2unix $TEAM.txt
#    file $TEAM.txt
#    sleep 20
    grep -i -e nord -e sammandrag $TEAM.txt | grep "[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | \
	sed -e 's,<[a-zA-Z0-9 ]*=[0-9a-zA-Z#]*>[ \t]*[0-9]*[ \t]*[0-9]*,,g' -e "s,</font>,,g" -e "s,^[ \t]*,,g" > $TEAM.tmp

#    echo " ==== get_games $1 "

#    echo "in here..... $(pwd)"

    cat $TEAM.tmp | while (true); 
    do
	read line
#	echo "line: $line"
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

 #   echo "FIND $REG in $FILE"
#    grep 04 $FILE

    grep "$MONTH_RE" $FILE | while (true); do
	read newline
	if [ "$newline" = "" ]; then break ; fi

	if [ "$REG" != "all" ]
	then
#	    echo "#LINE1: $newline  \"$REG\"  "
#	    echo "#  re: $REG"
	    LINE=$(echo "$newline" | grep "[I]*[K]*[ ]*Nord -" | grep -e asthugg -e alhalla -e iseberg)
#	    echo "#LINE2: $LINE"
	    if [ "$LINE" != "" ] ; then
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
	start_file games.tmp  "Hemmamatcher" "$MYTEAMS" "2013-2014"
    else
	start_file games.tmp  "Matcher" "$MYTEAMS" "2013-2014"
    fi

    idx=0
    while (true) 
    do
	MO="${MONTHS[$idx]}"
	if [ "$MO" = "" ]; then break ; fi

	if [ "$HOME" != "all" ]
	then
	    start_file month.tmp  "Hemmamatcher" "$MYTEAMS" "$MO / 2013-2014"
	else
	    start_file month.tmp  "Matcher" "$MYTEAMS" "$MO / 2013-2014"
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
	pandoc   $MONTH_MD -o $MONTH_PDF_FILE
	pandoc   $MONTH_MD -o $MONTH_HTML_FILE
	cleanup_sv $MONTH_HTML_FILE

	
	echo "created:  $MONTH_PDF_FILE  $MONTH_HTML_FILE (from $(file $MONTH_MD))"
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
    tohtml "<title>Spelschema f&ouml;r IK Nord 2013/2014 ($TEAMS)</title>"
    tohtml "<img src=\"ik-nord.png\">"
    tohtml "</head>"
    tohtml "<body>"
    tohtml "<h1>Spelschema f&ouml;r IK Nord 2013/2014</h1>"
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
clean_up
set_up
cd       ${MYTMPDIR}


for i in $TEAMS
do
    fetch_url $i
    if [ $? -ne 0 ]
    then
	exit 0
    fi

    diff $i.txt ../../$i.txt
    RET=$?
#    if [ $RET -ne 0 ]
#	then
#	echo "Lag: $i $(date)" >> ../../nytt-schema.txt
#    fi
    cp $i.txt ../../

done




start_html


#if [ -f ../../nytt-schema.txt ]
#then
#    tohtml "Nytt schema funnet: $(cat ../../nytt-schema.txt)"
#else
#    tohtml "Inga uppdateringar p&aring; www3.proteamonline.se funna $(date "+%Y-%m-%d %H:%M:%S")"
#fi


for i in $TEAMS
do
    get_games $i
done


tohtml "<h2>Spelschema f&ouml;r samtliga lag: $TEAMS</h2>"
create_all ik-nord-alla.md  "$TEAMS" "all" ik-nord-alla-
create_all ik-nord-hemma.md "$TEAMS" "home" ik-nord-hemma-

tohtml "<h2>Individuella spelschema f&ouml;r lagen: $TEAMS</h2>"
for i in $TEAMS
do
    tohtml "<h2>$i</h2>"
    create_all ik-nord-$i.md $i "all" ik-nord-$i-
done

cp *.pdf ../../
cp *.html ../../


add_all

stop_html
