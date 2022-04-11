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

pub type EventType = json2.Any

pub type HandlerFunction = fn (json2.Any, Context) string

pub struct BootstrapConfig {
pub mut:
	handlers map[string]HandlerFunction
}

pub fn (b BootstrapConfig) process() {
	mut api := new_lambda_api()

	handler := b.handlers[api.handler] or { panic('handler "$api.handler" not found!') }

	for {
		// Get an event. The HTTP request will block until one is received
		event_data := api.invocation_next() or { panic('invocation api failed: $err') }
		dump(event_data)
		if event_data.status_code != 200 {
			panic('request not 200: $event_data.status_code')
		}
		api.update_context(event_data.header) or { panic('Extract request ID: $err') }
		// # Extract request ID by scraping response headers received above
		aws_request_id := api.context.aws_request_id

		content_type := event_data.header.get(http.CommonHeader.content_type) or {
			panic('response without content type!')
		}
		if content_type != 'application/json' {
			panic('expected content type application/json - got "$content_type"')
		}
		event := json2.raw_decode(event_data.text) or { panic('json decode $err') }

		// Run the handler function from the script
		handler_response := handler(event, api.context)

		api.response(aws_request_id, handler_response) or { panic('response: $err') }
	}
}

struct LambdaRuntimeEnvironment {
	aws_lambda_runtime_api          string // AWS_LAMBDA_RUNTIME_API – (Custom runtime) The host and port of the runtime API.
	handler                         string // _HANDLER – The handler location configured on the function.
	aws_region                      string // AWS_REGION – The AWS Region where the Lambda function is executed.
	aws_execution_env               string // AWS_EXECUTION_ENV – The runtime identifier, prefixed by AWS_Lambda_—for example, AWS_Lambda_java8.
	aws_lambda_function_name        string // AWS_LAMBDA_FUNCTION_NAME – The name of the function.
	aws_lambda_function_memory_size string // AWS_LAMBDA_FUNCTION_MEMORY_SIZE – The amount of memory available to the function in MB.
}

pub struct Context {
	// once on init from environment
	memory_limit_in_mb int    = os.getenv('AWS_LAMBDA_FUNCTION_MEMORY_SIZE').int() // The amount of memory available to the function in MB.
	function_name      string = os.getenv('AWS_LAMBDA_FUNCTION_NAME') // The name of the function.
	function_version   string = os.getenv('AWS_LAMBDA_FUNCTION_VERSION') // The version of the function being executed.
	log_stream_name    string = os.getenv('AWS_LAMBDA_LOG_STREAM_NAME') // The name of the Amazon CloudWatch Logs group and stream for the function.
	log_group_name     string = os.getenv('AWS_LAMBDA_LOG_GROUP_NAME')
pub mut: // on every request from header
	client_context       json2.Any // The client context sent by the AWS Mobile SDK with the invocation request. This value is returned by the Lambda Runtime APIs as a header. This value is populated only if the invocation request originated from an AWS Mobile SDK or an SDK that attached the client context information to the request.
	identity             json2.Any // The information of the Cognito identity that sent the invocation request to the Lambda service. This value is returned by the Lambda Runtime APIs in a header and it's only populated if the invocation request was performed with AWS credentials federated through the Cognito identity service.
	deadline             i64       // Lambda-Runtime-Deadline-Ms
	invoked_function_arn string    // he fully qualified ARN (Amazon Resource Name) for the function invocation event. This value is returned by the Lambda Runtime APIs as a header.
	aws_request_id       string    // The AWS request ID for the current invocation event. This value is returned by the Lambda Runtime APIs as a header.
	xray_trace_id        string    // The X-Ray trace ID for the current invocation. This value is returned by the Lambda Runtime APIs as a header. Developers can use this value with the AWS SDK to create new, custom sub-segments to the current invocation.
}

// TODO: implement ClientContext
// pub struct ClientContext {
// }

// type ClientContextType = json2.Any | none

// TODO: implement CognitoIdentity
// pub struct CognitoIdentity {}

// type CognitoIdentityType = json2.Any | none

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
	aws_lambda_runtime_api string
	handler                string
	// invocation_next string = 'http://${os.getenv('AWS_LAMBDA_RUNTIME_API')}/2018-06-01/runtime/invocation/next'
	req_incocation_next http.Request
mut:
	context Context
}

fn (lr LambdaAPI) response_url(request_id string) string {
	return 'http://$lr.aws_lambda_runtime_api/2018-06-01/runtime/invocation/$request_id/response'
}

fn new_lambda_api() LambdaAPI {
	aws_lambda_runtime_api := os.getenv('AWS_LAMBDA_RUNTIME_API')
	handler := os.getenv('_HANDLER')
	return LambdaAPI{
		aws_lambda_runtime_api: aws_lambda_runtime_api
		handler: handler
		context: Context{}
		req_incocation_next: http.Request{
			method: http.Method.get
			url: 'http://$aws_lambda_runtime_api/2018-06-01/runtime/invocation/next'
			read_timeout: -1 // wait for ever
		}
	}
}

fn (lr LambdaAPI) invocation_next() ?http.Response {
	return lr.req_incocation_next.do()
}

fn (lr LambdaAPI) response(request_id string, body string) ? {
	http.post('http://$lr.aws_lambda_runtime_api/2018-06-01/runtime/invocation/$request_id/response',
		body) ?
}

fn (mut lr LambdaAPI) update_context(header http.Header) ? {
	lr.context.invoked_function_arn = header.get_custom('Lambda-Runtime-Invoked-Function-Arn') ?
	lr.context.aws_request_id = header.get_custom('Lambda-Runtime-Aws-Request-Id') ?
	if trace_id := header.get_custom('X-Amzn-Trace-Id') {
		lr.context.xray_trace_id = trace_id
	}
	if deadline := header.get_custom('Lambda-Runtime-Deadline-Ms') {
		lr.context.deadline = deadline.i64()
	}
	if cc := header.get_custom('Lambda-Runtime-Client-Context') {
		lr.context.client_context = json2.raw_decode(cc) ?
	}
	if identity := header.get_custom('Lambda-Runtime-Cognito-Identity') {
		lr.context.identity = json2.raw_decode(identity) ?
	}
}

// https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html#runtimes-api-initerror
fn (lr LambdaAPI) error_initialization(category_reason string, error_request ErrorRequest) {
	mut header := http.new_header(key: .content_type, value: 'application/json')
	header.add_custom('Lambda-Runtime-Function-Error-Type', category_reason) or { panic(err) }
	println('http://$lr.aws_lambda_runtime_api/runtime/init/error')
	resp := http.fetch(http.FetchConfig{
		url: 'http://$lr.aws_lambda_runtime_api/runtime/init/error'
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

// https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html#runtimes-api-initerror
fn (lr LambdaAPI) error_invocation(category_reason string, error_request ErrorRequest, request_id string) {
	mut header := http.new_header(key: .content_type, value: 'application/json')
	header.add_custom('Lambda-Runtime-Function-Error-Type', category_reason) or { panic(err) }
	println('http://$lr.aws_lambda_runtime_api/runtime/init/error')
	resp := http.fetch(http.FetchConfig{
		url: 'http://$lr.aws_lambda_runtime_api/runtime/invocation/$request_id/error'
		method: http.Method.post
		header: header
		data: json2.encode<ErrorRequest>(error_request)
	}) or { panic('error post error_invocation: $err') }
	if resp.status_code != 202 {
		println(resp.text)
		panic('error error_invocation status_code: $resp.status_code')
	}
	exit(1)
}