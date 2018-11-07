FROM alpine

RUN wget -qO kubectl https://storage.googleapis.com/kubernetes-release/release/$(wget -qO - https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl &&\
    chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN while ! ( apk update && apk add --no-cache bash python grep jq python3 libcurl git docker curl openssl ); do sleep 1; done &&\
    python3 -m pip install pyyaml

RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
    chmod 700 get_helm.sh && ./get_helm.sh --version v2.11.0 && helm version --client && rm ./get_helm.sh

COPY *.sh /cca-operator/

WORKDIR /cca-operator

ENTRYPOINT ["./cca-operator.sh"]
