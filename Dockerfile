FROM golang:1.14 AS lambda_rie
# AWS lambda Runtime Interface Emulator
RUN git clone https://github.com/aws/aws-lambda-runtime-interface-emulator.git /aws-lambda-rie && \
    cd /aws-lambda-rie && \
    go build -ldflags "-s -w" -o aws-lambda-rie ./cmd/aws-lambda-rie

FROM public.ecr.aws/lambda/provided:al2 AS basesys
RUN yum update -y && \
    yum install -y @'Development Tools' \
    openssl11 \
    openssl11-devel \
    # needed for v -gc boehm
    gc-devel 
        
FROM basesys AS devsys

# V needs openssl 1.1 which does not exist on Amazon Linux 2, only v1.0.1
# RUN git clone https://github.com/openssl/openssl.git /openssl &&\
#     yum install -y perl-core zlib-devel && \
#     cd /openssl && \
#     ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl no-shared no-comp zlib && \
#     make && make test && make install

# RUN yum install -y perl-core zlib-devel && mkdir /openssl
# RUN curl https://www.openssl.org/source/openssl-1.1.1k.tar.gz | \
#      tar -xz -C /openssl --strip-components=1 && \
#     cd /openssl && \
#    ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl no-shared no-comp zlib && \
#    ./config -Wl,-rpath=/var/task/lib --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib && \
#    make && make test && make install

FROM basesys AS vlang
RUN mkdir -p /var/task/lib
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
# copy dynamic libs to directory which is searched by lambda environment
#COPY --from=devsys /usr/local/ssl/lib /usr/local/ssl/lib
# copy development header for V
#COPY --from=devsys /usr/local/ssl/include /usr/include/openssl

# compile V lang
#RUN git clone https://github.com/vlang/v /vlang
RUN git clone --branch feature/feat-request-timeout https://github.com/aheissenberger/v.git /vlang
RUN cd /vlang && \
    git pull && \
    make && \
    /vlang/v symlink

#RUN cp /lib64/*.so* /var/task/lib
RUN mkdir -p /var/task
COPY src/ /src
# compile V bootstrap and handler to binary
#RUN cd /src; LDFLAGS="-L/usr/local/ssl/lib" v -prod -gc boehm_full_opt -cflags "-I/usr/include/openssl -Wl,-rpath=/var/task/lib" lambda_function.v -o  /var/task/bootstrap
RUN cd /src; v -prod -gc boehm_full_opt  lambda_function.v -o /var/task/bootstrap

FROM vlang AS prodbuild
# prepare lambda shared libs
RUN mkdir -p /var/task/lib
RUN ldd /var/task/bootstrap | egrep -o '/[a-z0-9/\_\.\-]+' | xargs -I{} -P1 cp -v {} /var/task/lib
#RUN cp /usr/local/ssl/lib/*.so* /var/task/lib
# RUN cp /usr/lib64/libbz2.so.1 /usr/lib64/libssl.so.1.1 /usr/lib64/libcrypto.so.1.1 \
#     /usr/lib64/libgc.so.1 \
#     /usr/lib64/libatomic_ops.so.1 \
#     /var/task/lib/

FROM public.ecr.aws/lambda/provided:al2 AS prod
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
COPY --from=prodbuild /var/task/lib/* /var/task/lib/
COPY --from=vlang /var/task/bootstrap /var/task/bootstrap
