module bootstrap

import os

const (
	aws_runtime_api  = '127.0.0.1:9001'
	aws_handler      = 'my-handler'
	lambda_task_root = '/var/task'
)

fn testsuite_begin() {
	os.setenv('AWS_LAMBDA_RUNTIME_API', bootstrap.aws_runtime_api, true)
	os.setenv('_HANDLER', bootstrap.aws_handler, true)
	os.setenv('LAMBDA_TASK_ROOT', bootstrap.lambda_task_root, true)
}

fn test_new_lambda_api() {
	data := new_lambda_api()
	assert data.environment.aws_lambda_runtime_api == bootstrap.aws_runtime_api
	assert data.req_incocation_next.url == 'http://$bootstrap.aws_runtime_api/2018-06-01/runtime/invocation/next'
}
