require 'gzip'
require 'network_message.rb'

class HttpMessage

	RequestTypes = "GET|HEAD|POST|DELETE|PUT|TRACE|OPTIONS|CONNECT".split("|")
	ResponseTypes = "HTTP\/1.0|HTTP\/1.1".split("|")
	def self.extract_header(string)
		new_string = string.dup
		header = new_string.slice!(/^(?>#{(RequestTypes + ResponseTypes).join("|")})\s+.*?(\r\n\r\n)/mi)
		return header,new_string
	end
	def self.is_message?(string)
		is_request?(string) || is_response?(string)
	end
	def self.is_request?(string)
		if string =~ /^(#{RequestTypes.join("|")})\s/i then true else false end
	end
	def self.is_response?(string)
		if string =~ /^(#{ResponseTypes.join("|")})\s/i then true else false end
	end

	def self.encode(message,options)
		http_message = self.new
		http_message.message = message
		http_message.options = options
		http_message.to_s
	end

	def request_info
		if HttpMessage.is_request?(@options["id"])
			request = @options["id"].dup

			request_type = request.slice!(/^([a-zA-Z]+)\s/).gsub(/\s*([a-zA-Z]+)\s+/i,"\\1")
			resource = "." + request.slice!(/^([^?\s]+)/)
			args = request.slice!(/^([^\s]+)\s/)
			args = args.gsub(/(.*)\s+/,"\\1").gsub(/^\?/,"").split("&") if args
			resource
			return request_type,resource,args
		end
	end

	def to_s
		string_priorities = "id,Host,md5-digest,Content-Encoding,Content-Length,Content-Type,Transfer-Encoding".split(",")
		if @message != ""
			if @options["Content-MD5"] != nil
				@options["Content-MD5"] = Digest::MD5.hexdigest(if options["Content-Encoding"] == "gzip" then @message.gzip else @message end)
			end
			if @message != "" && @options["Transfer-Encoding"] == nil then
				@options["Content-Length"] = (if @options["Content-Encoding"] == "gzip" then @message.gzip.length.to_s else @message.length.to_s end)
			end
		end
		options_array = [];@options.each{|k,v| options_array << [k,v] };
		options_array.sort!{|a,b| (string_priorities.find_index(a[0])||2) <=> (string_priorities.find_index(b[0])||2) }
		string = options_array.collect{|a| if a[0] =~ /^id$/ then a[1] else a.join(": ") end }.join("\r\n") + "\r\n\r\n"
		if @message != "" then
			if @options["Transfer-Encoding"] == "chunked" then
				string += NetworkMessage.encode(@message) + NetworkMessage.encode("")
			else
				string += (if @options["Content-Encoding"] == "gzip" then @message.gzip else @message end) + "\r\n\r\n"
			end
		end
		puts self.to_yaml
		return string
	end

	def self.decode string
		if is_message?(string)
			header,message = extract_header(string)
			options = {}
			unprocessed = ""
			options["id"] = header.slice!(/^(#{(RequestTypes + ResponseTypes).join("|")})\s+.*?\r\n/m).gsub("\r\n","")
			header.split("\r\n").each{|line|
				options[line.slice!(/^.*?:\s*/).gsub(/:\s*/,'')] = line
			}
			
			http_message = HttpMessage.new
			http_message.options = options
			p message
			message_complete = false
			if options["Transfer-Encoding"] == "chunked"

				while NetworkMessage.decode(message) != nil do
					dechunked_message,message = NetworkMessage.decode(message)

					http_message.message += dechunked_message 
					unprocessed = message
					pp message
				end 
			elsif options["Content-Length"] != nil
				http_message.message = message[0...(options["Content-Length"].to_i)]
				unprocessed = message[(http_message.message.length + 2)..-1]
				if options["Content-Encoding"] == "gzip" then http_message.message = http_message.message.gunzip end	
			else
				http_message.message = message
				if options["Content-Encoding"] == "gzip" then http_message.message = http_message.message.gunzip end	
			end

			return  unprocessed,http_message
		else
			return nil
		end
	end

	attr_accessor :options,:message
	def initialize
		@options = {}
		@message = ""
	end
end

# wholly cow, I can't beleive I used to test this way!!!!!!  irb testing string
$test_response = "HTTP/1.1 200 OK\r\nunidentified data: 1234567\r\nTransfer-Encoding: chunked\r\n\r\n#{"Test Message".gzip.length.to_s(16)}\r\n#{"Test Message".gzip}\r\n0\r\n\r\n"
$test_request = "GET / HTTP/1.1\r\nHost: 192.168.2.197:8888\r\nJunk Data: 123454\r\n\r\n"
