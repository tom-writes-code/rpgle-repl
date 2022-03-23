#!/QOpenSys/pkgs/bin/bash

# Installation script to install rpgle-repl
# =========================================
#
# Limitations:
#  - You will likely need elevated authorities to run this script
#  - If you use IASPs, I'm afraid you're on your own

set -euo pipefail

function show_help {
    local script=`basename $0`
    echo "Usage: $script [-v] [-f|--force] [--version VERSION] [--app-lib LIBRARY] [--download-lib LIBRARY]" 
    echo "       $script [-h|--help]"
    echo ""
    echo "    -h|--help"
    echo "        Usage information"
    echo "    -v|--verbose"
    echo "        Extra logging for debugging"
    echo "    -f|--force"
    echo "        Overwrite existing application library, if exists"
    echo "    --version"
    echo "        Application version to install"
    echo "        Default: 'latest'"
    echo "    --app-lib"
    echo "        Target library for app installation"
    echo "        Default: 'RPGREPL'"
    echo "    --download-lib"
    echo "        Library to receive downloaded REPL save file"
    echo "        Default: 'QGPL'"

}

system_cmd="/QOpenSys/usr/bin/system"


#####################
# Argument processing
#####################

while [[ $# -gt 0 ]]
do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            verbose=1
            shift
            ;;
        -f|--force)
            force=1
            shift
            ;;
        --version)
            [[ $# -lt 2 ]] && show_help && exit 1
            version=$2
            shift 2
            ;;
        --app-lib)
            [[ $# -lt 2 ]] && show_help && exit 1
            app_lib=$2
            shift 2
            ;;
        --download-lib)
            [[ $# -lt 2 ]] && show_help && exit 1
            savf_lib=$2
            shift 2
            ;;
        -*)
            echo "Unsupported option: $1"
            show_help
            exit 1
            ;;
        *) # Anything else: assume position-based argument
            set -A positional "${positional[@]}" "$1"
            shift 
            ;;
    esac
done

set -- "${positional[@]}" # restore positional parameters

if [[ ${verbose:-0} -eq 1 ]]; then
    system_cmd="$system_cmd -v"
    set -x
fi

verbose=${verbose:-0}
force=${force:-0}
version=${version:-latest}
app_lib=${app_lib:-RPGREPL}
app_lib=${app_lib^^}
savf_lib=${savf_lib:-QGPL}
savf_lib=${savf_lib^^}
savf_name=RPGLEREPL


echo "** =============================="
echo "** rpgle-repl Installation Script"
echo "** =============================="
echo "**"


############
# Validation
############
if [[ ! -d /QSYS.LIB/${savf_lib}.LIB ]]; then
    >&2 echo "!! Save File download library, ${savf_lib}, does not exist!"
    exit 2
fi

if [[ -d /QSYS.LIB/${app_lib}.LIB && $force -eq 0 ]]; then
    >&2 echo "!! Application library, ${app_lib}, exists! Manually remove/backup, or specify --force to overwrite" 
    exit 3
fi
################
# End Validation
################


echo "** Version to install: ${version}"

if [[ "$version" = latest ]]; then
    version=$(git ls-remote --tags  https://github.com/tom-writes-code/rpgle-repl.git |
        cut -d/ -f3- |
        tail -n1 )
    echo "**   -> Latest version is ${version}"
fi

echo "**"
echo "** Downloading package to ${savf_lib}/${savf_name}..."

download_url="https://github.com/tom-writes-code/rpgle-repl/releases/download/${version}/RPGLEREPL.FILE"
download_target="/QSYS.LIB/${savf_lib}.LIB/${savf_name}.FILE"

/QOpenSys/pkgs/bin/wget --no-verbose --show-progress "$download_url" -O "$download_target"

echo "** Download complete."
echo "**"
echo -n "** Checking if target application library ${app_lib} exists... "

if [[ -d "/QSYS.LIB/${app_lib}.LIB" && $force -eq 1 ]]; then
    echo "present."
    echo -n "** Deleting library ${app_lib}... "
    $system_cmd "DLTLIB LIB(${app_lib})" > /dev/null
    echo "done."
else
    echo "absent."
fi

echo -n "** Creating application library ${app_lib}... "
$system_cmd "CRTLIB LIB(${app_lib}) TEXT('REPL tool for ILE RPG snippets') AUT(*ALL) CRTAUT(*ALL)" > /dev/null
echo "done."

echo -n "** Restoring save file... "
$system_cmd "RSTOBJ OBJ(*ALL) SAVLIB(REPLBOB) DEV(*SAVF) SAVF(${savf_lib}/${savf_name}) ALWOBJDIF(*COMPATIBLE) RSTLIB(${app_lib})" > /dev/null
echo "done."

echo -n "** Configuring product library on REPL command... "
$system_cmd "CHGCMD CMD(${app_lib}/REPL) PRDLIB(${app_lib})" > /dev/null
echo "done."

echo -n "** Recording version... "
echo -n "$version" > "/QSYS.LIB/${app_lib}.LIB/VERSION.USRSPC"
echo "done."


###########
# All done.
###########
echo "**"
echo "** Installation complete."
echo "**"
echo "** To use, run ${app_lib}/REPL from the IBM i command line."
