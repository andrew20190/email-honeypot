FROM ubuntu

RUN apt-get update \
    && apt-get -y install tcpdump ngrep net-tools sysstat 

RUN apt-get -y install libdbi-perl \
    && apt-get -y install libdbd-mysql \
    && apt-get -y install libdbd-mysql-perl \
    && apt-get -y install libnet-dns-perl \
    && apt-get -y install libnet-smtps-perl \
    && apt-get -y install cpanminus \
    && apt-get -y install libarchive-zip-perl \
    && apt-get -y install build-essential \
    && cpanm install Net::Server::POP3 \ 
    && apt-get -y install libdatetime-perl \
    && apt-get -y install libdatetime-format-mail-perl \ 
    && apt-get -y install libnet-server-mail-perl

RUN mkdir /mail
WORKDIR /mail

COPY smtp_with_auth.pl /mail
COPY keymat/mail.crt /mail
COPY keymat/mail.key /mail

RUN chmod ugo+rx smtp_with_auth.pl 

CMD /mail/smtp_with_auth.pl
