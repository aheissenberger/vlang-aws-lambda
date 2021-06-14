FROM public.ecr.aws/lambda/provided:latest AS VLANG

RUN yum update -y && \
    yum install -y \
        git bash \
        //clang make
RUN yum groupinstall -y "Development Tools" 
RUN yum install -y openssl-devel
RUN git clone https://github.com/vlang/v /vlang
RUN cd /vlang; make && /vlang/v symlink
RUN mkdir -p /var/task
COPY src/ /src
RUN cd /src; v -prod -autofree lambda_function.v -o  /var/task/bootstrap

# Copy custom runtime bootstrap
#COPY build/bootstrap ${LAMBDA_RUNTIME_DIR}
# Copy function code
#COPY function.sh ${LAMBDA_TASK_ROOT}
FROM public.ecr.aws/lambda/provided:latest AS PROD
COPY --from=VLANG /var/task/bootstrap /var/task/bootstrap
# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "function.handler" ]
