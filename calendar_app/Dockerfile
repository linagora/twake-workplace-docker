FROM linagora/twake-calendar-side-service:branch-master

COPY ../twake_auth/traefik/ssl/root-ca.crt /usr/local/share/ca-certificates/root-ca.crt

RUN keytool -importcert -trustcacerts \
      -keystore $JAVA_HOME/lib/security/cacerts \
      -storepass changeit \
      -alias twake-root-ca \
      -file /usr/local/share/ca-certificates/root-ca.crt \
      -noprompt
