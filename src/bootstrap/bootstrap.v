module bootstrap

import os
import net.http
import x.json2

// pub interface Handler {
// 	execute(string ,string) string
// }

// pub struct BootstrapConfig {
//   mut:
// 	handlers map[string]Handler
// }

pub type HandlerFunction = fn (string, string) string

pub struct BootstrapConfig {
pub mut:
	handlers map[string]HandlerFunction
}

pub fn (b BootstrapConfig) process() {
	api := new_lambda_api()

	handler := b.handlers[api.environment.handler] or {
		panic('handler "$api.environment.handler" not found!')
	}

	for {
		// Get an event. The HTTP request will block until one is received
		event_data := api.invocation_next() or { panic('invocation api failed: $err') }
		dump(event_data)
		if event_data.status_code != 200 {
			panic('request not 200: $event_data.status_code')
		}
		// # Extract request ID by scraping response headers received above
		request_id := event_data.header.get_custom('Lambda-Runtime-Aws-Request-Id', {}) or {
			panic('Extract request ID: $err')
		}
		// Run the handler function from the script
		handler_response := handler(event_data.text, 'context')

		api.response(request_id, handler_response) or { panic('response: $err') }
	}
}

pub struct LambdaRuntimeEnvironment {
	aws_lambda_runtime_api          string // AWS_LAMBDA_RUNTIME_API – (Custom runtime) The host and port of the runtime API.
	handler                         string // _HANDLER – The handler location configured on the function.
	aws_region                      string // AWS_REGION – The AWS Region where the Lambda function is executed.
	aws_execution_env               string // AWS_EXECUTION_ENV – The runtime identifier, prefixed by AWS_Lambda_—for example, AWS_Lambda_java8.
	aws_lambda_function_name        string // AWS_LAMBDA_FUNCTION_NAME – The name of the function.
	aws_lambda_function_memory_size string // AWS_LAMBDA_FUNCTION_MEMORY_SIZE – The amount of memory available to the function in MB.
}

fn get_lambda_runtime_environment() LambdaRuntimeEnvironment {
	return LambdaRuntimeEnvironment{
		aws_lambda_runtime_api: os.getenv('AWS_LAMBDA_RUNTIME_API')
		handler: os.getenv('_HANDLER')
		aws_region: os.getenv('AWS_REGION')
		aws_execution_env: os.getenv('AWS_EXECUTION_ENV')
		aws_lambda_function_name: os.getenv('AWS_LAMBDA_FUNCTION_NAME')
		aws_lambda_function_memory_size: os.getenv('AWS_LAMBDA_FUNCTION_MEMORY_SIZE')
	}
}

struct ErrorRequest {
	error_message string
	error_type    string
	stack_trace   []string
}

pub fn (er ErrorRequest) to_json() string {
	mut obj := map[string]json2.Any{}
	obj['errorMessage'] = er.error_message
	obj['errorType'] = er.error_type
	mut stack_trace := []json2.Any{}
	for line in er.stack_trace {
		stack_trace << line
	}
	obj['stackTrace'] = stack_trace
	return obj.str()
}

struct LambdaAPI {
	environment LambdaRuntimeEnvironment
	// invocation_next string = 'http://${os.getenv('AWS_LAMBDA_RUNTIME_API')}/2018-06-01/runtime/invocation/next'
	req_incocation_next http.Request
}

fn (lr LambdaAPI) response_url(request_id string) string {
	return 'http://$lr.environment.aws_lambda_runtime_api/2018-06-01/runtime/invocation/$request_id/response'
}

fn new_lambda_api() LambdaAPI {
	environment := get_lambda_runtime_environment()
	return LambdaAPI{
		environment: environment
		req_incocation_next: http.Request{
			method: http.Method.get
			url: 'http://$environment.aws_lambda_runtime_api/2018-06-01/runtime/invocation/next'
			read_timeout: -1 // wait for ever
		}
	}
}

fn (lr LambdaAPI) invocation_next() ?http.Response {
	return lr.req_incocation_next.do()
}

fn (lr LambdaAPI) response(request_id string, body string) ? {
	http.post('http://$lr.environment.aws_lambda_runtime_api/2018-06-01/runtime/invocation/$request_id/response',
		body) ?
}

fn (lr LambdaAPI) error_initialization(category_reason string, error_request ErrorRequest) {
	mut header := http.new_header(key: .content_type, value: 'application/json')
	header.add_custom('Lambda-Runtime-Function-Error-Type', category_reason) or { panic(err) }
	println('http://$lr.environment.aws_lambda_runtime_api/runtime/init/error')
	resp := http.fetch('http://$lr.environment.aws_lambda_runtime_api/runtime/init/error',
		http.FetchConfig{
		method: http.Method.post
		header: header
		data: json2.encode<ErrorRequest>(error_request)
	}) or { panic('error post error_initialization: $err') }
	if resp.status_code != 202 {
		println(resp.text)
		panic('error error_initialization status_code: $resp.status_code')
	}
	exit(1)
}
