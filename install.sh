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
# Update Server
#--------------------------------------------------
echo -e "\n============== Update Server ======================="
sudo apt update && sudo apt upgrade -y

# Setup timezone
sudo dpkg-reconfigure tzdata

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg x264 x265

# Install nginx dependencies
sudo apt install -y software-properties-common build-essential libpcre3 libpcre3-dev openssl libssl-dev zlib1g-dev git tree

sudo mkdir ~/build && cd ~/build

# Clone nginx-rtmp-module
git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git

# Download nginx
sudo wget http://nginx.org/download/nginx-1.19.6.tar.gz && sudo tar zxvf nginx-1.19.6.tar.gz
cd nginx-1.19.6

# Build nginx with nginx-rtmp
sudo ./configure --prefix=/usr/local/nginx \
                 --with-http_ssl_module \
                 --with-file-aio \
                 --add-module=../nginx-rtmp-module
sudo make && sudo make install

# Start nginx server
# sudo /usr/local/nginx/sbin/nginx

# Setup live streaming
sudo echo "" > /usr/local/nginx/conf/nginx.conf
sudo cat <<EOF > /usr/local/nginx/conf/nginx.conf

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
        listen 1935;         # Listen on standard RTMP port
        chunk_size 4000;

        application live {
            live on;         # Allows live input
			
            hls on;                                          # Enable HTTP Live Streaming
            hls_path /usr/local/nginx/html/show/hls;         # hls fragments path
            hls_nested on;
            hls_fragment 2s;
            hls_playlist_length 16s;
	    
            # This is the Dash application
            dash on;
            dash_path /usr/local/nginx/html/show/dash;       # dash fragments path
            dash_nested on;
            dash_fragment 2s;
            dash_playlist_length 16s;
        }
    }
}
            
http  {
                sendfile on;
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
			        root /usr/local/nginx/html/show;
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

		                 root /usr/local/nginx/html/show;
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

mkdir /usr/local/nginx/html/show
mkdir /usr/local/nginx/html/show/hls
mkdir /usr/local/nginx/html/show/dash

# Create Nginx systemd daemon
sudo cat <<EOF > /lib/systemd/system/nginx.service

[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/usr/local/nginx/sbin/nginx -s reload -c /usr/local/nginx/conf/nginx.conf
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload
sudo systemctl enable nginx.service
sudo systemctl restart nginx.service

###### Install SSL Certificates #########
sudo apt install software-properties-common -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d vps.rw --noninteractive --agree-tos --email hrmuwanika@gmail.com --redirect
sudo systemctl reload nginx
 
