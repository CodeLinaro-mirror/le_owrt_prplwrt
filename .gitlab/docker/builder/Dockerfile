FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
	build-essential \
	curl \
	file \
	gawk \
	git-core \
	gosu \
	iproute2 \
	iputils-ping \
	libdw-dev \
	libelf-dev \
	libncurses5-dev \
	locales \
	nmap \
	openssh-client \
	pwgen \
	python3 \
	python3-distlib \
	python3-jira \
	python3-jwt \
	python3-pip \
	python3-setuptools \
	python3-yaml \
	rsync \
	signify-openbsd \
	subversion \
	sudo \
	swig \
	unzip \
	wget && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

RUN \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    useradd -c "OpenWrt Builder" -m -d /home/builder -G sudo -s /bin/bash builder

USER builder
ENV HOME /home/builder
WORKDIR /home/builder/
