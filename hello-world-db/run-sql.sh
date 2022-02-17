#!/bin/bash

CMD_DIR=$(cd -P -- "$(dirname -- "$0")"; pwd -P)
echo "Directory Name is $CMD_DIR "
pushd "$CMD_DIR" > /dev/null

MYSQL_PASSWORD_NOT_DEFINED_ERROR=5
MYSQL_ERROR=3

pid=$$
dateStamp="$(date '+%Y%m%d')-${pid}"

#### FUNCTIONS #####
function usage(){
	cat <<-EOF
	Usage :
	$CMD [-h <DB Host> -u <DB Root User> ]

	 -h || --host  [ DB host.  Default value is "localhost" ]
	 -u || --user  [ DB Root User .  Default value is "root" ]
	 -e || --env   [ Environment to create. Used to share DB instance across environments.]
   -c || --clean  Drops the DB and recreates it from scratch.
   -v || --version [ Version to update or rollback to i.e. 19.9.0 ]
   -r || --rollback Rolls back to the specified version.
   -D || --dry-run Does not execute update queries
	 -H || --help

Example $CMD -h localhost -u root -e local

EOF
exit
}

### compare fisrt version with second version ver_cmp $v1 ${op:<|<=|=|>=|>} $v2
function ver_cmp() {
  local op
  if [ "${1}" == "${3}" ]; then
    op="="
  else
    local ver=`echo -ne "${1}\n${3}" | sort -V | head -n1`
    if [ "${3}" == "${ver}" ]; then
      op=">"
    else
      op="<"
    fi
  fi
  [[ ${2} == *${op}* ]] && return 0 || return 1
}

function _getDBVersion() {
  DB_VERSION=$(${MYSQL_CLIENT} -e "select rel from db_sql_rel where rel_status = 'D' order by INET_ATON(SUBSTRING_INDEX(CONCAT(rel, '.0.0.0.0'), '.',4)) desc LIMIT 1" | head -n2 | tail -n1 )
  if [ -z "${DB_VERSION}" ]; then
    DB_VERSION="0"
  fi
}

function update_rel_status() {
  local version=$1;shift
  local status=$1;shift
  local timeCol=$1;shift
  local files="$@"

  #escape for MySQL single string
  files=${files//\\/\\\\}
  files=${files//\'/\\\'}
  files=${files//\"/\\\"}

  if [ -n "${dryRunFlag}" ]; then
    echo "Dry Run for ${version} with ${status} and files ${files}"
    return
  fi

  ${MYSQL_CLIENT} <<EOS
    INSERT INTO db_sql_rel (rel, rel_status, last_status_details, ${timeCol}_ts)
    VALUES('${version}', '${status}', '${files}', CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE rel_status = VALUES(rel_status),
    last_status_details = VALUES(last_status_details),
    ${timeCol}_ts = CURRENT_TIMESTAMP;
EOS

}

function update_rel_detail_status() {
  local version=$1;shift
  local fileName=$1;shift
  local logFileName=$1;shift
  local timeCol=$1;shift

  if [ -n "${dryRunFlag}" ]; then
    echo "Dry Run for ${version} with ${fileName}"
    return
  fi

  local log=$(cat ${logFileName})
  #escape for MySQL single string
  log=${log//\\/\\\\}
  log=${log//\'/\\\'}
  log=${log//\"/\\\"}

  ${MYSQL_CLIENT} <<EOS
    INSERT INTO db_sql_rel_details
    (rel, file_name, run_details, ${timeCol}_ts)
    VALUES('${version}', '${fileName}', '${log}', CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE run_details = VALUES(run_details),
    ${timeCol}_ts = CURRENT_TIMESTAMP;
EOS

}

function runScripts() {
  local version=$1
  local FILES=()
  for f in $(find sql/${version} -name "${SQL_FILE_PREFIX}*.ddl" | sort); do
    FILES+=( ${f} )
  done
  for f in $(find sql/${version} -name "${SQL_FILE_PREFIX}*.sql" | sort); do
		SQL_TARGET=$(basename ${f})
    SQL_TARGET=${SQL_TARGET#*.}
    if [[ "${SQL_TARGET}" == "sql" || "${SQL_TARGET}" == "${TARGET_NAME}.sql" ]]; then
      FILES+=( ${f} )
    fi
  done
	if [[ "${SQL_FILE_PREFIX}" == "R" ]]; then
		local R_FILES=()
		for (( i=${#FILES[@]}-1; i>=0; i-- ));do
			R_FILES+=( ${FILES[i]} )
		done
		FILES=( "${R_FILES[@]}" )
	fi

  echo "Running Ver ${version} with files ${FILES[@]}"
  update_rel_status "${version}" "PENDING" "start" "${FILES[@]}"

  for sqlFile in "${FILES[@]}"; do
    local logFileSpec="/tmp/${version}_$(basename ${sqlFile})_${dateStamp}.log"
    cat <<EOF | tee -a ${logFileSpec}
    Directory Listing
EOF

    ls -l ${sqlFile}  | tee -a ${logFileSpec}

    update_rel_detail_status "${version}" "${sqlFile}" "${logFileSpec}" "start"

    if [ -n "${dryRunFlag}" ]; then
      cat <<EOF | tee -a ${logFileSpec}
----------------------------------------------------------------------------------------------------
[INFO]
Dry Run Mode

EOF
      cat <<EOF | tee -a ${logFileSpec}

File contents
EOF
      cat ${sqlFile} | grep -v '\-\-' | tee -a ${logFileSpec}

      cat <<EOF | tee -a ${logFileSpec}

Full SQL Command:
 ${MYSQL_CLIENT} ${forceSwitch} <  ${sqlFile}

EOF
    else

      startTime=$(date)
      startEpochSec=$(date +%s)
      echo "About to run file ${sqlFile}"
      cat <<EOF | tee -a ${logFileSpec}

----------------------------------------------------------------------------------------------------
[INFO]
Live Mode

SQL Start Time: ${startTime}

EOF

      cat <<EOF | tee -a ${logFileSpec}

${MYSQL_CLIENT} ${forceSwitch}  <  ${sqlFile}  > >(tee -a ${logFileSpec}) 2> >(tee  -a ${logFileSpec} >&2)

EOF

# execute the mysql cmd with the sql file
      ${MYSQL_CLIENT}  ${forceSwitch}  < ${sqlFile} > >(tee -a ${logFileSpec}) 2> >(tee  -a ${logFileSpec} >&2)
      status=$?

      endEpochSec=$(date +%s)

      durationSec=$(( ${endEpochSec} - ${startEpochSec} ))

      cat <<EOF | tee -a ${logFileSpec}

SQL Start Time: ${startTime}
SQL End Time:  $(date)

SQL Duration (sec): ${durationSec}

--------------------------------------------------------------------------------

EOF

# check exit status
# fail if non-zero
      if [ ${status} != 0 ]; then
        cat <<EOF | tee -a ${logFileSpec}
----------------------------------------------------------------------------------------------------
[ERROR]
mysql  Exit Error

SQL File: ${MYSQL_CLIENT} ${sqlFile}
mysql exit code: ${status}

EOF
        update_rel_detail_status "${version}" "${sqlFile}" "${logFileSpec}" "end"
        update_rel_status "${version}" "SQL_ERROR" "end" "${FILES[@]}
FAILED: ${sqlFile}"
        exit ${MYSQL_ERROR}
      fi
    fi
    update_rel_detail_status "${version}" "${sqlFile}" "${logFileSpec}" "end"
  done
  update_rel_status "${version}" "${SQL_FILE_PREFIX}" "end" "${FILES[@]}"
}


function _getDbaPassword () {

    # allow over-ride of DBA input for password
    [[ -n "${MYSQL_PWD}" ]] && {
	cat <<EOF
--------------------------------------------------------------------------------
[INFO]
  Using environment variable: ${MYSQL_PWD}

EOF
	} || {
	cat <<EOF
--------------------------------------------------------------------------------
Please enter the password for the DBA user ${USER}:

EOF

	read -s dbaPassword

	[[ -z "${dbaPassword}" ]] && {
	    cat <<EOF
--------------------------------------------------------------------------------
[ERROR]
    DBA Password is null

    Exit Status: ${MYSQL_PASSWORD_NOT_DEFINED_ERROR}

EOF
	    exit ${MYSQL_PASSWORD_NOT_DEFINED_ERROR}

    } || {

	    export MYSQL_PWD=${dbaPassword}
	   }
    }
}

##### MAIN #####
CMD=$(basename -- "$0")
HOST=""
USER=""
TARGET=""
TARGET_NAME=""
TARGET_VERSION=""
CLEAN_CMD=""
CREATE_DB=""
SQL_FILE_PREFIX="D"
dryRunFlag=

while [ $# -gt 0 ]; do
	case $1 in
		-H|--help)
			usage
			exit
		;;
    -D|--dry-run)
      dryRunFlag=1
      ;;
    -r|--rollback)
      SQL_FILE_PREFIX="R"
			;;
		-cdb|--clean-db)
      CREATE_DB="Yes"
			;;
		-c|--clean)
      CLEAN_CMD="Yes"
			;;
    -h|--host)
			shift
			HOST=$1
			;;
    -v|--version)
			shift
			TARGET_VERSION=$1
			;;
		-u|--user)
			shift
			USER=$1
		;;
		-e|--env)
			shift
			TARGET="_${1}"
      TARGET_NAME=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
		;;
	esac
	shift
done

if [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$TARGET" ] ; then
	usage
fi

if [ -z "${TARGET_VERSION}"]; then
  TARGET_VERSION=$(ls sql | sort -V  -r | head -1)
fi

DB_NAME=$(echo "notification_api${TARGET}" | tr '[:lower:]' '[:upper:]')

if [ ! -z "${CLEAN_CMD}" ]; then
  CLEAN_CMD="DROP DATABASE IF EXISTS ${DB_NAME};DROP USER IF EXISTS '${DB_USER}'@'%';"
fi

_getDbaPassword

if [[ "${DB_NAME}" == *"LOCAL_DB" || "${CREATE_DB}" == "Yes" ]]; then
	DB_USER=$(echo "${USER}" | tr '[:upper:]' '[:lower:]')
	mysql -h $HOST -u $USER <<EOS
  	${CLEAN_CMD}
		CREATE DATABASE IF NOT EXISTS ${DB_NAME};

		-- CREATE USER IF NOT EXISTS '${DB_USER}'@'%' Identified by '${DB_USER}';
		-- GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';

		-- FLUSH PRIVILEGES;
EOS
	RC=$?

	if [ "${RC}" -eq "0" ]; then
		echo  "Database ${DB_NAME} with user ${DB_USER} created successfully!"
		mysql -h $HOST -u ${DB_USER} -p${DB_USER} ${DB_NAME} <<EOS
		select 1
EOS
	else
	  echo "Failed creating the DB :(, exiting with code ${rc}..."
	  exit ${RC}
	fi
fi

MYSQL_CLIENT="mysql --user=${USER} --host=${HOST} --database=${DB_NAME}"

# Initialize DB if first time.
${MYSQL_CLIENT} <<EOS
  CREATE TABLE IF NOT EXISTS db_sql_rel (
    rel varchar(15) not null,
    rel_status varchar(50) not null,
    last_status_details longtext,
    start_ts TIMESTAMP,
    end_ts TIMESTAMP,
		creation_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		primary key (rel)
	) engine = InnoDB;

  CREATE TABLE IF NOT EXISTS db_sql_rel_details (
    rel varchar(15) not null,
    file_name varchar(255) not null,
    run_details longtext,
    start_ts TIMESTAMP,
    end_ts TIMESTAMP,
    creation_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    primary key (rel, file_name),
	  CONSTRAINT db_sql_rel_details_db_sql_rel_FK FOREIGN KEY (rel) REFERENCES db_sql_rel (rel)
	) ENGINE=InnoDB;

EOS
RC=$?

if [ ! "${RC}" -eq "0" ]; then
	echo "Failed creating the DB release tables:(, exiting with code ${rc}..."
	exit ${RC}
fi

_getDBVersion
echo "We found the DB at Version: ${DB_VERSION} with a target of ${TARGET_VERSION}"
if ver_cmp ${TARGET_VERSION} "<=" ${DB_VERSION} && [[ "${SQL_FILE_PREFIX}" == "D" ]]; then
  echo "DB is at ${DB_VERSION}, selected target is ${TARGET_VERSION}, nothing to upgrade!"
  exit 0
fi
if ver_cmp ${TARGET_VERSION} ">=" ${DB_VERSION} && [[ "${SQL_FILE_PREFIX}" == "R" ]]; then
  echo "DB is at ${DB_VERSION}, selected target is ${TARGET_VERSION}, nothing to rollback!"
  exit 0
fi

RELEASES=( )
if [[ "${SQL_FILE_PREFIX}" == "R" ]]; then
  for ver in $(ls sql | sort -V  -r); do
    if ver_cmp ${DB_VERSION} ">=" ${ver} && ver_cmp ${TARGET_VERSION} "<" ${ver}; then
      RELEASES+=( "${ver}" )
    fi
  done
  echo "Rolling back ${RELEASES[@]}"
elif [[ "${SQL_FILE_PREFIX}" == "D" ]]; then
  for ver in $(ls sql | sort -V ); do
    if ver_cmp ${DB_VERSION} "<" ${ver} && ver_cmp ${TARGET_VERSION} ">=" ${ver}; then
      RELEASES+=( "${ver}" )
    fi
  done
  echo "Upgrading ${RELEASES[@]}"
else
  echo "Unknown request ${SQL_FILE_PREFIX}"
  exit 1
fi

for ver in ${RELEASES[@]}; do
  runScripts ${ver}
done

_getDBVersion
echo "DB ${DB_NAME} is now at ${DB_VERSION}"

popd > /dev/null
