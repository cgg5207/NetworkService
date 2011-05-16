#!/usr/bin/env ruby
require 'rubygems'
require 'time'
require 'digest/md5'
require 'base64'
require 'eventmachine'
require 'network_message'
require 'http_message'
require 'gzip'
if ARGV.length == 0 then
	port = 8888 
else
	port = ARGV[0].to_i
	if port == 0 then port = 8888 end #should probably test for < 1024
end

STDOUT.sync = true
$interface = []
$clients = []
class String
	def to_base27
		text=self;
		alph=[];('a'..'z').each_with_index{|c,i| alph<<c };
		result = ""	
		text.split(//).each{|c|i = c[0];  
			while i != 0
			       tmp_result = ""	
				r  = i%27
				print alph[r]
				tmp_result += alph[r]
				i = i/27
			end
			puts 
			result += (tmp_result.ljust(4,"a"))
		}
	end
end

module NetworkServer
	MessageTypes = "GET|HEAD|POST|DELETE|PUT|TRACE|OPTIONS|CONNECT|RUN|SET_VAR|GET_VAR"
	def post_init
		puts "post_init called"
		#send_data "welcome to my custom server\n"
		@data = ''
	end
	def send_data(data,unprocessed = false)
		if unprocessed then
			super(data)
		else
			super(NetworkMessage.encode(data))
		end
	end
	def receive_data(incomming_data)
		@data << incomming_data
		Thread.new{
		#puts "\tpre_process buffer is: #{@data.gsub("\n",'\n').gsub("\r",'\r')}"
		while NetworkMessage::decode(@data) || HttpMessage::decode(@data)
			if HttpMessage::is_message?(@data) then
				@data,http_message = HttpMessage::decode(@data)
				puts http_message.to_yaml
				if HttpMessage::is_request?(http_message.options["id"]) then
					request_type,resource,args = http_message.request_info
					case request_type.upcase
					when "GET"
						puts "getting #{resource}"
						if File.file?(resource) then 
								response = HttpMessage.encode(File.read(resource),"id" => "HTTP/1.1 200 OK","Content-Encoding" => "gzip","Content-MD5" => "","Last-Modified" => File.mtime(resource).httpdate,"Expires" => (Time.now + 3600).httpdate,"Cache-Control" => "max-age")
						elsif File.file?(resource + ".cgi") then
							response = HttpMessage.encode(`#{resource + ".cgi"} "#{args.join("&")}"`,"id" => "HTTP/1.1 200 OK","Content-Encoding" => "gzip","Content-MD5" => "","Last-Modified" => Time.now.httpdate,"Expires" => (Time.now + 3600).httpdate,"Cache-Control" => "max-age")
						elsif File.file?("404.html")
							response = HttpMessage.encode(File.read("404.html"),"id" => "HTTP/1.1 404 OK","Content-Encoding" => "gzip","Content-MD5" => "","Last-Modified" => File.mtime("404.html").httpdate,"Expires" => (Time.now + 3600).httpdate,"Cache-Control" => "max-age")
						else
							response = HttpMessage.encode("Yeah, hmmm, wow, really dropped the ball here, not even a 404 page, gadzukes","id" => "HTTP/1.1 404 OK","Content-Encoding" => "gzip","Content-MD5" => "","Last-Modified" => Time.now.httpdate,"Expires" => (Time.now + 3600).httpdate,"Cache-Control" => "max-age")
						end
						send_data(response,true)
					else
						response = HttpMessage.encode("<HTML><HEAD><TITLE>404</TITLE></HEAD><BODY><H1>Niner Niner, thats a Four Oh Four</H1><BR><H5>the request of #{request_type} is not supported</H5></BODY></HTML>","id" => "HTTP/1.1 404 OK","Content-Encoding" => "gzip")
						send_data(response,true)
					end

				end
			else
				message,@data = NetworkMessage::decode(@data)
				puts "message decoded to: #{message}"
				puts "                  : #{message.split(//).collect{|c| c[0].to_s }.join(",")}"
			end
		end
		#@data = @data.gsub(/^[^0-9]*(.*)$/m,"\\1")
		puts "\tbuffer is: #{@data.gsub("\n",'\n').gsub("\r",'\r')}"
		}
	end
end

EM.run{
	EM.start_server('0.0.0.0',port,NetworkServer)
}

