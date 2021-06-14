FROM public.ecr.aws/lambda/provided:latest AS VLANG

RUN yum update -y && \
    yum groupinstall -y "Development Tools" \
    yum install -y \
        git \
        //openssl-devel \
        //clang make

#RUN yum install -y openssl-devel
RUN git clone https://github.com/vlang/v /vlang
RUN cd /vlang; make && /vlang/v symlink

# RUN amazon-linux-extras install epel -y
# RUN yum repolist
# RUN yum install -y openssl-devel

RUN git clone https://github.com/openssl/openssl.git /openssl &&\
    yum install -y perl-core zlib-devel && \
    cd /openssl && \
    ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib && \
    make && make test && make install

RUN mkdir -p /var/task
COPY src/ /src
RUN cd /src; LDFLAGS="-L/usr/local/ssl/lib" v -cflags "-I/usr/local/ssl/include" lambda_function.v -o  /var/task/bootstrap
# Copy custom runtime bootstrap
#COPY build/bootstrap ${LAMBDA_RUNTIME_DIR}
# Copy function code
#COPY function.sh ${LAMBDA_TASK_ROOT}
FROM public.ecr.aws/lambda/provided:latest AS PROD
COPY --from=VLANG /var/task/bootstrap /var/task/bootstrap
# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "function.handler" ]
