#!/bin/bash

CIF=cloud-init.txt-template
CRT=../decrypt-ca/certs/ca.cert.pem

if [ ! -f $CIF ] || [ ! -r  $CIF ]
then
	echo "$CIF does not exist or is not readable in cwd"
	exit -1
fi

if [ ! -f $CRT ] || [ ! -r  $CRT ]
then
	echo "$CRT does not exist or is not readable in cwd"
	exit -1
fi

which base64
if [ $? -ne 0 ]
then
	echo "base64 not in $PATH. install base64 and try again"
	exit
fi

B64CRT=$(base64 < $CRT)

sed -e "s|___TRUSTCA___|$B64CRT|" < $CIF > cloud-init.txt

echo $B64CRT
