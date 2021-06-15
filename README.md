
**create lambda bootstrap**
```sh
v -os linux src/lambda_function.v -o build/bootstrap
chmod 755 build/bootstrap
```
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"payload":"hello world!"}'
### resources
* https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html
* https://stackoverflow.com/questions/58548580/npm-package-pem-doesnt-seem-to-work-in-aws-lambda-nodejs-10-x-results-in-ope/60232433#60232433
* https://github.com/softprops/lambda-rust
http://jamesmcm.github.io/blog/2020/10/24/lambda-runtime/
https://github.com/awslabs/aws-lambda-cpp
https://gallery.ecr.aws/lambda/provided