FROM alpine:3.6
MAINTAINER Andrew Tanner

ADD /apk /apk
RUN cp /apk/.abuild/-58b83ac3.rsa.pub /etc/apk/keys
RUN apk --no-cache --update add /apk/x11vnc-0.9.13-r0.apk

RUN apk --no-cache add xvfb firefox-esr xfce4 xfce4-terminal supervisor git sudo \
  && addgroup alpine \
  && adduser  -G alpine -s /bin/sh -D alpine \
  && echo "alpine:alpine" | /usr/sbin/chpasswd \
  && echo "alpine    ALL=(ALL) ALL" >> /etc/sudoers \
  && rm -rf /apk /tmp/* /var/cache/apk/*

ADD etc /etc
WORKDIR /home/alpine
EXPOSE 5900

USER alpine
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
