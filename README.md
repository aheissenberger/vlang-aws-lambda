# V lang / AWS Lambda functions / Compiling & Testing

**create lambda bootstrap**
This is not working
```sh
v -os linux src/lambda_function.v -o build/bootstrap
chmod 755 build/bootstrap
```

## build local lambda test container
`docker compose build`

## run local lambda test container
`docker compose up -d && docker compose logs -f lambda`

## invoke lambda handler

```sh
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"payload":"hello world!"}'
```

## shutdown local lambda test container

`docker compose down`

## local run AWS Lambda Runtime Interface Emulator without docker image

**build**
```
git clone git@github.com:aws/aws-lambda-runtime-interface-emulator.git aws-lambda-rie
cd aws-lambda-rie
go build -ldflags "-s -w" -o aws-lambda-rie ./cmd/aws-lambda-rie
```

**run**
1. compile V lang handler
```sh
v -prod -gc boehm_full_opt src/lambda_function.v -o build/bootstrap
```

2. run AWS Lambda Runtime Interface Emulation
```
./aws-lambda-rie/aws-lambda-rie --log-level debug ./build/bootstrap myhandler
```
3. call the AWS Lambda Runtime Interface on port 8080 (different to docker image)

```sh
curl -XPOST "http://localhost:8080/2015-03-31/functions/function/invocations" -d '{"payload":"hello world!"}'
```


## get libs needed
```
docker compose up -d
docker compose exec lambda sh
ldd /var/task/bootstrap | cut -d ' ' -f 3 | xargs -I{} -P1 cp -v {} /var/task/lib
exit
docker ps # get container id
docker cp cf5e54c2de8a:/var/task/lib/ build-serverless/lib/
```

docker cp cf5e54c2de8a:/var/task/lib/ build-serverless/lib/
### resources
* https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html
* https://github.com/aws/aws-lambda-runtime-interface-emulator
* https://stackoverflow.com/questions/58548580/npm-package-pem-doesnt-seem-to-work-in-aws-lambda-nodejs-10-x-results-in-ope/60232433#60232433
* https://github.com/softprops/lambda-rust
http://jamesmcm.github.io/blog/2020/10/24/lambda-runtime/
https://github.com/awslabs/aws-lambda-cpp
https://gallery.ecr.aws/lambda/provided
