install_standard_ckan_extension_github() {
    REPO_NAME="${1}"
    BRANCH=""
    # EGG is part of REPO_NAME
    EGG=$(printf $REPO_NAME | cut -d / -f 2) 
    # Use default value for branch if none specified
    if [ $2 ]; then
      BRANCH="@${2}"
    fi
    echo "############  Selected branch: $BRANCH #########"
    TEMPFILE=`mktemp`
    for REQUIREMENTS_FILE_NAME in requirements pip-requirements
    do
      if wget -O $TEMPFILE https://raw.githubusercontent.com/${REPO_NAME}/master/$REQUIREMENTS_FILE_NAME.txt
        then ckan-pip install -r $TEMPFILE && break;
      fi
    done &&\
    ckan-pip install -e git+https://github.com/${REPO_NAME}.git$BRANCH#egg=${EGG} && break
}

install_bundled_requirements() {
    ckan-pip install -r "/tmp/${1}"
}
