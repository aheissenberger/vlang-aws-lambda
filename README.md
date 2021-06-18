# vlang / AWS Lambda Custom Runtime Setup

Use V lang for AWS Lambda functions. This template provides a setup 
to  compile, test local and deploy to AWS with the [serverless framework](https://www.serverless.com/framework/docs/providers/aws/guide/intro/) which provides easy creation of additional AWS Cloud resources.
## Installation 

create a project from the template

```bash
  mkdir my-project && cd $_
  git init
  git pull --depth 1 https://github.com/aheissenberger/vlang-aws-lambda.git
```

## Requirements

* `V` language [setup](https://vlang.io)
* [Docker Desktop](https://www.docker.com/products/docker-desktop)
  **Hint:** This project uses the latest version of Docker Desktop. If your version does not provide `docker compose` replace all mentioned commands with `docker-compose`.
* [AWS credentials setup](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-getting-started-set-up-credentials.html)

## Usage

### Write Lambda functions

add the code for your functions to `src/bootstrap.v`

### Build binary for AWS Lambda

```sh
docker compose run --rm build
```

### Test local 
#### A) Docker with AWS Lambda Runtime Emulator

start the AWS Lambda Emulator as background process:
```sh
docker compose up -d lambda my-handler
```

invoke your function with a AWS Event:
```sh
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"payload":"hello world!"}'
```

Lambda Logs:
```sh
docker compose logs -f lambda
```

shutdown background process:
```sh
docker compose down
```
**Hint:** you need to restart if you built new binaries!

#### B) Native go binary with AWS Lambda Runtime Emulator

This is the option you will use if you need to debug your V function with `lldb`or `gdb`.

**build**
requires local golang development environment
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

### Deploy to AWS Cloud

1. Modify configuration

check and adapt  `serverless.yml`:
* `service: <project_name>` should be short and will be part of the lambda function name
* `region: eu-west-1` adapt [region](https://docs.aws.amazon.com/general/latest/gr/lambda-service.html) to your location
* `stage: dev`
for more information check [serverless framework documentation](https://www.serverless.com/framework/docs/providers/aws/guide/serverless.yml/)

2. [Setup AWS credentials](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-getting-started-set-up-credentials.html)

3. Deploy
```sh
docker compose run --rm deploy
```

## Options

### `docker compose run build`

Check the `environment:` and `args:` sections of the `docker-compose.yml` file for possible options.

### `docker compose up lambda`

Check the `entrypoint:` sections of the `docker-compose.yml` file for possible options.

### `docker compose run deploy`

by default this will do:
`serverless deploy`

you can add any valid [serverless cli command](https://www.serverless.com/framework/docs/providers/aws/cli-reference/) to the command:
`docker compose run deploy <serverless command>`

remove the whole project from AWS Cloud:
`docker compose run deploy remove --stage test`

deploy to a different stage as defined in `serverless.yml`:
`docker compose run deploy deploy --stage test`

## Bootstrap API

The bootstrap module will handle the communication to the AWS Runtime API.
The only information which needs to be provided is a mapping of handler names to handler functions.

```v
fn main() {
	runtime := bootstrap.BootstrapConfig{
		handlers: map{
			'default': my_handler
		}
	}

	runtime.process()
}

fn my_handler(event json2.Any, context bootstrap.Context) string {
  return result
}
```
If only one function is needed use the name 'default' which is allready used as a default for the local lambda test setup.

### Roadmap

 - [X] Build pipeline to create AWS Linux 2 native binaries and bundle shared libraries
 - [X] Local Lambda Testenvironment
 - [X] Integrated AWS Cloud deployment with the serverless framework 
 - [X] Encapsulate the V lang custome runtime in a v module
 - [ ] Include example which uses the AWS C++ SDK

### Contribution

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are greatly appreciated.

1. Fork the Project
1. Create your Feature Branch (git checkout -b feature/AmazingFeature)
1. Commit your Changes (git commit -m 'Add some AmazingFeature')
1. Push to the Branch (git push origin feature/AmazingFeature)
1. Open a Pull Request

### Resources
These are resources which helped to land this project
* https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html
* https://github.com/aws/aws-lambda-runtime-interface-emulator
* https://stackoverflow.com/questions/58548580/npm-package-pem-doesnt-seem-to-work-in-aws-lambda-nodejs-10-x-results-in-ope/60232433#60232433
* https://github.com/softprops/lambda-rust
* http://jamesmcm.github.io/blog/2020/10/24/lambda-runtime/
* https://github.com/awslabs/aws-lambda-cpp
* https://gallery.ecr.aws/lambda/provided

when extra tools from centos epel required:
```
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum update -y && \
    yum install -y inotify-tools
```

### License

Distributed under the "bsd-2-clause" License. See [LICENSE.txt](LICENSE.txt) for more information.
