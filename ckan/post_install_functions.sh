install_standard_ckan_extension_github() {
    ### Help ###
      # -r: RepoName
      # -b: BranchName (Optional. If not specified, it defaults to Master)
      # -e: EGG (Optional. If not specified, it gets extracted from RepoName)
      # Usage:
      # install_standard_ckan_extension_github -r [repo/name] -b [optional] -e [optional]

    # By default, the master branch is used unless specified otherwise
    BRANCH="master"
    GITHUB_URL=${GITHUB_URL:-https://github.com}
    PIP_INDEX_URL=${PIP_INDEX_URL:-https://pypi.org/simple/}

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

    echo "#### REPO: $REPO_NAME ####"
    echo "#### BRANCH: $BRANCH ####"
    echo "#### REPO URL: $GITHUB_URL/$REPO_NAME.git ####"

    BRANCH_EXISTS=$(git ls-remote --heads ${GITHUB_URL}/${REPO_NAME}.git ${BRANCH})

    if [ -z "$BRANCH_EXISTS" ]; then
      BRANCH_EXISTS=$(git ls-remote --tags ${GITHUB_URL}/${REPO_NAME}.git ${BRANCH})

      if [ -z "$BRANCH_EXISTS" ]; then
        BRANCH_EXISTS=$(git ls-remote ${GITHUB_URL}/${REPO_NAME}.git | grep -o ${BRANCH})
      fi
    fi

    if [ -z "$BRANCH_EXISTS" ]; then
      echo "#### BRANCH EXISTS: $BRANCH_EXISTS ####"

      if [ "$BRANCH" = "master" ]; then
        BRANCH_EXISTS=$(git ls-remote --heads ${GITHUB_URL}/${REPO_NAME}.git main)
        if [ -n "$BRANCH_EXISTS" ]; then
          echo "Branch 'master' not found, switching to 'main'."
          BRANCH="main"
        else
          echo "Branch 'master' not found, and 'main' also does not exist."
          exit 1
        fi
      else
        echo "Branch '$BRANCH' not found. Please check the branch name."
        exit 1
      fi
    fi

    if [ $PIP_INDEX_URL != https://pypi.org/simple/ ]; then
      TMPDIR=${CKAN_VENV}/src/${EGG}
      git clone -b $BRANCH ${GITHUB_URL}/${REPO_NAME}.git ${TMPDIR}

      for REQUIREMENTS_FILE_NAME in requirements pip-requirements
      do
        if [ -f ${TMPDIR}/$REQUIREMENTS_FILE_NAME.txt ]; then
          ckan-pip install --index-url ${PIP_INDEX_URL} -r ${TMPDIR}/$REQUIREMENTS_FILE_NAME.txt && break;
        fi
      done &&\
      ckan-pip install --no-use-pep517 --index-url ${PIP_INDEX_URL} -e ${TMPDIR}
    else
      # Remove poetry files: ckan-cloud-docker currently has issues with poetry dependencies
      if [ "${REPO_NAME}" = "datopian/ckanext-sentry" ]; then
        TMPDIR=${CKAN_VENV}/src/${EGG}
        git clone -b $BRANCH ${GITHUB_URL}/${REPO_NAME}.git ${TMPDIR}

        CURRENT_DIR=$(pwd)

        cd ${TMPDIR}

        if [ -f "poetry.lock" ] && [ -f "pyproject.toml" ]; then
          rm -f "poetry.lock" "pyproject.toml"
        fi

        for REQUIREMENTS_FILE_NAME in requirements pip-requirements
        do
          if [ -f ${TMPDIR}/$REQUIREMENTS_FILE_NAME.txt ]; then
            ckan-pip install --index-url ${PIP_INDEX_URL} -r ${TMPDIR}/$REQUIREMENTS_FILE_NAME.txt && break;
          fi
        done

        ckan-pip install --no-use-pep517 --index-url ${PIP_INDEX_URL} -e ${TMPDIR}

        cd ${CURRENT_DIR}

      else
        TEMPFILE=`mktemp`
        for REQUIREMENTS_FILE_NAME in requirements pip-requirements
        do
          if wget -O $TEMPFILE https://raw.githubusercontent.com/${REPO_NAME}/$BRANCH/$REQUIREMENTS_FILE_NAME.txt
            then ckan-pip install --index-url ${PIP_INDEX_URL} -r $TEMPFILE && break;
          fi
        done &&\
        ckan-pip install --no-use-pep517 --index-url ${PIP_INDEX_URL} -e git+${GITHUB_URL}/${REPO_NAME}.git@$BRANCH#egg=${EGG}
      fi
    fi
}

install_bundled_requirements() {
    ckan-pip install --index-url ${PIP_INDEX_URL} -r "/tmp/${1}"
}

patch_ckan() {
  for d in /etc/patches/*; do
    for f in `ls $d/*.patch | sort -g`; do
      cd /usr/lib/ckan/venv/src/`basename "$d"` && echo "$0: Applying patch $f to /usr/lib/ckan/venv/src/`basename $d`"; patch -p1 < "$f" ;
    done;
  done;
}
