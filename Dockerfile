FROM debian:bullseye AS builder
WORKDIR /root
RUN apt-get update && \
    apt-get install --yes --no-install-recommends devscripts equivs && \
    apt-get clean
COPY debian ./debian
RUN export DH_VERSION=`dpkg-query --showformat='${Version}' --show debhelper` && \
    export DH_COMPAT=${DH_VERSION%%.*} && \
    sed -i "s/debhelper-compat (= 8)/debhelper-compat (= ${DH_COMPAT})/" debian/control && \
    mk-build-deps && \
    equivs-build debian/control

FROM debian:bullseye
WORKDIR /root
COPY --from=builder /root/*.deb .
RUN apt-get update && \
    dpkg --unpack *.deb && \
    apt-get --fix-broken --yes --no-install-recommends install && \
    apt-get clean
WORKDIR /srv/jessie-powerpc-packages
COPY . ./
RUN a2enmod expires rewrite && \
    bin/setup-site /srv/jessie-powerpc-packages 127.0.0.1; \
    ln -s /srv/jessie-powerpc-packages/conf/apache-default.conf /etc/apache2/sites-available/jessie.conf && \
    sed -i 's@ErrorLog ${APACHE_LOG_DIR}/error.log@ErrorLog /proc/self/fd/2\nCustomLog /proc/self/fd/1 combined@' /etc/apache2/apache2.conf && \
    a2dissite 000-default && \
    a2ensite jessie && \
    mkdir cache && \
    chown www-data cache && \
    chmod 2770 cache
RUN bin/daily
EXPOSE 80
CMD /usr/sbin/apache2ctl -DFOREGROUND