install_standard_ckan_extension_github() {
    REPO_NAME="${1}"
    EGG="${2}"
    TEMPFILE=`mktemp`
    for REQUIREMENTS_FILE_NAME in requirements pip-requirements
    do
      if wget -O $TEMPFILE https://raw.githubusercontent.com/${REPO_NAME}/master/$REQUIREMENTS_FILE_NAME.txt
      then ckan-pip install -r $TEMPFILE && break; fi
    done &&\
    ckan-pip install -e git+https://github.com/${REPO_NAME}.git#egg=${EGG} && break
}

install_bundled_requirements() {
    ckan-pip install -r "/tmp/${1}"
}
