DOCKER_IMAGE=viderum/ckan-cloud-docker
BUILD_APPS="ckan cca-operator jenkins nginx db solr"
BUILD_CKAN_OVERRIDES="1"
BUILD_SOLR_OVERRIDES="1"

touch docker-compose/ckan-secrets.sh docker-compose/datastore-db-secrets.sh docker-compose/db-secrets.sh docker-compose/provisioning-api-db-secrets.sh docker-compose/provisioning-api-secrets.sh

exec_build_apps() {
    for APP in $BUILD_APPS; do
        APP_LATEST_IMAGE="${DOCKER_IMAGE}:${APP}-latest"
        ! eval "${1}" && return 1
    done
    return 0
}

get_ckan_compose_ovverride_name() {
    echo "${1}" | python -c "import sys; print(sys.stdin.read().split('.')[2])"
}

exec_ckan_compose_overrides() {
    for DOCKER_COMPOSE_OVERRIDE in `ls .docker-compose.*.yaml`; do
        OVERRIDE_NAME=$(get_ckan_compose_ovverride_name "${DOCKER_COMPOSE_OVERRIDE}")
        ! eval "${1}" && return 1
    done
    return 0
}

pull_latest_images() {
    echo -e "\n** Pulling latest images **\n"
    exec_build_apps 'docker-compose pull $APP'
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        exec_ckan_compose_overrides 'docker pull "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}"'
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        docker pull "${DOCKER_IMAGE}:solrcloud-latest"
        docker pull "${DOCKER_IMAGE}:solr-latest-filenames-unicode"
    fi
    return 0
}

build_latest_images() {
    echo -e "\n** Building latest images **\n"
    ! exec_build_apps 'docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose-cache-from.yaml build $APP' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker-compose -f docker-compose.yaml \
                           -f .docker-compose-db.yaml \
                           -f .docker-compose-cache-from.yaml \
                           -f .docker-compose.${OVERRIDE_NAME}.yaml build ckan
        ' && return 1
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        ! docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml \
                         -f .docker-compose-cache-from.yaml \
                         -f .docker-compose-centralized.yaml build solr && return 1
        ! docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml \
                         -f .docker-compose-cache-from.yaml \
                         -f .docker-compose.filenames-unicode.yaml build solr && return 1
    fi
    return 0
}

tag_images() {
    [ -z "${1}" ] && return 1
    export TAG_SUFFIX="${1}"
    echo -e "\n** Tagging images with tag suffix ${TAG_SUFFIX} **\n"
    ! exec_build_apps '
        docker tag "${APP_LATEST_IMAGE}" "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}" &&\
        echo tagged ${APP} latest image: ${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker tag "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}" \
                       "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}" &&\
            echo tagged ckan override ${OVERRIDE_NAME} latest image: ${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}
        ' && return 1
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        docker tag "${DOCKER_IMAGE}:solr-latest-filenames-unicode" \
                   "${DOCKER_IMAGE}:solr-${TAG_SUFFIX}-filenames-unicode" &&\
        echo tagged solr override ${OVERRIDE_NAME} latest image: ${DOCKER_IMAGE}:solr-${TAG_SUFFIX}-filenames-unicode &&\
        docker tag "${DOCKER_IMAGE}:solrcloud-latest" \
                   "${DOCKER_IMAGE}:solrcloud-${TAG_SUFFIX}" &&\
        echo tagged solrcloud latest image: ${DOCKER_IMAGE}:solrcloud-${TAG_SUFFIX}
        [ "$?" != "0" ] && return 1
    fi
    return 0
}

push_latest_images() {
    echo -e "\n** Pushing latest images **\n"
    ! exec_build_apps '
        docker push "${DOCKER_IMAGE}:${APP}-latest"
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker push "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}"
        ' && return 1
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        ! docker push "${DOCKER_IMAGE}:solr-latest-filenames-unicode" && return 1
        ! docker push "${DOCKER_IMAGE}:solrcloud-latest" && return 1
    fi
    return 0
}

push_tag_images() {
    [ -z "${1}" ] && return 1
    export TAG_SUFFIX="${1}"
    echo -e "\n** Pushing tag images: ${TAG_SUFFIX} **\n"
    ! exec_build_apps '
        docker push "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}"
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker push "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}"
        ' && return 1
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        ! docker push "${DOCKER_IMAGE}:solr-${TAG_SUFFIX}-filenames-unicode" && return 1
        ! docker push "${DOCKER_IMAGE}:solrcloud-${TAG_SUFFIX}" && return 1
    fi
    return 0
}

print_summary() {
    [ -z "${1}" ] && return 1
    [ -z "${2}" ] && return 1
    export TAG_SUFFIX="${1}"
    export PUSHED_LATEST="${2}"
    echo -e "\n** Published docker images **\n"
    if [ "${PUSHED_LATEST}" == "1" ]; then
        exec_build_apps 'echo "${DOCKER_IMAGE}:${APP}-latest"'
        if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
            exec_ckan_compose_overrides 'echo "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}"'
        fi
        if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
            echo "${DOCKER_IMAGE}:solr-latest-filenames-unicode"
            echo "${DOCKER_IMAGE}:solrcloud-latest"
        fi
    fi
    exec_build_apps 'echo "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}"'
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        exec_ckan_compose_overrides 'echo "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}"'
    fi
    if [ "${BUILD_SOLR_OVERRIDES}" == "1" ]; then
        echo "${DOCKER_IMAGE}:solr-${TAG_SUFFIX}-filenames-unicode"
        echo "${DOCKER_IMAGE}:solrcloud-${TAG_SUFFIX}"
    fi
    return 0
}
