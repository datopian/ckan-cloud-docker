install_standard_ckan_extension_github() {
    REPO_NAME="${1}"
    EGG="${2}"
    TEMPFILE=`mktemp`
    if wget -O $TEMPFILE https://raw.githubusercontent.com/${REPO_NAME}/master/pip-requirements.txt
    then ckan-pip install -r $TEMPFILE; fi &&\
    ckan-pip install -e git+https://github.com/${REPO_NAME}.git#egg=${EGG}
}

install_bundled_requirements() {
    ckan-pip install -r "/tmp/${1}"
}
