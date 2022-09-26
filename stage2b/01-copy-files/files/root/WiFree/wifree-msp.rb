#!/usr/bin/ruby
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'webrick'
require 'socket'
require 'json'

require 'msp'
require 'serialport'

$params_file = "/data/params.json"

$params = {
	"CHANNEL" => 1,
	"IWSIGMIN" => -75,
	"FPS" => 40,
	"FPS_RECORD" => 30,
	"GOP" => 10,
	"VSTAB" => true,
	"CODEC" => "H264"
}

$values = { 
	:throttle => 1000, 
	:aileron => 1500, 
	:elevator => 1500, 
	:rudder=> 1500,
	:aux1 => 1000,
	:aux2 => 1000,
	:aux3 => 1000,
	:aux4 => 1000
}

$value_ms = 0
	

$hold  = false
$sender = nil
$armed = false


Thread.new do
	begin
		SerialPort.open('/dev/ttyAMA0', :baud => 9600, :data_bits => 8, :stop_bits => 1, :parity => SerialPort::NONE) do |sp|
			loop do
				pkt = gen_msp($values)
				sp.write(pkt)
				sleep 0.022
			end
		end
	rescue
		sleep 0.1
		retry
	end
end


def emergency
	# $hold = true
	# $values[:aux2] = 2000
end

def all_clear
	$hold = false
	$values[:aux2] = 1000
end

def show_values
#	warn $values.to_s
end

def b2s(v)
	(1500+v/127.0*500).to_i
end


Thread.new do 
begin
	sock = UDPSocket.new
	udp_port = 9988
	wifidev = "wlan0"
	wifidev = "wlan1" if File.exists?("/sys/class/net/wlan1")
	
	loop do

		if (($value_ms > 0) && (((Time.now.to_f*1000).to_i - $value_ms) > 500))
			emergency
		end
		
		next if $sender.nil?

		mac = (IO.readlines("/proc/net/arp").grep(Regexp.new($sender[2]))[0]||"").split(/ +/)[3]
		# iwsig=`iw dev wlan0 station dump`.scan(/\tsignal avg:+\t([-\d]+) dBm/).flatten.map{|f| f.to_i}.min
		iwsig=`iw dev #{wifidev} station get #{mac}`.scan(/\tsignal:\s+([-\d]+).* dBm/).flatten.map{|f| f.to_i}.min

		if (iwsig.nil? or (iwsig < $params['IWSIGMIN'])) && $armed
			emergency
		end
		msg = "Signal: #{iwsig}, Rescue: #{$hold}"
		if $sender
			sock.send(msg, 0, $sender[2], udp_port)
		end
		sleep 0.3
	end
rescue
	retry
end
end

Thread.new do 
	loop do
		show_values
		sleep 0.5
	end
end


Thread.new do 
	s = UDPSocket.new
	s.bind("0.0.0.0", 23)
	loop do
		text, $sender = s.recvfrom(16)
		tmp = text.unpack("c*")
		STDOUT.flush
	
		x,y,u,v,b = tmp
		if b < -20
			$armed = false
		else
			$armed = true
		end
		
		$values[:throttle] = b2s(y)
		$values[:aileron] = b2s(x)
		$values[:elevator] = b2s(u)
		$values[:rudder] = b2s(v)
		$values[:aux1] = b2s(b)

		$value_ms = (Time.now.to_f*1000).to_i		
	end
end


def load_params
	p loaded = JSON.parse(IO.read($params_file))
	$params.merge!(loaded)
	$params['CHANNEL'] = IO.read('/data/channel.conf').split('=')[1].to_i
	$params['PSK'] = IO.read('/data/key.conf').split('=')[1].strip
end

def save_params
	system("mount -o remount,rw /data")
	File.open($params_file,"w"){|f| f.write($params.to_json)}
ensure
	system("mount -o remount,ro /data")
end


def start_raspivid1(ip, record=false)
	system("killall raspivid")
	tee = ""
	if record
		n = 0
		if last_file = Dir.glob("/video/video-????.*").sort.last
			n = last_file.split('-')[1].to_i
		end
		n += 1
		new_file = sprintf("/video/video-%04d.#{$params['CODEC'].downcase}", n)
		tee = " | tee #{new_file} "
	end

	vstab = $params['VSTAB'] ? '--vstab' : ''
	gop = $params['GOP']
	fps = record ? $params['FPS_RECORD'] : $params['FPS']

	if $params['CODEC'] == "H264"
		system("raspivid #{vstab} -pf baseline -fl -g #{gop} -n -w 640 -h 480 -b 4500000 -fps #{fps}  -t 0 -pf high -o - #{tee} | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay ! udpsink host=#{ip} port=5200 &")
	else
		system("raspivid -t 0 -cd MJPEG -n -w 640 -h 480 -b 2500000 -fps 30 -o - #{tee} | gst-launch-1.0 -v fdsrc ! jpegparse ! rtpjpegpay ! udpsink host=#{ip} port=5200 &")
	end


end

def start_raspivid(ip, record=false)
        system("killall wfpicam.py")
        tee = ""
	new_file = ""
        if record
                n = 0
                if last_file = Dir.glob("/video/video-????.*").sort.last
                        n = last_file.split('-')[1].to_i
                end
                n += 1
                new_file = sprintf("/video/video-%04d.h264", n)
                tee = " -o #{new_file} "
        end

        vstab = $params['VSTAB'] ? '--vstab' : ''
        gop = $params['GOP']
        fps = record ? $params['FPS_RECORD'] : $params['FPS']

        if $params['CODEC'] == "H264"
		system("/root/WiFree/wfpicam.py -s #{tee} -f h264 | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay ! udpsink host=#{ip} port=5200 &")
        else
		system("/root/WiFree/wfpicam.py -s #{tee} -f mjpeg | gst-launch-1.0 -v fdsrc ! jpegparse ! rtpjpegpay ! udpsink host=#{ip} port=5200 &")
        end

end


def videolist
	lis = Dir.glob("/video/*.{mjpeg,h264,mp4}").map{|f| [File.basename(f), File.size(f)]}.sort
	usage = `df -h /video|grep video`.split(/ +/).values_at(3,1)
	{:list => lis, :usage => usage}	
end

server = WEBrick::HTTPServer.new(:Port => 8000, :DocumentRoot => '/video')

server.mount_proc '/cam_on' do |req,res|
        ip = $sender.nil? ? req.remote_ip : $sender[2]
	start_raspivid(ip)
end

server.mount_proc '/record_on' do |req,res|
        ip = $sender.nil? ? req.remote_ip : $sender[2]
	start_raspivid(ip, record=true)
end


server.mount_proc '/cam_off' do |req,res|
        system("killall raspivid ; killall wfpicam.py")
end

server.mount_proc '/params' do |req,res|
	res.body = $params.to_json
end

server.mount_proc '/apply' do |req,res|
	n = JSON.parse(req.query['value'])
	$params.merge!(n)
	res.body = $params.to_json
end

server.mount_proc '/saveChannel' do |req,res|
	n = req.query['channel'].to_i
	minsig = req.query["minsig"]
	psk = req.query["psk"] || $params['PSK']
	vstab = (req.query['vstab']||$params['VSTAB'].to_s)  == "true" ? true : false
	gop = req.query['gop']||$params['GOP']
	codec = req.query['codec']||$params['CODEC']
	restart = ((n != $params['CHANNEL']) || (psk != $params['PSK']))
	
	$params['CHANNEL'] = n
	$params['IWSIGMIN'] = minsig.to_i
	$params['PSK'] = psk
	$params['GOP'] = gop.to_i
	$params['VSTAB'] = vstab
	$params['CODEC'] = codec
	save_params
	if restart
		system("/data/set_channel.sh #{n} #{psk}")
	end
end

server.mount_proc '/save' do |req,res|
	n = JSON.parse(req.query['value'])
	$params.merge!(n)
	res.body = $params.to_json
	save_params
end

server.mount_proc '/rescue' do |req,res|
	emergency
end

server.mount_proc '/reset' do |req,res|
	all_clear
end

server.mount_proc '/shutdown' do |req,res|
	system("/bin/systemctl halt")
end

server.mount_proc '/reboot' do |req,res|
	system("/bin/systemctl reboot")
end

server.mount_proc '/listfiles' do |req,res|
	res.content_type = "application/json"
	res.body = videolist.to_json
end

server.mount_proc '/deletefile' do |req,res|
	system("rm /video/" + req.query['file'])
	res.content_type = "application/json"
	res.body = videolist.to_json
end

server.mount_proc '/convertfile' do |req,res|
	file = req.query['file']
	ext = File.extname(file)[1..-1]
	mp4 = file.sub(".#{ext}",'.mp4')
	system("avconv  -r #{$params['FPS_RECORD']} -f #{ext} -i /video/#{file} -vcodec copy /video/#{mp4}")
	res.content_type = "application/json"
	res.body = videolist.to_json
end

server.mount_proc '/video_df' do |req,res|
	res.content_type = "application/json"
	res.body = `df -h /video|grep video`.split(/ +/).values_at(3,1).to_json
end


trap 'INT' do server.shutdown end

load_params

server.start



