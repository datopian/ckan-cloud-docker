FROM jenkins/jenkins:2.478

ARG PIP_INDEX_URL
ENV PIP_INDEX_URL=$PIP_INDEX_URL

RUN export JENKINS_VERSION=$(unzip -p /usr/share/jenkins/jenkins.war META-INF/MANIFEST.MF | grep 'Jenkins-Version' | cut -d' ' -f2) && \
    echo "Jenkins version: $JENKINS_VERSION" && \
    jenkins-plugin-cli --jenkins-version $JENKINS_VERSION --plugins \
        build-timeout envfile copyartifact extensible-choice-parameter file-operations \
        fstrigger generic-webhook-trigger git-parameter github-branch-source \
        global-variable-string-parameter http_request jobgenerator join managed-scripts matrix-combinations-parameter \
        persistent-parameter workflow-aggregator pipeline-github-lib python ssh-slaves timestamper urltrigger \
        ws-cleanup

USER root
RUN curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && apt-key fingerprint 0EBFCD88 &&\
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" &&\
    apt-get update && apt-get install -y docker-ce
RUN chmod +x /usr/local/bin/docker-compose && echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers &&\
    echo "export CKAN_CLOUD_DOCKER_JENKINS=1" > /etc/profile.d/ckan_cloud_docker_jenkins &&\
    chmod +x /etc/profile.d/ckan_cloud_docker_jenkins
RUN apt update && apt install -y python3-pip
RUN python3 -m pip install --break-system-packages --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} pyyaml

USER jenkins
