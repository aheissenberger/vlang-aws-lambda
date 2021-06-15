FROM golang:1.14 AS lambda_rie
# AWS lambda Runtime Interface Emulator
RUN git clone https://github.com/aws/aws-lambda-runtime-interface-emulator.git /aws-lambda-rie && \
    cd /aws-lambda-rie && \
    go build -ldflags "-s -w" -o aws-lambda-rie ./cmd/aws-lambda-rie

FROM public.ecr.aws/lambda/provided:latest AS basesys
RUN yum update -y && \
    yum install -y @'Development Tools' \
    # needed for v -gc boehm
    gc-devel 
        
FROM basesys AS devsys

# V needs openssl 1.1 which does not exist on Amazon Linux 2, only v1.0.1
RUN git clone https://github.com/openssl/openssl.git /openssl &&\
    yum install -y perl-core zlib-devel && \
    cd /openssl && \
    ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib && \
    make && make test && make install

FROM basesys AS vlang
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
# copy dynamic libs to directory which is searched by lambda environment
COPY --from=devsys /usr/local/ssl/lib /var/task/lib
# copy development header for V
COPY --from=devsys /usr/local/ssl/include /usr/include/openssl

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
RUN cd /src; LDFLAGS="-L/var/task/lib" v -prod -gc boehm_full_opt -cflags "-I/usr/include/openssl" lambda_function.v -o  /var/task/bootstrap

FROM public.ecr.aws/lambda/provided:latest AS prod
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
COPY --from=devsys /usr/local/ssl/lib /var/task/lib
COPY --from=VLANG /var/task/bootstrap /var/task/bootstrap
