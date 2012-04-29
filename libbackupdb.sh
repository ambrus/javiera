#! /bin/sh

source ~/code/bash/lib-backupdb/libftype.sh
source ~/code/bash/lib-backupdb/upvars.sh

#=======================================================================
#
#         FILE: libbackupdb.sh
#
#  DESCRIPTION: Provides functions to scripts that must interact with
#               the backup database.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               libftype.sh
#               upvars.sh
#         BUGS: --
#        NOTES: --
#       AUTHOR: Marcelo Auquer, auquer@gmail.com
#      CREATED: 03/07/2012
#     REVISION: 03/25/2012
#
#======================================================================= 

#===  FUNCTION =========================================================
#
#        NAME: get_id
#
#       USAGE: get_id HANDLE VARNAME HOSTNAME PATHNAME
#
# DESCRIPTION: Query the backup database for a file id number. Store the
#              result in the caller's VARNAME variable.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
#=======================================================================
get_id () {
	! is_backedup $1 backedup $3 $4 && return 1
	if [ $backedup == "true" ]
	then
		local id
		id=$(shsql $1 $(printf 'SELECT id FROM file WHERE 
			hostname="%b" AND pathname="%b";' $3 $4))
		[[ $? -ne 0 ]] && return 1
		local $2 && upvar $2 $id
	fi
}

#===  FUNCTION =========================================================
#
#        NAME: is_backedup
#
#       USAGE: is_backedup HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Do a query on the connected database to find out if data
#              about the file pointed by PATHNAME already exists in the
#              database. Store "true" in the caller's VARNAME variable
#              if it is so. Otherwise, store "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
#=======================================================================
is_backedup () {
	local count
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM file WHERE
		hostname="%b" AND pathname="%b";' $3 $4))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
}

#===  FUNCTION =========================================================
#
#        NAME: is_archived
#
#       USAGE: is_archived HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "archived" column of any row in the table
#              "archive" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
#=======================================================================
is_archived () {
	local count
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM archive
		WHERE archived=%b;' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: is_indvd
#
#       USAGE: is_indvd HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "image_file" column of any row in the table
#              "dvd" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
#=======================================================================
is_indvd () {
	local count
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM dvd
		WHERE image_file=%b;' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: is_archiver
#
#       USAGE: is_archiver HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "archiver" column of any row in the table
#              "archive" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
#=======================================================================
is_archiver () {
	local count
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM archive
		WHERE archiver=%b;' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: is_insync
#
#       USAGE: is_insync HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Do a query on the connected database to find out if data
#              about the file pointed by PATHNAME is up to date. Store 
#              "true" in the caller's VARNAME variable if it is so. 
#              Otherwise, store "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
#=======================================================================
is_insync () {
	local tstamp
	tstamp=$(shsql $1 $(printf 'SELECT last_updated FROM 
		file WHERE hostname="%b" AND pathname="%b";' $3 $4))
	[[ $? -ne 0 ]] && return 1
	tstamp="${tstamp##\"}"
	tstamp="${tstamp%%\"}"
	tstamp=$(date --date="$tstamp" +%s)
	local diff
	diff=$(($tstamp-$(stat --format=%Y $4)))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $diff -lt 0 ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: insert_archive
#
#       USAGE: insert_archive HANDLE ARCHIVER_ID ARCHIVED_ID
#
# DESCRIPTION: Insert in the archive table of the backup database a row.
#
#  PARAMETERS: HANDLE      A connection to a database.
#              ARCHIVER_ID The file id number of the archiver file. Must
#                          be passed between <">.
#              ARCHIVED_ID The file id number of the archived file. Must
#                          be passed between <">.
#
#=======================================================================
insert_archive () {
	shsql $1 $(printf 'INSERT INTO archive (archiver, archived)
		VALUES (%b, %b);' $2 $3)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: insert_dvd
#
#       USAGE: insert_dvd HANDLE IMAGE_ID DVD_TYPE DVD_TRADEMARK
#
# DESCRIPTION: Insert in the archive table of the backup database a row.
#
#  PARAMETERS: HANDLE        A connection to a database.
#              IMAGE_ID      The file id number of the image file. Must
#                            be passed between <">.
#              DVD_TYPE      The type of the DVD burned. Usually, DVD-R,
#                            DVD+R, etc. Must be passed between <">.
#              DVD_TRADEMARK The trademark or manufacturer of the DVD.
#                            Must be passed between <">.
#
#=======================================================================
insert_dvd () {
	shsql $1 $(printf 'INSERT INTO dvd (image_file, dvd_type,
		dvd_trademark) VALUES (%b, "%b", "%b");' $2 $3 $4)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: insert_file
#
#       USAGE: insert_file HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Collect metadata related to the file pointed by PATHNAME
#              and insert it in the db's file table.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
#=======================================================================
insert_file () {
	shsql $1 $(printf 'INSERT INTO file (mimetype, hostname, 
		pathname, fsize, mtime) VALUES ("%b", "%b", "%b", "%b",
		"%b");' $(file -b --mime-type $3) $2 $3 \
		$(stat --format='%s %Y' $3))
	[[ $? -ne 0 ]] && return 1
	if is_flac $3
	then
		local lastid
		lastid=$(shsql $1 "SELECT LAST_INSERT_ID();")
		[[ $? -ne 0 ]] && return 1
		! insert_flacdata $1 $3 $lastid && return 1
	fi
	if is_iso $3
	then
		local lastid
		lastid=$(shsql $1 "SELECT LAST_INSERT_ID();")
		[[ $? -ne 0 ]] && return 1
		! insert_iso $1 $lastid && return 1
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: insert_iso
#
#       USAGE: insert_iso HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the iso file pointed by
#              PATHNAME and insert it in the related table in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              ID        A number value related to the id column of the
#                        database's file table.
#=======================================================================
insert_iso () {
	shsql $1 $(printf 'INSERT INTO iso_metadata (file_id) VALUE
		(%b);' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: insert_flacdata
#
#       USAGE: insert_flacdata HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        A number value related to the id column of the
#                        database's file table.
#=======================================================================
insert_flacdata () {
	local tsamples=\"$(metaflac --show-total-samples $2)\"
	local sample_rate=\"$(metaflac --show-sample-rate $2)\"
	local channels=\"$(metaflac --show-channels $2)\"
	local bps=\"$(metaflac --show-bps $2)\"
	local md5=\"$(metaflac --show-md5sum $2)\"
	shsql $1 $(printf 'INSERT INTO flac_streaminfo (file_id, 
		total_samples, sample_rate, channels, bits_per_sample, 
		MD5_signature) VALUES (%b, %b, %b, %b, %b, %b);' $3 \
		"$tsamples" "$sample_rate" "$channels" "$bps" "$md5")
	[[ $? -ne 0 ]] && return 1
	local title="$(metaflac --show-tag=title $2)"
	title="${title##title=}"
	title=${title:-NULL} && [[ $title != NULL ]] && \
		title="\"$title\""
	local artist="$(metaflac --show-tag=artist $2)"
	artist="${artist##artist=}"
	artist=${artist:-NULL} && [[ $artist != NULL ]] && \
		artist="\"$artist\""
	local artistsort="$(metaflac --show-tag=artistsort $2)"
	artistsort="${artistsort##artistsort=}"
	artistsort=${artistsort:-NULL} && [[ $artistsort != NULL ]] && \
		artistsort="\"$artistsort\""
	local album="$(metaflac --show-tag=album $2)"
	album="${album##album=}"
	album=${album:-NULL} && [[ $album != NULL ]] && \
		album="\"$album\""
	local tracknumber="$(metaflac --show-tag=tracknumber $2)"
	tracknumber="${tracknumber##tracknumber=}"
	tracknumber=${tracknumber:-NULL} && [[ $tracknumber != NULL ]] && \
		tracknumber="\"$tracknumber\""
	local totaltracks="$(metaflac --show-tag=totaltracks $2)"
	totaltracks="${totaltracks##totaltracks=}"
	totaltracks=${totaltracks:-NULL} && [[ $totaltracks != NULL ]] && \
		totaltracks="\"$totaltracks\""
	shsql $1 $(printf 'INSERT INTO flac_comments (file_id, title, 
		artist, artistsort, album, tracknumber, totaltracks) 
		VALUES (%b, %b, %b, %b, %b, %b, %b);' $3 "$title" \
		"$artist" "$artistsort" "$album" "$tracknumber" \
		"$totaltracks")
	[[ $? -ne 0 ]] && return 1
	local mbrz_albumid="$(metaflac --show-tag=musicbrainz_albumid $2)"
	mbrz_albumid="${mbrz_albumid##musicbrainz_albumid=}"
	mbrz_albumid=${mbrz_albumid:-NULL} && [[ $mbrz_albumid != NULL ]] \
	       	&& mbrz_albumid="\"$mbrz_albumid\""
	local mbrz_artistid="$(metaflac --show-tag=musicbrainz_artistid $2)"
	mbrz_artistid="${mbrz_artistid##musicbrainz_artistid=}"
	mbrz_artistid=${mbrz_artistid:-NULL} && [[ $mbrz_artistid != NULL ]] \
	       	&& mbrz_artistid="\"$mbrz_artistid\""
	local mbrz_albartid="$(metaflac --show-tag=musicbrainz_albumartistid $2)"
	mbrz_albartid="${mbrz_albartid##musicbrainz_albumartistid=}"
	mbrz_albartid=${mbrz_albartid:-NULL} && [[ $mbrz_albartid != NULL ]] \
	       	&& mbrz_albartid="\"$mbrz_albartid\""
	local mbrz_trackid="$(metaflac --show-tag=musicbrainz_trackid $2)"
	mbrz_trackid="${mbrz_trackid##musicbrainz_trackid=}"
	mbrz_trackid=${mbrz_trackid:-NULL} && [[ $mbrz_trackid != NULL ]] \
	       	&& mbrz_trackid="\"$mbrz_trackid\""
	shsql $1 $(printf 'INSERT INTO musicbrainz_ids (file_id, 
		albumid, artistid, albumartistid, trackid) VALUES (%b, 
		%b, %b, %b, %b);' $3 "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid")
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: delete_file
#
#       USAGE: delete_file HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
#=======================================================================
delete_file () {
	! is_archived $1 archived $2 && return 1
	! is_indvd $1 indvd $2 && return 1

	# If it's an archived file or has been burned to a DVD do not
	# delete from db. Instead, set
	# NULL "pathname" and "hostname" columns in "file" table.
	if [ \( $archived == true \) -o \( $indvd == true \) ]
	then
		shsql $1 $(printf 'UPDATE file SET pathname=NULL,
			hostname=NULL WHERE id=%b;' $2)
		[[ $? -ne 0 ]] && return 1
		return 0
	fi

	! is_archiver $1 archiver $2 && return 1

	# If it's an archiver file, before deleting it from the db,
	# delete from "archive" table every row with a value of ID in
	# "archiver" column.
	if [ $archiver == true ]
	then
		shsql $1 $(printf 'DELETE FROM archive WHERE
			archiver="%b";' $2)
		[[ $? -ne 0 ]] && return 1
		delete_orphans $1
		[[ $? -ne 0 ]] && return 1
	fi
	local mimetype
	mimetype=$(shsql $1 $(printf 'SELECT mimetype FROM file 
		WHERE id="%b";' $2))
	[[ $? -ne 0 ]] && return 1
	if [[ $mimetype = \"audio/x-flac\" ]]
	then
		if ! delete_flacdata $1 $2 
		then
			printf 'libbackupdb.sh: error in delete_flacdata
				().' 1>&2
			return 1
		fi
	elif [[ $mimetype = \"application/x-iso9660-image\" ]]
	then
		if ! delete_isodata $1 $2
		then
			printf 'libbackupdb.sh: error in delete_isodata
				().' 1>&2
			return 1
		fi
	fi
	shsql $1 $(printf 'DELETE FROM file WHERE id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: delete_orphans
#
#       USAGE: delete_orphans HANDLE
#
# DESCRIPTION: Delete from table "file" all the records with
#              pathname=NULL which do not exist as archived in table
#              archive.
#
#  PARAMETERS: HANDLE  A connection to a database.
#
#=======================================================================
delete_orphans () {
	shsql $1 $(printf 'DELETE FROM file WHERE file.pathname IS NULL
		AND NOT EXISTS (SELECT archived FROM archive WHERE
		file.id=archive.archived);' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: delete_isodata
#
#       USAGE: delete_isodata HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
#=======================================================================
delete_isodata () {
	shsql $1 $(printf 'DELETE FROM iso_metadata WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: delete_flacdata
#
#       USAGE: delete_flacdata HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
#=======================================================================
delete_flacdata () {
	shsql $1 $(printf 'DELETE FROM flac_streaminfo WHERE
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'DELETE FROM flac_comments WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	shsql $1 $(printf 'DELETE FROM musicbrainz_ids WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: update_file
#
#       USAGE: update_file HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Collect metadata related to the file pointed by PATHNAME
#              and update all the related records in the database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
#=======================================================================
update_file () {
	! get_id $1 id $2 $3 && return 1
	! is_archived $1 archived $id && return 1
	if [ $archived == "true" ]
	then
		! insert_file $1 $2 $3 && return 1
	else
		shsql $1 $(printf 'UPDATE file SET mimetype="%b", 
			fsize="%b", mtime="%b" WHERE hostname="%b" AND 
			pathname="%b";' $(file -b --mime-type $3) \
			$(stat --format='%s %Y' $3) $2 $3)
		[[ $? -ne 0 ]] && return 1
		if is_flac $3; then
			local id
			id=$(shsql $1 $(printf 'SELECT id FROM file 
				WHERE pathname="%b";' $3))
			[[ $? -ne 0 ]] && return 1
			! update_flacdata $1 $file $id && return 1
		fi
	fi
	return 0
}

#===  FUNCTION =========================================================
#
#        NAME: update_flacdata
#
#       USAGE: update_flacdata HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the flac file pointed by
#              PATHNAME and update it in all the related tables in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              PATHNAME  A unix filesystem formatted string. 
#              ID        A number value related to the id column of the
#                        database's file table.
#=======================================================================
update_flacdata () {
	local tsamples="\"$(metaflac --show-total-samples $2)\""
	local sample_rate="\"$(metaflac --show-sample-rate $2)\""
	local channels="\"$(metaflac --show-channels $2)\""
	local bps="\"$(metaflac --show-bps $2)\""
	local md5="\"$(metaflac --show-md5sum $2)\""
	shsql $1 $(printf 'UPDATE flac_streaminfo SET
		total_samples=%b, sample_rate=%b, channels=%b,
		bits_per_sample=%b, MD5_signature=%b WHERE file_id=%b;'\
		"$tsamples" "$sample_rate" "$channels" "$bps" "$md5" $3)
	[[ $? -ne 0 ]] && return 1
	local title="$(metaflac --show-tag=title $2)"
	title="${title##title=}"
	title=${title:-NULL} && [[ $title != NULL ]] && \
		title="\"$title\""
	local artist="$(metaflac --show-tag=artist $2)"
	artist="${artist##artist=}"
	artist=${artist:-NULL} && [[ $artist != NULL ]] && \
		artist="\"$artist\""
	local artistsort="$(metaflac --show-tag=artistsort $2)"
	artistsort="${artistsort##artistsort=}"
	artistsort=${artistsort:-NULL} && [[ $artistsort != NULL ]] && \
		artistsort="\"$artistsort\""
	local album="$(metaflac --show-tag=album $2)"
	album="${album##album=}"
	album=${album:-NULL} && [[ $album != NULL ]] && \
		album="\"$album\""
	local tracknumber="$(metaflac --show-tag=tracknumber $2)"
	tracknumber="${tracknumber##tracknumber=}"
	tracknumber=${tracknumber:-NULL} && [[ $tracknumber != NULL ]] && \
		tracknumber="\"$tracknumber\""
	local totaltracks="$(metaflac --show-tag=totaltracks $2)"
	totaltracks="${totaltracks##totaltracks=}"
	totaltracks=${totaltracks:-NULL} && [[ $totaltracks != NULL ]] && \
		totaltracks="\"$totaltracks\""
	shsql $1 $(printf 'UPDATE flac_comments SET title=%b, 
		artist=%b, artistsort=%b, album=%b, tracknumber=%b, 
		totaltracks=%b WHERE file_id=%b ;' "$title" "$artist" \
		"$artistsort" "$album" "$tracknumber" "$totaltracks" $3)
	[[ $? -ne 0 ]] && return 1
	local mbrz_albumid="$(metaflac --show-tag=musicbrainz_albumid $2)"
	mbrz_albumid="${mbrz_albumid##musicbrainz_albumid=}"
	mbrz_albumid=${mbrz_albumid:-NULL} && [[ $mbrz_albumid != NULL ]] \
	       	&& mbrz_albumid="\"$mbrz_albumid\""
	local mbrz_artistid="$(metaflac --show-tag=musicbrainz_artistid $2)"
	mbrz_artistid="${mbrz_artistid##musicbrainz_artistid=}"
	mbrz_artistid=${mbrz_artistid:-NULL} && [[ $mbrz_artistid != NULL ]] \
	       	&& mbrz_artistid="\"$mbrz_artistid\""
	local mbrz_albartid="$(metaflac --show-tag=musicbrainz_albumartistid $2)"
	mbrz_albartid="${mbrz_albartid##musicbrainz_albumartistid=}"
	mbrz_albartid=${mbrz_albartid:-NULL} && [[ $mbrz_albartid != NULL ]] \
	       	&& mbrz_albartid="\"$mbrz_albartid\""
	local mbrz_trackid="$(metaflac --show-tag=musicbrainz_trackid $2)"
	mbrz_trackid="${mbrz_trackid##musicbrainz_trackid=}"
	mbrz_trackid=${mbrz_trackid:-NULL} && [[ $mbrz_trackid != NULL ]] \
	       	&& mbrz_trackid="\"$mbrz_trackid\""
	shsql $1 $(printf 'UPDATE musicbrainz_ids SET albumid=%b, 
		artistid=%b, albumartistid=%b, trackid=%b WHERE 
		file_id=%b ;' "$mbrz_albumid" "$mbrz_artistid" \
		"$mbrz_albartid" "$mbrz_trackid" $3)
	[[ $? -ne 0 ]] && return 1
	return 0
}