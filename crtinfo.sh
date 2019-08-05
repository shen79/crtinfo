#/bin/bash


PROGRESS="--progress --eta --bar"

_print() { echo -e "[${FUNCNAME[1]}] $1"; }
msg() { [ ! "$QUIET" = 1 ] && _print "$1"; }
dbg() {	[ ! "$QUIET" = 1 ] && _print "$1"; }
err() {	_print "$1"; }
die() { _print "$1"; exit; }
handl() {
	openssl x509 -noout -inform pem -in "$1" -subject | cut -d ' ' -f 3- >> $1.subj
	openssl x509 -noout -inform pem -in "$1" -ext subjectAltName | tr , "\n" | grep -v 'X509v3 Subject Alternative Name:' | sed -e 's/^\s*//' | cut -d : -f 2 >> $1.san
	openssl x509 -noout -inform pem -in "$1" -email >> $1.email
}
export -f handl
resolv() {
	host "$1" |& sed -e 's/is an alias for/ALIAS/; s/has address/A/; s/not found: 2(SERVFAIL)/SERVFAIL/; s/^Host\s//; s/mail is handled by [0-9]*/MX/; s/has IPv6 address/AAAA/'
}
export -f resolv


usage() {
	echo -e "Params:
	-d|--domain     domainname.tld
	-no-dl          disable downloading
	-no-proc        disable processing
	-no-dns         disable dns resolution
	-q|--quiet      quiet
	-o|--output     output file name
Example:
	$0 <-d|--domain domain.tld>"
	exit
}

# ==============================================================================
# ~GETOPT
# ==============================================================================

DOWNLOAD=1
PROCESS=1
DNSRESOLVE=1

VAR=''
for OPT in "$@"; do
	if [ -n "$VAR" ]; then
		export "$VAR"="$OPT"
		VAR=''
	else
		case "$OPT" in
			-d|--domain)
				VAR=DOMAIN
				;;
			-no-dl)
				DOWNLOAD=0
				;;
			-no-proc)
				PROCESS=0
				;;
			-no-dns)
				DNSRESOLVE=0
				;;
			-q|--quiet)
				QUIET=1
				PROGRESS=""
				;;
			-o|--output)
				VAR=OUTPUT ;;
			*)
				err "unknown parameter: $OPT"
				usage ;;
		esac
	fi
done

# ==============================================================================
# 
# ==============================================================================

[ -z "$DOMAIN" ] && usage
T=./data/$DOMAIN
[ ! -d $T ] && mkdir -p $T
[ "$DOWNLOAD" = 1 ] && rm -f $T/*


msg "targeting $DOMAIN"


# ==============================================================================
# DOWNLOAD from crt.sh
# ==============================================================================

if [ "$DOWNLOAD" = 1 ]; then
	wget -q "https://crt.sh/?output=json&q=%25.$DOMAIN" -O $T/crt.json
#	wget -q "https://crt.sh/?output=json&q=$DOMAIN" -O $T/crt.json
	cat $T/crt.json | jq .[].min_cert_id | sort -nr | uniq > $T/certids.txt
	CERTS=$(cat $T/certids.txt | wc -l)
	msg "certificates found $CERTS, downloading..."
#	cat $T/certids.txt | parallel $PROGRESS -j 4 wget -q "https://crt.sh/?d={1}" -O "$T/{1}.pem"
	parallel -a $T/certids.txt $PROGRESS -j 4 wget -q "https://crt.sh/?d={1}" -O "$T/{1}.pem"
	msg "download finished"
else
	msg "skip downloading..."
fi


# ==============================================================================
# 
# ==============================================================================




if [ "$PROCESS" = 1 ]; then
	msg "processing..."
	msg "parsing the hell out of the files..."
	rm -f .san .subj
	ls -1 $T/*.pem | parallel $PROGRESS -j 8 handl '{1}'
	{
		cat $T/*.pem.subj | sed -e 's/,\s*/\n/g' | grep ^CN | cut -d ' ' -f 3 | sed -e 's/^/SUBJECT:/'
		cat $T/*.pem.san | sed -e 's/^/SAN:/'
	} | cut -d : -f 2 | sort | uniq > $T/all-domains
	{
		cat $T/*.pem.email
	}
	rm -f $T/*.pem.*
else
	msg "skip processing..."
fi


# ==============================================================================
# DNS RESOLVE
# ==============================================================================

if [ "$DNSRESOLVE" = 1 ]; then
	rm -f $T/all-resolv
	msg "DNS resolution..."
	parallel -a $T/all-domains -j 10 $PROGRESS resolv '{}' > $T/all-resolv
	cat $T/all-resolv | column -nts' '
else
	msg "skip DNS resolution..."
fi















