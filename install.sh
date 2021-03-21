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
sudo apt update 
sudo apt upgrade -y
sudo apt autoremove -y

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg 
ffmpeg -version

# Install Nginx and RTMP module
sudo apt install -y nginx 
sudo apt install libnginx-mod-rtmp
sudo systemctl stop nginx
sudo systemctl start nginx

# Install nginx dependencies
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev 

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
        listen 1935;         # Listen on standard RTMP port
        chunk_size 4000;

        application live {
            live on;         # Allows live input
			
            hls on;                                          # Enable HTTP Live Streaming
            hls_path /var/www/html/show/hls;                 # hls fragments path
            hls_nested on;
            hls_fragment 2s;
            hls_playlist_length 16s;
	    
	    # Setup AES encryption
            # hls_keys on;
            # hls_key_path /mnt/hls/keys;
            # hls_key_url keys/;
            # hls_fragments_per_key 10;
            
            # This is the Dash application
            dash on;
            dash_path /var/www/html/show/dash;               # dash fragments path
            dash_nested on;
            dash_fragment 2s;
            dash_playlist_length 16s;
	    
	    # disable consuming the stream from nginx as rtmp
            deny play all;
        }
    }
}
            
http  {
                sendfile off;
                tcp_nopush on;
                directio 512;
    
                keepalive_timeout  65;
    
                include mime.types;
                default_type application/octet-stream;
		
    # HTTP server required to serve the player and HLS fragments
    server {
                listen 443;
                server_name vps.rw;
		       
		# Serve HLS fragments
		location /hls {
			types {
				application/vnd.apple.mpegurl m3u8;
				video/mp2t ts;
			}
			        root /var/www/html/show;
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

		                 root /var/www/html/show;
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
                                 root /var/www/html;
		        } 
	          }
           }

################################################################################################################
EOF

mkdir /var/www/html/show
mkdir /var/www/html/show/hls
mkdir /var/www/html/show/dash

###### Install SSL Certificates #########
sudo apt install software-properties-common -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d vps.rw --noninteractive --agree-tos --email hrmuwanika@gmail.com --redirect
sudo systemctl reload nginx
 
