FROM golang:1.14 AS lambda_rie
# AWS lambda Runtime Interface Emulator
RUN git clone https://github.com/aws/aws-lambda-runtime-interface-emulator.git /aws-lambda-rie && \
    cd /aws-lambda-rie && \
    go build -ldflags "-s -w" -o aws-lambda-rie ./cmd/aws-lambda-rie
FROM public.ecr.aws/lambda/provided:al2 AS prod
ENV LOG_LEVEL "info"
ENV HANDLER "default"
COPY --from=lambda_rie /aws-lambda-rie/aws-lambda-rie /usr/bin/aws-lambda-rie
RUN echo $'#!/bin/sh\n\
set -x\n\
/usr/bin/aws-lambda-rie --log-level ${LOG_LEVEL} /var/task/bootstrap ${HANDLER}\n\
' > /entry_script.sh && \
chmod +x /entry_script.sh
ENTRYPOINT [ "/entry_script.sh" ]
