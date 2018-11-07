# https://github.com/johanhaleby/bash-templater/commit/5ac655d554238ac70b08ee4361d699ea9954c941
readonly PROGNAME=$(basename $0)
config_file="<none>"
print_only="false"
silent="false"
[ $# -eq 0 ] && exit 1
[[ ! -f "${1}" ]] && exit 1
template="${1}"
if [ "$#" -ne 0 ]; then
    while [ "$#" -gt 0 ]
    do
        case "$1" in
        -p|--print)
            print_only="true"
            ;;
        -f|--file)
            config_file="$2"
            ;;
        -s|--silent)
            silent="true"
            ;;
        --)
            break
            ;;
        -*)
            exit 1
            ;;
        *)  ;;
        esac
        shift
    done
fi
vars=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "${template}" | sort | uniq | sed -e 's/^{{//' -e 's/}}$//')
if [[ -z "$vars" ]]; then
    if [ "$silent" == "false" ]; then
        echo "Warning: No variable was found in ${template}, syntax is {{VAR}}" >&2
    fi
fi
if [ "${config_file}" != "<none>" ]; then
    if [[ ! -f "${config_file}" ]]; then
      echo "The file ${config_file} does not exists" >&2
      echo "$usage"
      exit 1
    fi
    tmpfile=`mktemp`
    sed -e "s;\&;\\\&;g" -e "s;\ ;\\\ ;g" "${config_file}" > $tmpfile
    source $tmpfile
fi
var_value() {
    eval echo \$$1
}
replaces=""
defaults=$(grep -oE '^\{\{[A-Za-z0-9_]+=.+\}\}' "${template}" | sed -e 's/^{{//' -e 's/}}$//')
for default in $defaults; do
    var=$(echo "$default" | grep -oE "^[A-Za-z0-9_]+")
    current=`var_value $var`
    if [[ -z "$current" ]]; then
        eval $default
    fi
    replaces="-e '/^{{$var=/d' $replaces"
    vars="$vars
$current"
done
vars=$(echo $vars | sort | uniq)
if [[ "$print_only" == "true" ]]; then
    for var in $vars; do
        value=`var_value $var`
        echo "$var = $value"
    done
    exit 0
fi
for var in $vars; do
    value=`var_value $var`
    if [[ -z "$value" ]]; then
        if [ $silent == "false" ]; then
            echo "Warning: $var is not defined and no default is set, replacing by empty" >&2
        fi
    fi
    value=$(echo "$value" | sed 's/\//\\\//g');
    replaces="-e 's/{{$var}}/${value}/g' $replaces"
done
escaped_template_path=$(echo $template | sed 's/ /\\ /g')
eval sed $replaces "$escaped_template_path"
