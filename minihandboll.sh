#!/bin/bash

FIL_ARKIV_URL="http://www.proteamonline.se/customers/file_archive.asp?Id=443"
FIL_ARKIV_TXT=filarkiv.txt
FIL_ARKIV_HTML=filarkiv.html

if [ ! -d tmp ]
then
    mkdir tmp
fi
if [ ! -d tmp/pojkar ]
then
    mkdir tmp/pojkar
fi
if [ ! -d tmp/flickor ]
then
    mkdir tmp/flickor
fi

cd tmp

cleanup() 
{
    rm -f *.doc *.txt *.doc.*
}

exit_on_error()
{
    if [ "$1" != "0" ]
    then
	echo "Error ... bailing out"
	echo "    last command: $2"
	exit $1
    fi
}

finddocs()
{
    TXT_FILE=$1

    DOCS=$(grep Spelprogram  ${FIL_ARKIV_TXT} | grep doc | sed -e "s,\[system/images/archive_icon_doc.gif\],,g"  -e "s,^[ \t]*,,g" | sed 's, ,\n,g' | grep Spelprogram | awk '{ print $1}')
    
    for file in $DOCS
    do
	FILE1=$( echo ${file} | sed 's,_, ,g' | sed 's,[0-9][0-9]*$,,g').doc
	FILE2=$(urlencode $FILE1)
#	echo 
#	echo "PWD:    $(pwd)"
#	echo "Doc :   $file"
#	echo "Doc1:   $FILE1"
#	echo "Doc2:   $FILE2"
	export FILE1
	FILE3=$(php -r "echo urlencode(\"$FILE1\");")
#	echo "Doc3:   wget http://www.proteamonline.se/storage/customers/443/archive/$FILE3"
	
#	echo "Arkiv: $FIL_ARKIV_TXT"
#	echo "encode:  $FILE1 => $FILE2"
	echo "dload: http://www.proteamonline.se/storage/customers/443/archive/$FILE1"
	wget "http://www.proteamonline.se/storage/customers/443/archive/$FILE1" 
	RET=$?
	echo " ---> $RET"
	if [ "$RET" != "0" ]
	then
	    echo "DEBUG:"
	    echo "    file:  $file"
	    echo "    FILE1: $FILE1"
	    echo "    FILE2: http://www.proteamonline.se/storage/customers/443/archive/$FILE2"
	    echo "    FILE3: $FILE3"
	fi
	exit_on_error $RET "wget \"http://www.proteamonline.se/storage/customers/443/archive/$FILE1\" "
	#--output-file=${file}.doc
#	mv  "$FILE1" "${file}.doc"
#	RET=$?
#  2>/dev/null

#	curl "http://www.proteamonline.se/storage/customers/443/archive/$FILE2" -o ${file}.doc 2>/dev/null
#	exit_on_error $? "curl \"http://www.proteamonline.se/storage/customers/443/archive/$FILE2\" -o ${file}.doc"
	IS_HTML=$(file $file.doc | grep -i html | wc -l)
	if [ $IS_HTML -ne 0 ]
	    then
	    echo "Failed downloading: $FILE2  (http://www.proteamonline.se/storage/customers/443/archive/$FILE1)"
	    exit
	fi

#http://www.proteamonline.se/storage/customers/443/archive/Spelprogram%20omg%201%2005%20S%C3%A4r%C3%B6kometerna%2017%20nov.doc
#                                                          Spelprogram%20omg%201%2005%20S%FF%FFr%FF%FFkometerna%2017%20nov59.doc
    done

    
	#Spelprogram
        #Spelprogram
#    cat $TXT_FILE | while read LINE 
#    do
#	echo "LINE: $LINE"	
#    done


}

getdocs()
{
    curl -o ${FIL_ARKIV_HTML} "$FIL_ARKIV_URL" # 2>/dev/null
    RET=$?
    exit_on_error $RET "curl -o ${FIL_ARKIV_HTML} $FIL_ARKIV_URL"

    # QUICK AND DIRTY FIX
    cat ${FIL_ARKIV_HTML} | sed 's,Spelprogram  ,Spelprogram QAD_FILL,g' > ${FIL_ARKIV_HTML}.tmp
    mv ${FIL_ARKIV_HTML}.tmp ${FIL_ARKIV_HTML}

    html2text  -o ${FIL_ARKIV_TXT} ${FIL_ARKIV_HTML}


    echo "QUICK AND DIRTY FIX: ${FIL_ARKIV_TXT} in $(pwd)"
    cat ${FIL_ARKIV_TXT} | sed 's,QAD_FILL,_,g' > ${FIL_ARKIV_TXT}.tmp
    mv  ${FIL_ARKIV_TXT}.tmp ${FIL_ARKIV_TXT}
}


gentxt()
{

#    GENDER=$1

 #   rm $GENDER/*
 #   cp ../docs/$GENDER/*.doc $GENDER/

#    cd $GENDER 
    ls *.doc  | while read file
    do
	NEW=$(echo $file | sed 's, ,_,g')
	if [ "$NEW" != "$file" ]
	then
	    mv "$file" $NEW
	fi
    done

    for i in $(ls *.doc)
    do
	echo "Converting $i to $i.txt"
	catdoc "$i" > "$i".txt

	POJK=$(grep -e "P0[45]" -e "[Pp]ojkar" "$i.txt" | wc -l)
	FLICK=$(grep -e "F0[45]" -e "[Ff]lickor" "$i.txt" | wc -l)
	if [ "$POJK" != "0" ] &&  [ "$FLICK" != "0" ]; then
	    echo "ERROR"
	    "File: $i.txt  is both FLICK and POJK"
	    exit 1
	fi

	if [ "$POJK" != "0" ] ; then
	    mv "$i".txt pojkar/
	fi

	if [ "$FLICK" != "0" ] ; then
	    mv "$i".txt flickor/
	fi


    done



#    cd ..
}

finddat()
{
    GENDER=$1

    if [ "$GENDER" = "flickor" ]
	then
	GENDER_SHORT="F04"
    else
	GENDER_SHORT="P04"
    fi

    cd $GENDER 
    rm ../$GENDER_SHORT.txt
    for f in $(grep -l -i nord *.txt)
    do
#    echo $f
	for t in $(grep -l -i nord $f)
	do
	    echo "Getting date..."
	    DATE=$(grep Dag $t | sed 's,[a-zA-Z]*[dD]*ag: ,,g' | sed 's,[a-zA-Z]*[dD]*ag ,,g' | sed 's,Okt,Oct,g' | sed -e 's,[sSlL]ö,,')
	    DATE=$(echo $DATE | sed -e 's,mars,march 2014,g' -e 's,februari,february 2014,g' -e 's,januari,january 2014,g')
	    GDATE=$(date -d "$DATE" "+%y-%m-%d")
	    GLOC=$(grep -i hall $f | sed 's,Hall:[ ]*,,g')  
	    echo "GDATE: $GDATE => date -d \"$DATE\" \"+%y-%m-%d\""
	    echo "Convert $DATE"
	    
	    echo "$(date -d "$DATE" "+%y-%m-%d")   dag    Nord                 - olika-lag                 -     $GLOC                 " >> ../$GENDER_SHORT.txt
#	    echo "in $(pwd) created  ../$GENDER_SHORT.txt"
	done
    done | sort

    cd ..

    cp $GENDER_SHORT.txt  ../
    

} 

cleanup
getdocs

finddocs ${FIL_ARKIV_TXT}

gentxt 
#gentxt flickor
#gentxt pojkar
rm all.txt

echo Flickor
finddat flickor 
echo Pojkar
finddat pojkar 



#echo "Flickor"
#sort F04.txt | tail -1
#echo "13-12-15   dag    Nord                 - olika-lag                 -     Aktiviteten"


