#!/bin/sh
set -x
if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
  exec /usr/local/bin/aws-lambda-rie /var/runtime/bootstrap aws-lambda-ric $@
else
  exec /var/runtime/bootstrap aws-lambda-ric $@
fi 