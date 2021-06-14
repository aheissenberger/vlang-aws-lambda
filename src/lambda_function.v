module main
import os
import net.http

struct LambdaAPI {
	api string = os.getenv('AWS_LAMBDA_RUNTIME_API')
	invocation_next string = 'http://${os.getenv('AWS_LAMBDA_RUNTIME_API')}/2018-06-01/runtime/invocation/next'
}

fn  (lr LambdaAPI) response_url(request_id string) string {
	return 'http://${lr.api}/2018-06-01/runtime/invocation/${request_id}/response'
}

fn main(){
	println('init V')
	lambda_api := LambdaAPI{}

	for {
		println('waiting V')
		// Get an event. The HTTP request will block until one is received
		event_data := http.get( lambda_api.invocation_next) or {panic('$err')}

		// # Extract request ID by scraping response headers received above
		request_id := event_data.header.get_custom('Lambda-Runtime-Aws-Request-Id',{}) or {panic('$err')}

		// Run the handler function from the script
		response := my_handler(event_data.text, event_data)

		// Send the response
		post_response := http.post(lambda_api.response_url(request_id), response) or {
			panic('$err')
		}
		dump(post_response)

	}

}

fn my_handler(event string, context http.Response) string {
	return 'ECHO: $event'
}