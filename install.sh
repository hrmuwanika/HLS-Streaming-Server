#!/bin/bash

################################################################################
# Script for installing Nginx RTMP module
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
#
# Place this content in it and then make the file executable:
# sudo chmod +x install.sh
################################################################################

#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

#--------------------------------------------------
# Update your operating system’s software
#--------------------------------------------------
echo -e "\n============== Update Server ======================="
sudo apt update 
sudo apt upgrade -y
sudo apt autoremove -y

# Setup the timezone
sudo dpkg-reconfigure tzdata

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg x264 x265

# Install necassry packages
sudo apt install -y software-properties-common build-essential git tree
sudo apt install -y openssl libssl-dev libpcre3 libpcre3-dev zlib1g-dev

sudo mkdir ~/build && cd ~/build

# Clone nginx-rtmp-module
git clone --depth=1 https://github.com/arut/nginx-rtmp-module.git

# Download the latest nginx
sudo wget http://nginx.org/download/nginx-1.19.6.tar.gz
sudo tar zxvf nginx-1.19.6.tar.gz
cd nginx-1.19.6



# Build nginx with nginx-rtmp
sudo ./configure --prefix=/usr/local/nginx --add-module=../nginx-rtmp-module --with-http_ssl_module
make
sudo make install

# Setup live streaming
sudo echo "" > /etc/nginx/nginx.conf
sudo cat <<EOF > /etc/nginx/nginx.conf

#############################################################################

worker_processes  auto;
#error_log  logs/error.log;

pid   /var/run/nginx.pid;

events {
    worker_connections  1024;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;            # Listen on standard RTMP port
        chunk_size 4000;

        application live {
            live on;            # Allows live input
			
            hls on;                                          # Enable HTTP Live Streaming
            hls_path /tmp/show/hls;         # hls fragments path
            hls_nested on;
            hls_fragment 2s;
            hls_playlist_length 16s;
	    
            # This is the Dash application
            dash on;
            dash_path /tmp/show/dash;       # dash fragments path
            dash_nested on;
            dash_fragment 2s;
            dash_playlist_length 16s;
        }
    }
}
            
http  {
                sendfile off;
                tcp_nopush on;
                aio on;
                directio 512;
    
                keepalive_timeout  65;
    
                include mime.types;
                default_type application/octet-stream;
		
    # HTTP server required to serve the player and HLS fragments
    server {
                listen 443;
                server_name example.com;
		       
		# Serve HLS fragments
		location /hls {
			types {
				application/vnd.apple.mpegurl m3u8;
				video/mp2t ts;
			}
			        root /tmp/show;
                                add_header Cache-Control no-cache;       # Disable cache
				
				# CORS setup
                                add_header 'Access-Control-Allow-Origin' '*' always;
                                add_header 'Access-Control-Expose-Headers' 'Content-Length';
		        }
		
                 # Serve DASH fragments
                 location /dash {
                        types {
                                 application/dash+xml mpd;
                                 video/mp4 mp4;
                        }

		                 root /tmp/show;
                                 add_header Cache-Control no-cache;      # Disable cache
				 
				 # CORS setup
                                add_header 'Access-Control-Allow-Origin' '*' always;
                                add_header 'Access-Control-Expose-Headers' 'Content-Length';
                        }		
		
		        # This URL provides RTMP statistics in XML
		        location /stat {
			         rtmp_stat all;
                                 rtmp_stat_stylesheet stat.xsl;     # Use stat.xsl stylesheet
		        }

		        location /stat.xsl {
			         # XML stylesheet to view RTMP stats.
                                 root /usr/local/nginx/html;
		        } 
	          }
           }

################################################################################################################
EOF

mkdir /tmp/show
mkdir /tmp/show/hls
mkdir /tmp/show/dash

# Create Nginx systemd daemon
sudo cat <<EOF > /etc/systemd/system/nginx.service

[Unit]
Description=nginx - high performance web server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl enable nginx.service
sudo systemctl start nginx.service

sudo systemctl is-enabled nginx.service

###### Install SSL Certificates #########
sudo apt install software-properties-common -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d vps.rw --noninteractive --agree-tos --email hrmuwanika@gmail.com --redirect
sudo systemctl reload nginx
 
