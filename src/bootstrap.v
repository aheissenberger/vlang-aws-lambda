module main

import os
import net.http
import x.json2

const app_version = '0.0.3'

struct LambdaAPI {
	api             string = os.getenv('AWS_LAMBDA_RUNTIME_API')
	invocation_next string = 'http://${os.getenv('AWS_LAMBDA_RUNTIME_API')}/2018-06-01/runtime/invocation/next'
}

fn (lr LambdaAPI) response_url(request_id string) string {
	return 'http://$lr.api/2018-06-01/runtime/invocation/$request_id/response'
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

fn (lr LambdaAPI) error_initialization(category_reason string, error_request ErrorRequest) {
	mut header := http.new_header(key: .content_type, value: 'application/json')
	header.add_custom('Lambda-Runtime-Function-Error-Type', category_reason) or { panic(err) }
	println('http://$lr.api/runtime/init/error')
	resp := http.fetch('http://$lr.api/runtime/init/error', http.FetchConfig{
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

fn main() {
	println('init V $app_version')
	lambda_api := LambdaAPI{}
	println('init V conf:')
	dump(lambda_api)
	req_incocation_next := http.Request{
		method: http.Method.get
		url: lambda_api.invocation_next
		read_timeout: -1 //wait for ever
	}
	for {
		println('waiting V')
		// Get an event. The HTTP request will block until one is received
		event_data := req_incocation_next.do() or {
		// event_data := http.get(lambda_api.invocation_next) or {
			panic('invocation api failed: $err')
			// if err is Error {
			// 	panic('invocation api failed: $err')
			// }
			// println('timeout waiting api invocation_next')
			// continue
		}
		dump(event_data)
		if event_data.status_code!= 200 {
			panic('request not 200: ${event_data.status_code}')
		}
		println('Extract request ID')
		// # Extract request ID by scraping response headers received above
		request_id := event_data.header.get_custom('Lambda-Runtime-Aws-Request-Id', {}) or {
			// println('Extract request ID: $err')
			// continue
			panic('Extract request ID: $err')
			// lambda_api.error_initialization('runtime.request_id',
			// 	error_message: 'extracting request id failed'
			// 	error_type: 'InvalidRequestId'
			// )
		}
		println('run handler request_id: $request_id')
		// Run the handler function from the script
		handler_response := my_handler(event_data.text, event_data)

		// Send the response
		println('response V')

		// create api gateway response
		//TODO: detect api gateway event
		mut api_gateway_response := map[string]json2.Any{}
		api_gateway_response['statusCode']=200
		//api_gateway_response['header']=map[string]json2.Any{}
		api_gateway_response['body']=handler_response
		// post_response :=
		http.post(lambda_api.response_url(request_id), api_gateway_response.str()) or { panic('api response: $err') }
		// dump(post_response)
	}
}

fn my_handler(event string, context http.Response) string {
	return 'ECHO $app_version: $event'
}
