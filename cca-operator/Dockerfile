FROM alpine:3.6

RUN while ! ( apk update && apk add --no-cache --update-cache --repository ${APK_REPOSITORY} --allow-untrusted \
        bash python grep jq python3 libcurl git docker openssl curl ca-certificates wget \
        openssh-server openssh-sftp-server postgresql-client \
    ); do sleep 1; done &&\
    wget -qO kubectl https://storage.googleapis.com/kubernetes-release/release/$(wget -qO - https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl &&\
    chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl &&\
    python3 -m pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} pyyaml &&\
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
    chmod 700 get_helm.sh && ./get_helm.sh --version v2.11.0 && helm version --client && rm ./get_helm.sh

COPY *.sh /cca-operator/
COPY *.py /cca-operator/
COPY *.template /cca-operator/

RUN chmod +x /cca-operator/*.sh /cca-operator/*.py

WORKDIR /cca-operator

ENTRYPOINT ["./cca-operator.sh"]
