FROM public.ecr.aws/lambda/provided:al2 AS basesys
RUN yum update -y && \
    yum install -y @'Development Tools' \
    # V net module needs openssl 1.1
    openssl11 \
    openssl11-devel \
    # needed for v -gc boehm
    gc-devel 

FROM basesys AS vlang
ARG vlang_repo_url=https://github.com/vlang/v
ARG vlang_repo_branch=master
RUN mkdir -p /var/task/lib

# compile V lang
RUN git clone --branch ${vlang_repo_branch} ${vlang_repo_url} /vlang
RUN cd /vlang && \
    git pull && \
    make && \
    /vlang/v symlink

FROM vlang AS devbuild
ENV VLANG_BUILD_OPTIONS="-prod -gc boehm_full_opt"
ENV VLANG_LAMBDA_FUNC_NAME="main.v"
# create mount points
RUN mkdir /src && \
    mkdir -p /var/task
VOLUME ["/src","/var/task"]

RUN echo $'#!/bin/sh\n\
set -e # exit on error \n\
set -x \n\
# compile V bootstrap and handler to binary \n\
cd /src\n\
[ -f "/var/task/bootstrap" ] && rm /var/task/bootstrap\n\
v ${VLANG_BUILD_OPTIONS} -o /var/task/bootstrap ${VLANG_LAMBDA_FUNC_NAME} \n\
# prepare lambda shared libs \n\
# copy all shared libs which are linked with the binary \n\
[ -d "/var/task/lib" ] && rm -fr /var/task/lib\n\
mkdir -p /var/task/lib\n\
ldd /var/task/bootstrap | egrep -o '/[a-z0-9/\_\.\-]+' | xargs -I{} -P1 cp -v {} /var/task/lib' > /build.sh &&\
    chmod +x /build.sh
ENTRYPOINT [ "/build.sh" ]