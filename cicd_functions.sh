DOCKER_IMAGE=viderum/ckan-cloud-docker
BUILD_APPS="ckan cca-operator nginx db solr"
BUILD_CKAN_OVERRIDES="1"

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
    ! exec_build_apps '
        if [ "${APP}" == "cca-operator" ]; then
            docker pull "${APP_LATEST_IMAGE}"
        else
            docker-compose pull $APP
        fi
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker pull "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}"
        ' && return 1
    fi
    return 0
}

build_latest_images() {
    echo -e "\n** Building latest images **\n"
    ! exec_build_apps '
        if [ "${APP}" == "cca-operator" ]; then
            docker build --cache-from "${APP_LATEST_IMAGE}" -t "${APP_LATEST_IMAGE}" cca-operator
        else
            docker-compose -f docker-compose.yaml -f .docker-compose-cache-from.yaml build $APP
        fi
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker-compose -f docker-compose.yaml -f .docker-compose-cache-from.yaml \
                           -f .docker-compose.${OVERRIDE_NAME}.yaml build ckan
        ' && return 1
    fi
    return 0
}

tag_images() {
    [ -z "${1}" ] && return 1
    export TAG_SUFFIX="${1}"
    echo -e "\n** Tagging images with tag prefix ${TAG_SUFFIX} **\n"
    ! exec_build_apps '
        docker tag "${APP_LATEST_IMAGE}" "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}"
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker tag "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}" \
                       "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}"
        ' && return 1
    fi
    return 0
}

push_images() {
    [ -z "${1}" ] && return 1
    export TAG_SUFFIX="${1}"
    echo -e "\n** Pushing images **\n"
    ! exec_build_apps '
        docker push "${DOCKER_IMAGE}:${APP}-latest" &&\
        docker push "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}"
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            docker push "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}" &&\
            docker push "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}"
        ' && return 1
    fi
    return 0
}

print_summary() {
    [ -z "${1}" ] && return 1
    export TAG_SUFFIX="${1}"
    echo -e "\n** Published docker images **\n"
    ! exec_build_apps '
        echo "${DOCKER_IMAGE}:${APP}-latest"
        echo "${DOCKER_IMAGE}:${APP}-${TAG_SUFFIX}"
    ' && return 1
    if [ "${BUILD_CKAN_OVERRIDES}" == "1" ]; then
        ! exec_ckan_compose_overrides '
            echo "${DOCKER_IMAGE}:ckan-latest-${OVERRIDE_NAME}"
            echo "${DOCKER_IMAGE}:ckan-${TAG_SUFFIX}-${OVERRIDE_NAME}"
        ' && return 1
    fi
    return 0
}
