module main

import bootstrap
import x.json2

const app_version = '0.0.5'

fn main() {
	runtime := bootstrap.BootstrapConfig{
		handlers: map{
			'default': my_handler
		}
	}

	runtime.process()
}

fn my_handler(event string, context string) string {
	handler_response := 'ECHO $app_version: $event'
	// create api gateway response
	// TODO: detect api gateway event
	mut api_gateway_response := map[string]json2.Any{}
	api_gateway_response['statusCode'] = 200
	// api_gateway_response['header']=map[string]json2.Any{}
	api_gateway_response['body'] = handler_response
	return api_gateway_response.str()
}
