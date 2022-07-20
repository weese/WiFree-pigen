#!/usr/bin/python

import os
import sys
import getopt
import signal
import picamera

sformat = 'mjpeg'
outputfile = ""
vstab = False
gop = 10

running = True

try:
    opts, args = getopt.getopt(sys.argv[1:], "f:o:sg:")
except getopt.GetoptError:
    sys.exit()

for opt, arg in opts:
    if (opt == '-f') and (arg in ("mjpeg", "h264")):
        sformat = arg
    elif (opt == '-o'):
        outputfile = arg
    elif (opt == '-s'):
        vstab = True
    elif (opt == '-g'):
        gop = int(arg)



sys.stderr.write("format: " + sformat + "\n")
sys.stderr.write("outputfile: " + outputfile+ "\n")
sys.stderr.write("vstab: " + str(vstab)+ "\n")
sys.stderr.write("gop: " + str(gop)+ "\n")

def signal_handler(signal, frame):
    global running
    sys.stderr.write("aborting...\n")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# reopen sys.stdout in unbuffered mode
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)


# limit: 1 stream at 62,914,560 luma samples/s (~1920*1080*30)
# 1280*720*30 + 640*480*30 = 36,864,000 luma samples/s => ok
with picamera.PiCamera() as camera:
    #camera.resolution = (640, 480)
    #camera.resolution = (1920, 1080)
    camera.resolution = (1280, 720)
    camera.framerate = 30
    camera.video_stabilization = vstab
    
    if outputfile:
        #camera.start_recording(outputfile, format='h264', profile='baseline', bitrate=4500000)
        camera.start_recording(outputfile, format='h264', profile='baseline', quality=22, bitrate=20000000)
    
    if (sformat == 'mjpeg'):
        # quality=1-100(lo-hi)
        camera.start_recording(sys.stdout, format=sformat,resize=(640, 480),splitter_port=2, bitrate=80000)
        #camera.start_recording(sys.stdout, format=sformat,splitter_port=2, bitrate=80000)
    else:
        # quality=10-40(hi-lo)
        camera.start_recording(sys.stdout, format=sformat,resize=(640, 480),splitter_port=2, profile='baseline', intra_period=gop, bitrate=4500000)


    while running:
        signal.pause()

    camera.stop_recording(splitter_port=2)
    if outputfile:
        camera.stop_recording()
    
    sys.stderr.write("done.\n")
    
    
    

