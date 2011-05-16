# The encoding of the Network message is the same as what is used by http when sending chunked messages
# to give the clients a heads up as to how big the following message is to be.
# The format is the size of the message in hexidecimal followed by a carrage return and a newline
# character followed by a carrage return and a newline
#$encryption = true
require 'gzip'
begin
require 'string-encrypt'
rescue
	puts "string-encrypt not installed, install with gem install string-encrypt"
end

class NetworkMessage
	def self.encode string,encryption_key=:no_encryption
		encrypted_string = (if encryption_key != :no_encryption then string.encrypt(encryption_key) else string end).gzip
		size = encrypted_string.length
		return (size).to_s(16) + "\r\n" + encrypted_string + "\r\n"
	end
	def self.decode string,decryption_key=:no_encryption
		if string =~ /^[0-9a-fA-F]+\r{0,1}\n.*/m then
			size = string.slice(/^[0-9a-fA-F]+\r{0,1}\n/m).chomp.to_i(16)
			new_string = string.dup
			new_string.slice!(/^[0-9a-fA-F]+\r{0,1}\n/m)
			message = new_string[0...size]
			if message.length < (size) then
				return nil
			end
		else
			return nil
		end
		return (if decryption_key != :no_encryption then message.decrypt(decryption_key) else message end).gunzip,new_string[(size+2)..-1]
	end
end
