FROM grafana/promtail:2.2.1

RUN apt-get update && apt-get install -y bc curl dumb-init bash python procps coreutils sysstat vim net-tools

RUN mkdir /sense-collector

COPY exec-device-details.sh \
exec-host-performance.sh \
exec-monitor-status.sh \
exec-sense-collector.sh \
sense-collector-details.sh \
start-device-details.sh \
start-host-performance.sh \
start-monitor-status.sh \
start-sense-collector.sh \
sense-collector-init.sh \
websocat_amd64-linux-static \
/sense-collector/

COPY jq /usr/bin/

WORKDIR /sense-collector

RUN chmod a+x *.sh

RUN chmod +x websocat_amd64-linux-static

RUN chmod +x /usr/bin/jq

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/sense-collector/sense-collector-init.sh"]
