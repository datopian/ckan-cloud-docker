install_standard_ckan_extension_github() {
    ### Help ###
      # -r: RepoName
      # -b: BranchName (Optional. If not specified, it defaults to Master)
      # -e: EGG (Optional. If not specified, it gets extracted from RepoName)
      # Usage:
      # install_standard_ckan_extension_github -r [repo/name] -b [optional] -e [optional]

    # By default, the master branch is used unless specified otherwise
    BRANCH="master"
    while getopts ":r:b:e:" options; do
      case ${options} in
        r) REPO_NAME=${OPTARG}
           # By default, EGG is part of REPO_NAME
           EGG=$(echo $REPO_NAME | cut -d / -f 2)
        ;;
        b) BRANCH=${OPTARG:=$BRANCH};;
        # If -e option is specified, it overrides the default stated above
        e) EGG=${OPTARG};;
      esac
    done
#    echo "#### REPO: $REPO_NAME ####"
#    echo "#### BRANCH: $BRANCH ####"
#    echo "#### EGG: $EGG ####"

    TEMPFILE=`mktemp`
    for REQUIREMENTS_FILE_NAME in requirements pip-requirements
    do
      if wget -O $TEMPFILE https://raw.githubusercontent.com/${REPO_NAME}/$BRANCH/$REQUIREMENTS_FILE_NAME.txt
        then ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -r $TEMPFILE && break;
      fi
    done &&\
    ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -e git+https://github.com/${REPO_NAME}.git@$BRANCH#egg=${EGG} && break
}

install_bundled_requirements() {
    ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -r "/tmp/${1}"
}

patch_ckan() {
  for d in /etc/patches/*; do
    for f in `ls $d/*.patch | sort -g`; do
      cd /usr/lib/ckan/venv/src/`basename "$d"` && echo "$0: Applying patch $f to /usr/lib/ckan/venv/src/`basename $d`"; patch -p1 < "$f" ;
    done;
  done;
}
