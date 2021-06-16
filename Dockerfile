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
RUN mkdir -p /var/task/lib
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie

# compile V lang
#RUN git clone https://github.com/vlang/v /vlang
RUN git clone --branch feature/feat-request-timeout https://github.com/aheissenberger/v.git /vlang
RUN cd /vlang && \
    git pull && \
    make && \
    /vlang/v symlink

RUN mkdir -p /var/task
COPY src/ /src

# compile V bootstrap and handler to binary
RUN cd /src; v -prod -gc boehm_full_opt  lambda_function.v -o /var/task/bootstrap

FROM vlang AS prodbuild
# prepare lambda shared libs
RUN mkdir -p /var/task/lib
# copy all shared libs which are linked with the binary
RUN ldd /var/task/bootstrap | egrep -o '/[a-z0-9/\_\.\-]+' | xargs -I{} -P1 cp -v {} /var/task/lib

FROM public.ecr.aws/lambda/provided:al2 AS prod
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
COPY --from=prodbuild /var/task/lib/* /var/task/lib/
COPY --from=vlang /var/task/bootstrap /var/task/bootstrap
