#!/bin/sh

# nanopolish index wrapper script


###############################################################################
#### Helper Functions ####
###############################################################################

## MODIFY >>> *****************************************************************
## Usage description should match command line arguments defined below
usage () {
    echo "Usage: $(basename "$0")"
    echo "  --reads => Input Reads File"
    echo "  --summary => Input Sequencing Summary File"
    echo "  --fast5 => Input Fast5 Directory"
    echo "  --output => Output Directory"
    echo "  --exec_method => Execution method (singularity, auto)"
    echo "  --help => Display this help message"
}
## ***************************************************************** <<< MODIFY

# report error code for command
safeRunCommand() {
    cmd="$@"
    eval "$cmd"
    ERROR_CODE=$?
    if [ ${ERROR_CODE} -ne 0 ]; then
        echo "Error when executing command '${cmd}'"
        exit ${ERROR_CODE}
    fi
}

# print message and exit
fail() {
    msg="$@"
    echo "${msg}"
    usage
    exit 1
}

# always report exit code
reportExit() {
    rv=$?
    echo "Exit code: ${rv}"
    exit $rv
}

trap "reportExit" EXIT

# check if string contains another string
contains() {
    string="$1"
    substring="$2"

    if test "${string#*$substring}" != "$string"; then
        return 0    # $substring is not in $string
    else
        return 1    # $substring is in $string
    fi
}



###############################################################################
## SCRIPT_DIR: directory of current script, depends on execution
## environment, which may be detectable using environment variables
###############################################################################
if [ -z "${AGAVE_JOB_ID}" ]; then
    # not an agave job
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
else
    echo "Agave job detected"
    SCRIPT_DIR=$(pwd)
fi
## ****************************************************************************



###############################################################################
#### Parse Command-Line Arguments ####
###############################################################################

getopt --test > /dev/null
if [ $? -ne 4 ]; then
    echo "`getopt --test` failed in this environment."
    exit 1
fi

## MODIFY >>> *****************************************************************
## Command line options should match usage description
OPTIONS=
LONGOPTIONS=help,exec_method:,reads:,summary:,fast5:,output:,
## ***************************************************************** <<< MODIFY

# -temporarily store output to be able to check for errors
# -e.g. use "--options" parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(\
    getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@"\
)
if [ $? -ne 0 ]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    usage
    exit 2
fi

# read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

## MODIFY >>> *****************************************************************
## Set any defaults for command line options
EXEC_METHOD="auto"
## ***************************************************************** <<< MODIFY

## MODIFY >>> *****************************************************************
## Handle each command line option. Lower-case variables, e.g., ${file}, only
## exist if they are set as environment variables before script execution.
## Environment variables are used by Agave. If the environment variable is not
## set, the Upper-case variable, e.g., ${FILE}, is assigned from the command
## line parameter.
while true; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --reads)
            if [ -z "${reads}" ]; then
                READS=$2
            else
                READS=${reads}
            fi
            shift 2
            ;;
        --summary)
            if [ -z "${summary}" ]; then
                SUMMARY=$2
            else
                SUMMARY=${summary}
            fi
            shift 2
            ;;
        --fast5)
            if [ -z "${fast5}" ]; then
                FAST5=$2
            else
                FAST5=${fast5}
            fi
            shift 2
            ;;
        --output)
            if [ -z "${output}" ]; then
                OUTPUT=$2
            else
                OUTPUT=${output}
            fi
            shift 2
            ;;
        --exec_method)
            if [ -z "${exec_method}" ]; then
                EXEC_METHOD=$2
            else
                EXEC_METHOD=${exec_method}
            fi
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option"
            usage
            exit 3
            ;;
    esac
done
## ***************************************************************** <<< MODIFY

## MODIFY >>> *****************************************************************
## Log any variables passed as inputs
echo "Reads: ${READS}"
echo "Summary: ${SUMMARY}"
echo "Fast5: ${FAST5}"
echo "Output: ${OUTPUT}"
echo "Execution Method: ${EXEC_METHOD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Validate and Set Variables ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add app-specific logic for handling and parsing inputs and parameters

# READS input

if [ -z "${READS}" ]; then
    echo "Input Reads File required"
    echo
    usage
    exit 1
fi
# make sure READS is staged
count=0
while [ ! -f "${READS}" ]
do
    echo "${READS} not staged, waiting..."
    sleep 1
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f "${READS}" ]; then
    echo "Input Reads File not found: ${READS}"
    exit 1
fi
READS_FULL=$(readlink -f "${READS}")
READS_DIR=$(dirname "${READS_FULL}")
READS_BASE=$(basename "${READS_FULL}")


# SUMMARY input

if [ -z "${SUMMARY}" ]; then
    echo "Input Sequencing Summary File required"
    echo
    usage
    exit 1
fi
# make sure SUMMARY is staged
count=0
while [ ! -f "${SUMMARY}" ]
do
    echo "${SUMMARY} not staged, waiting..."
    sleep 1
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f "${SUMMARY}" ]; then
    echo "Input Sequencing Summary File not found: ${SUMMARY}"
    exit 1
fi
SUMMARY_FULL=$(readlink -f "${SUMMARY}")
SUMMARY_DIR=$(dirname "${SUMMARY_FULL}")
SUMMARY_BASE=$(basename "${SUMMARY_FULL}")


# FAST5 input

if [ -z "${FAST5}" ]; then
    echo "Input Fast5 Directory required"
    echo
    usage
    exit 1
fi
# make sure FAST5 is staged
count=0
while [ ! -d "${FAST5}" ]
do
    echo "${FAST5} not staged, waiting..."
    sleep 1
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -d "${FAST5}" ]; then
    echo "Input Fast5 Directory not found: ${FAST5}"
    exit 1
fi
FAST5_FULL=$(readlink -f "${FAST5}")
FAST5_DIR=$(dirname "${FAST5_FULL}")
FAST5_BASE=$(basename "${FAST5_FULL}")



# OUTPUT parameter
if [ -n "${OUTPUT}" ]; then
    :
    OUTPUT_FULL=$(readlink -f "${OUTPUT}")
    OUTPUT_DIR=$(dirname "${OUTPUT_FULL}")
    OUTPUT_BASE=$(basename "${OUTPUT_FULL}")
    LOG_FULL="${OUTPUT_DIR}/_log"
    TMP_FULL="${OUTPUT_DIR}/_tmp"
else
    :
    echo "Output Directory required"
    echo
    usage
    exit 1
fi


## ***************************************************************** <<< MODIFY

## EXEC_METHOD: execution method
## Suggested possible options:
##   auto: automatically determine execution method
##   package: binaries packaged with the app
##   cdc-shared-package: binaries centrally located at the CDC
##   singularity: singularity image packaged with the app
##   cdc-shared-singularity: singularity image centrally located at the CDC
##   docker: docker containers from docker-hub
##   environment: binaries available in environment path
##   module: environment modules

## MODIFY >>> *****************************************************************
## List supported execution methods for this app (space delimited)
exec_methods="singularity auto"
## ***************************************************************** <<< MODIFY

# make sure the specified execution method is included in list
if ! contains " ${exec_methods} " " ${EXEC_METHOD} "; then
    echo "Invalid execution method: ${EXEC_METHOD}"
    echo
    usage
    exit 1
fi



###############################################################################
#### Auto-Detect Execution Method ####
###############################################################################

# assign to new variable in order to auto-detect after Agave
# substitution of EXEC_METHOD
AUTO_EXEC=${EXEC_METHOD}
## MODIFY >>> *****************************************************************
## Add app-specific paths to detect the execution method.
if [ "${EXEC_METHOD}" = "auto" ]; then
    # detect if singularity available
    if command -v singularity >/dev/null 2>&1; then
        SINGULARITY=yes
    else
        SINGULARITY=no
    fi

    # detect if docker available
    if command -v docker >/dev/null 2>&1; then
        DOCKER=yes
    else
        DOCKER=no
    fi

    # detect execution method
    if [ "${SINGULARITY}" = "yes" ]; then
        AUTO_EXEC=singularity
    else
        echo "Valid execution method not detected"
        echo
        usage
        exit 1
    fi
    echo "Detected Execution Method: ${AUTO_EXEC}"
fi
## ****************************************************************************



###############################################################################
#### App Execution Preparation, Common to all Exec Methods ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to prepare environment for execution
MNT=""; ARG=""; CMD0="mkdir -p ${OUTPUT_FULL} ${ARG}"; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
MNT=""; ARG=""; CMD0="mkdir -p ${LOG_FULL} ${ARG}"; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
## ***************************************************************** <<< MODIFY



###############################################################################
#### App Execution, Specific to each Exec Method ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to execute app
## There should be one case statement for each item in $exec_methods
case "${AUTO_EXEC}" in
    singularity)
        MNT=""; ARG=""; ARG="${ARG} -p"; MNT="${MNT} -B "; MNT="${MNT}\"${OUTPUT_DIR}:/data1\""; ARG="${ARG} \"/data1/${OUTPUT_BASE}/${OUTPUT_BASE}\""; ARG="${ARG} -d"; MNT="${MNT} -B "; MNT="${MNT}\"${FAST5_DIR}:/data2\""; ARG="${ARG} \"/data2/${FAST5_BASE}\""; ARG="${ARG} -s"; ARG="${ARG} \"${SUMMARY}\""; CMD0="singularity -s exec ${MNT} docker://quay.io/biocontainers/nanopolish:0.11.1--h99ef0c4_0 nanopolish index ${ARG}"; CMD0="${CMD0} >\"${LOG_FULL}/${OUTPUT_BASE}-nanopolish-index.stdout\""; CMD0="${CMD0} 2>\"${LOG_FULL}/${OUTPUT_BASE}-nanopolish-index.stderr\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
        ;;
esac
## ***************************************************************** <<< MODIFY



###############################################################################
#### Cleanup, Common to All Exec Methods ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to cleanup execution artifacts, if necessary
## ***************************************************************** <<< MODIFY

