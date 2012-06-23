#! /bin/bash

# dir2tar.bash (See description below).
# Copyright (C) 2012  Marcelo Javier Auquer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#        USAGE: See function usage below.
#
#  DESCRIPTION: Create a tar archive named NAME and include in it the
#               files founded in pathname...
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               backupdb.flib
#               getoptx.bash
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/code/bash/backupdb/backupdb.flib
source ~/code/bash/backupdb/getoptx/getoptx.bash


#===  FUNCTION =========================================================
#
#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.
#
usage () {
	cat <<- EOF
	Usage: dir2tar TAR_NAME pathname...
	dir2tar --listed-in TEXT_FILE TAR_NAME

	Create a tar archive named NAME and include in it the
	files founded in pathname...
	EOF
}

#===  FUNCTION =========================================================
#
#       USAGE: error_exit [MESSAGE]
#
# DESCRIPTION: Function for exit due to fatal program error.
#
#   PARAMETER: MESSAGE An optional description of the error.
#
error_exit () {
	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	[ -v handle ] && shsqlend $handle
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# Variables declaration.
declare progname=$(basename $0)

declare -a pathnames # A list of the pathnames of the files and
                     # directories that have been passed to this script.

declare txtfile      # The pathname of the file passed as argument to
                     # the --listed-in option.

declare -a notfound  # A list of pathnames passed as arguments to this
                     # script and that do not point to existing files or
		     # directories in the filesystem.

declare tempdir      # The pathname of a temporal directory where the
                     # files and directories will be processed.

declare handle       # Required by shsql. A connection to the database.

declare -a regfiles  # Same as pathnames variable, but only contains
                     # the pathnames that point to regular files.

declare tarfile      # The pathname of the tar file to be created.

declare archiver_id  # The id number in the file table of the database
                     # of the created tar file.

declare archived_id  # The id number in the file table of the database
                     # of a file archived in the tar file.

# If no argument were passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Parse command line options.
while getoptex "listed-in:" "$@"
do
	case "$OPTOPT" in
		listed-in) txtfile="$OPTARG"
		            ;;
	esac
done
if [ "$txtfile" ]
then
	if [ -a $(readlink -f "$txtfile") ]
	then
		while read line
		do
			[[ $line =~ Total:.* ]] && continue
			pathnames+=( "$line" )
		done < $(readlink -f "$txtfile")
	else
            	error_exit "$LINENO: $txtfile not found."
	fi
fi
shift $(($OPTIND-1))

# Add to the list of pathnames to be processed, those which were passed
# as command line arguments.
pathnames+=( ${@:2} )

# Check the existence of the files passed as arguments.
for pathname in ${pathnames[@]}
do
	if [ \( ! -d $pathname \) -a \( ! -f $pathname \) ]
	then
		notfound+=("$pathname")
	fi
done
if [ ${#notfound[@]} -ne 0 ]
then
	error_exit "$LINENO: The following arguments do not exist as
regular files or directories in the filesystem:
$(for file in ${notfound[@]}; do echo "$file"; done)"
fi

# Check if the pathname of the output tar file is a valid one.
if [[ $1 =~ .*/$ ]]
then
	error_exit "$LINENO: First arg must be a regular filename."
fi

# Check if the specified output tar file already exists in the working
# directory.
if [ -f $1 ]
then
	error_exit "$LINENO: $1 already exists in $(pwd)."
fi

# Create a temporary directory and move into it all the files and
# directories to be archived.
tempdir=$(mktemp -d tmp.XXX)
chmod 755 $tempdir
mv ${pathnames[@]} $tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mv command."
fi
cd $tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cd command."
fi

# Create a tar file.
pathnames=( $(find $(ls)) )
tar -cf $1 ${pathnames[@]}
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling tar utility."
fi

# Update the backup database.
backupdb -r .
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling backupdb."
fi

#-----------------------------------------------------------------------
# Update the backup database with the archive relationships.
#-----------------------------------------------------------------------

# Connect to the database.
handle=$(shmysql user=$BACKUPDB_USER password=$BACKUPDB_PASSWORD \
	dbname=$BACKUPDB_DBNAME) 
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling shmysql utility."
fi

# Get the id of the created tar file.
tarfile="$(readlink -f $1)"
get_id $handle archiver_id $(hostname) $tarfile
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling get_id()."
fi

# Make a list of the regular files that have been archived.
for pathname in ${pathnames[@]}
do
	pathname=$(readlink -f $pathname)
	if [ -f $pathname ]
	then
		regfiles+=( $pathname )
	fi
done
unset -v pathname

# Insert archive relationships between the tar file and its content.
for file in ${regfiles[@]}
do
	# Get the id of the archived file.
	get_id $handle archived_id $(hostname) $file
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling get_id()."
	fi

	# Insert the archive relationship.
	insert_archive $handle $archiver_id $archived_id
	if [ $? -ne 0 ]
	then
		error_exit "$LINENO: Error after calling insert_archive()."
	fi
done
unset -v file

#-----------------------------------------------------------------------
# Remove the temporary directory.
#-----------------------------------------------------------------------

mv $1 ..
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mv command."
fi
cd ..
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cd command."
fi
rm -r $tempdir
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling rm command."
fi

#-----------------------------------------------------------------------
# Update the backup database with this last movement.
#-----------------------------------------------------------------------

# Update the pathname of the tar file.
shsql $handle $(printf 'UPDATE file SET pathname="%b" WHERE id=%b;' \
	$(readlink -f $1) $archiver_id)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# This will reflect in the database the deletion of the temporal
# directory.
backupdb -r .
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error while trying to update the database."
fi

# Close the connection to the database.
shsqlend $handle
