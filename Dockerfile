FROM golang:1.14 AS lambda_rie
# AWS lambda Runtime Interface Emulator
RUN git clone https://github.com/aws/aws-lambda-runtime-interface-emulator.git /aws-lambda-rie && \
    cd /aws-lambda-rie && \
    go build -ldflags "-s -w" -o aws-lambda-rie ./cmd/aws-lambda-rie

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
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie

# compile V lang
RUN git clone --branch ${vlang_repo_branch} ${vlang_repo_url} /vlang
RUN cd /vlang && \
    git pull && \
    make && \
    /vlang/v symlink

RUN mkdir -p /var/task

FROM vlang AS devbuild
RUN echo "#!/bin/sh" > /build.sh && echo "set -x" >> /build.sh 
# compile V bootstrap and handler to binary
RUN echo "cd /src; v -prod -gc boehm_full_opt  lambda_function.v -o /var/task/bootstrap" >> /build.sh

# prepare lambda shared libs
RUN echo "mkdir -p /var/task/lib" >> /build.sh
# copy all shared libs which are linked with the binary
RUN echo "ldd /var/task/bootstrap | egrep -o '/[a-z0-9/\_\.\-]+' | xargs -I{} -P1 cp -v {} /var/task/lib" >> /build.sh
RUN chmod +x /build.sh

FROM vlang AS prodbuild
COPY src/ /src

# compile V bootstrap and handler to binary
RUN cd /src; v -prod -gc boehm_full_opt  lambda_function.v -o /var/task/bootstrap

# prepare lambda shared libs
RUN mkdir -p /var/task/lib
# copy all shared libs which are linked with the binary
RUN ldd /var/task/bootstrap | egrep -o '/[a-z0-9/\_\.\-]+' | xargs -I{} -P1 cp -v {} /var/task/lib

FROM public.ecr.aws/lambda/provided:al2 AS prod
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
COPY --from=prodbuild /var/task/lib/* /var/task/lib/
COPY --from=vlang /var/task/bootstrap /var/task/bootstrap
