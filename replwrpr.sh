#!/QOpenSys/pkgs/bin/bash

set -e

usage="$(basename "$0") [-h] [-s SNIPPET_NAME] [-n SESSION_NAME] [-l LIBRARY_NAME] [-f FILE_NAME] [-m MEMBER_NAME] [-v] [-w] [-x]
Provide details of how to run a particular snippet, and how the results should be returned:
    -h          show this help text
    -s          snippet name from rpgle-repl
    -l, -f, -m  library, file, and member within which to find executable code
    -n          session name to store the results under
    -v          add a test result summary, excluding this will return only a 0 or -1 result for success or failure
    -w          like -v, but with individual test results printed
    -x          like -w, but with the full compiler printout"

verbosity=0

while getopts ":hs:l:f:m:n:vwx" option; do
    case "$option" in
        h) echo "$usage"; exit;;
        s) snippet_name=$OPTARG;;
        l) library_name=$OPTARG;;
        f) file_name=$OPTARG;;
        m) member_name=$OPTARG;;
        n) session_name=$OPTARG;;
        v) verbosity=1;;
        w) verbosity=2;;
        x) verbosity=3;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2; echo "$usage" >&2; exit 1;;
        :) printf "missing argument for -%s\n" "$OPTARG" >&2; echo "$usage" >&2; exit 1;;
    esac
done

# system_cmd="/QOpenSys/usr/bin/system"
system_cmd="system"

if [ -n "$snippet_name" ]; then
  this_request="$snippet_name"
else 
  this_request="$library_name/$file_name/$member_name"
fi

if [ "$verbosity" -gt 0 ]; then
    echo "** submitting build task for $this_request"
fi

if [ -n "$session_name" ]; then
  thesessionid="$session_name"
else
  thesessionid=$(getjobid | sed 's/.* is //')
fi

if [ "$verbosity" -ge 3 ]; then 
    $system_cmd "REPLWRPR LIB('$library_name') FIL('$file_name') MBR('$member_name') SNP('$snippet_name') STD('$verbosity') SES('$thesessionid')"
else
    $system_cmd "REPLWRPR LIB('$library_name') FIL('$file_name') MBR('$member_name') SNP('$snippet_name') STD('$verbosity') SES('$thesessionid')" > /dev/null
fi

if [ "$verbosity" -gt 0 ]; then
    echo "** build and run complete for snippet, fetching results"
fi

$system_cmd "REPLPRTR STD('$verbosity') SES('$thesessionid')"
