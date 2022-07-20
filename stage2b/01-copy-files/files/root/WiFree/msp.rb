#encoding: utf-8
$LOAD_PATH.unshift(File.dirname(__FILE__))

def gen_msp(values)
	sequence = [:throttle, :aileron, :elevator, :rudder, :aux1, :aux2, :aux3, :aux4 ]

	data = sequence.map{|k| values[k]||1500}
	msp(200, data)
end

def msp(command, data)
	crc= 0
	
	res = [data.length*2, command] + data.pack("v*").bytes
	res.each{|d| crc ^= d}
	res << crc
	
	"$M<" + res.pack("c*")
end


if __FILE__==$0
	data = [1200,1300,1400,1500,1600,1700,1800,1900] 
	command = 200
	
	require 'serialport'
	
	SerialPort.open('COM17', :baud=>9600, :data_bits => 8, :stop_bits => 1, :parity => SerialPort::NONE) do |sp|
		warn "sp open"
		values = {:throttle => 1100, :aileron => 1200, :elevator => 1300, :rudder => 1400, :aux1 => 1500, :aux2 => 1600, :aux3 => 1700, :aux4 => 1800}
		loop do
			sp.write(gen_msp(values))		
			[:throttle, :aileron, :rudder].each do |k|
				values[k] += 1
				values[k] = 1000 if values[k]> 2000
			end
		end
	end
end

__END__

