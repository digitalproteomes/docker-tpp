FROM digitalproteomes/gosu:version-1.0

LABEL maintainer="Patrick Pedrioli" description="A container for the Trans Proteomics Pipeline" version="5.2.0"

ARG TPPLINK=https://sourceforge.net/projects/sashimi/files/Trans-Proteomic%20Pipeline%20%28TPP%29/TPP%20v5.2%20%28Flammagenitus%29%20rev%200/TPP_5.2.0-src.tgz/download

## Let apt-get know we are running in noninteractive mode
ENV DEBIAN_FRONTEND noninteractive

# Install pre-requisites for TPP and get_prophet_prob.py
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential=12.4ubuntu1 \
       perl=5.26.1-6ubuntu0.3 \
       zlib1g-dev=1:1.2.11.dfsg-0ubuntu2 \
       libghc-bzlib-dev=0.5.0.5-6build1 \
       gnuplot=5.2.2+dfsg1-2ubuntu1 \
       unzip=6.0-21ubuntu1 \
       expat=2.2.5-3ubuntu0.2 \
       libexpat1-dev=2.2.5-3ubuntu0.2 \
       git=1:2.17.1-1ubuntu0.7 \
       python3=3.6.7-1~18.04 \
       python3-pip=9.0.1-2.3~ubuntu1.18.04.2 \
       python3-setuptools=39.0.1-2 \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir pandas==1.1.0 \
       bs4==0.0.1


#############
# TPP setup #
#############

# Prepare folders
RUN mkdir -p /usr/local/tpp \
    && chown user.userg /usr/local/tpp \
    && mkdir /data \
    && chown user.userg /data

# Get TPP sources configure, make, install and cleanup
#
# NOTE The version of comet in 5.2.0 doesn't compile.
# RUN cd /tmp \
#     && mkdir tpp-src \
#     && wget -O tpp.tgz $TPPLINK \
#     && tar -zxf tpp.tgz -C tpp-src --strip-components 1 \
#     && cd /tmp/tpp-src/extern \
#     && rm comet_source_2018014.zip \
#     && wget -O comet_2019015.zip https://sourceforge.net/projects/comet-ms/files/comet_2019015.zip/download \
#     && unzip comet_2019015.zip \
#     && cd /tmp/tpp-src \
#     && sed -i 's/2018014/2019015/g' extern/Makefile \
#     && make all \
#     && make install \
#     && cd /tmp \
#     && rm -rf tpp-src \
#     && rm tpp.tgz
RUN mkdir /tmp/tpp-src \
    && wget -O /tmp/tpp.tgz $TPPLINK \
    && tar -zxf /tmp/tpp.tgz -C /tmp/tpp-src --strip-components 1 \
    && rm /tmp/tpp-src/extern/comet_source_2018014.zip \
    && wget -O /tmp/tpp-src/extern/comet_2019015.zip https://sourceforge.net/projects/comet-ms/files/comet_2019015.zip/download \
    && unzip /tmp/tpp-src/extern/comet_2019015.zip -d /tmp/tpp-src/extern \
    && sed -i 's/2018014/2019015/g' /tmp/tpp-src/extern/Makefile \
    && make -C /tmp/tpp-src all \
    && make -C /tmp/tpp-src install \
    && rm -rf /tmp/tpp-src \
    && rm /tmp/tpp.tgz

WORKDIR /usr/local/tpp/bin

# Add patched XPRESS binary
#
# NOTE: This bug will be fixed in future releases
COPY Patches/XPressPeptideParser /usr/local/tpp/bin/

# Set up PERL modules
ENV PERL_MM_USE_DEFAULT=1
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
RUN cpan -y install CGI \
    && cpan install XML::Parser \
    && cpan install FindBin::libs \
    && cpan -y install JSON

# Add TPP to the PATH
ENV PATH=/usr/local/tpp/bin:$PATH


################
# Apache setup #
################

RUN apt-get update \
    && apt-get -y --no-install-recommends install apache2=2.4.29-1ubuntu4.14 \
    xsltproc=1.1.29-5ubuntu0.2 \
    && rm -rf /var/lib/apt/lists/*

## Add site configurations
COPY tpp_443.conf /etc/apache2/sites-available/

## Enable Apache modules required for TPP
RUN a2enmod rewrite \
    && a2enmod cgid.load \
    && a2enmod ssl \
    && a2ensite tpp_443


###################
# TPP Data folder #
###################
RUN ln -s /digitalproteomes /var/www/html

## Make sure www-data belongs to the groups required to access data
## created during TPP analysis
RUN groupadd -g 1001 digitalproteomes
RUN usermod -a -G digitalproteomes www-data

EXPOSE 443
