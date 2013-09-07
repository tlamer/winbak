#!/bin/bash

PATH=$PATH:/bin
declare -r CONF="/etc/winbak.conf"
declare -r EXCLUDE="/etc/winbak.exclude"

if [[ -e $CONF ]]
then
	[[ ! -e $EXCLUDE ]] && { echo "Can not find $EXCLUDE . Exiting..." ; exit 1 ; }
	source "$CONF"
else
	echo "Can not find config file $CONF. Exiting..."
	exit 1
fi

die (){
	[[ $2 ]] && echo "$2"
	exit "$1"
}

# TODO source dir check
sanity(){
	# sanity checks
	if [[ ! -d ${DEST} ]]
	then
		die 2 "Can not find destination directory with path ${DEST} . Check if backup drive is connected properly. Exiting..."
	fi
	
	for i in $(seq ${SNAPCOUNT})
	do
		if [[ ! -d ${DEST}/snapshot.${i} ]]
		then
			die 3 "Destination directory ${DEST}/snapshot.${i} does not exist. Exiting..."
		fi
	done
	
	for src in "${SOURCE[@]}"
	do
		if [[ ! -e $src ]]
		then
			"Can not find source ${src}. Exiting..."
		fi
	done
	}

rotate(){
	# delete last snapshot
	rm -r "$DEST/snapshot.$SNAPCOUNT"
	(( $? !=0 )) && die 10 "Can not remove last snapshot. Exiting..."

	# rotate
	for i in $(seq $(($SNAPCOUNT-1)) -1 1)
	do
		mv "$DEST/snapshot.$i" "$DEST/snapshot.$(($i+1))"
		(( $? != 0 )) && die 11 "Rotating snapshots failed. Exiting..."
	done
	
	# create directory for new snapshot
	mkdir "$DEST/snapshot.1"
	(( $? != 0 )) && die 12 "Can not create directory for new snapshot. Exiting..."
}

backup(){
	local log="$(mktemp --tmpdir=/tmp backup_log.XXX)"
	
	rsync \
		--verbose \
		--human-readable \
		--archive \
		--safe-links \
		--hard-links \
		--delete \
		--delete-excluded \
		--exclude-from="$EXCLUDE" \
		--link-dest="$DEST/snapshot.2" \
		"${SOURCE[@]}" \
		"$DEST/snapshot.1" 2>&1 | tee "$log"
		
		if (( $? == 0 ))
		then
			mv "$log" "$DEST/snapshot.1/backup_log-$(date +%F).txt"
			echo "Backup was successfully finished."
		else
			die 100 "Backup failed. Log file: $log"
		fi
}

main(){
	sanity
	rotate
	backup
}

main
read