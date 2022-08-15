#!/bin/bash

################################################################################
# Script for installing Nginx RTMP module
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
#
# Place this content in it and then make the file executable:
# sudo chmod +x hls_streaming.sh
################################################################################
#
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Provide Email to register ssl certificate
ADMIN_EMAIL="hls@example.com"
# Set the website name
WEBSITE_NAME="example.com"

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
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

# Install Nginx and Nginx RTMP module
sudo apt install -y nginx-full libnginx-mod-rtmp 
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

mkdir -p /var/www/hls
mkdir -p /var/www/dash
sudo chown -R www-data:www-data /var/www/hls/
sudo chown -R www-data:www-data /var/www/dash/

# Install FFMPEG
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg x264 x265

# Edit the nginx conf
sudo echo "" > /etc/nginx/nginx.conf
sudo cat <<EOF > /etc/nginx/nginx.conf

###############################################################################
load_module "modules/ngx_rtmp_module.so";

worker_processes  auto;
# error_log  logs/error.log;

pid   /var/run/nginx.pid;

events {
    worker_connections 1024;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;                        # Listen on standard RTMP port
	listen [::]:1935 ipv6only=on;
        chunk_size 4096;
	
	allow publish 127.0.0.1;
	allow publish 192.168.254.0/24;      
        deny publish all;
	
        application hmtv {
            live on;                        # Allows live input
	    record off;
	    deny play all;                  # Disable consuming the stream from nginx as rtmp
		
            # This is the HLS application		
            hls on;                         # Enable HTTP Live Streaming
            hls_path /var/www/hls;          # HLS fragments path
            hls_fragment 3;
            hls_playlist_length 60;
	    hls_continuous on;
	    hls_cleanup on;                 # Delete fragments on restart/shutdown
	      
            # This is the Dash application
	    dash on;
            dash_path /var/www/dash;        # Dash fragments path
            dash_fragment 3; 
            dash_playlist_length 60;
            dash_cleanup on;
        }
    }
}
            
http  {
       include       mime.types;
       sendfile on;
       tcp_nopush on;
       #aio on;
       directio 512;
       default_type application/octet-stream;
       keepalive_timeout  65;
    
       client_max_body_size 128M;
       
       # HTTP server required to serve the player and HLS fragments
       server {
                listen 8080;
		listen [::]:8080;
                server_name example.com;
		
		root /var/www/html;
                index index.html;
    
		# Serve HLS fragments
		location /hls {
                        add_header Cache-Control no-cache;               # Disable cache
			
			# CORS setup
                        add_header 'Access-Control-Allow-Origin' '*' always;
                        add_header 'Access-Control-Expose-Headers' 'Content-Length';

                        # allow CORS preflight requests
                        if (\$request_method = 'OPTIONS') {
                           add_header 'Access-Control-Allow-Origin' '*';
                           add_header 'Access-Control-Max-Age' 1728000;
                           add_header 'Content-Type' 'text/plain charset=UTF-8';
                           add_header 'Content-Length' 0;
                           return 204;
                         }
			 
			types {
				application/vnd.apple.mpegurl m3u8;
				video/mp2t ts;
			}
			        root /var/www;
                                				
		        }
		
                 # Serve DASH fragments
                 location /dash {
                        types {
                                 application/dash+xml mpd;
                                 video/mp4 mp4;
                        }
		                 root /var/www;
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

sudo systemctl reload nginx
sudo systemctl restart nginx

sudo ufw allow 1935/tcp
sudo ufw allow 8080/tcp
sudo ufw disable && sudo ufw enable

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "hls@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt-get remove certbot
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo systemctl reload nginx  
  echo "\n============ SSL/HTTPS is enabled! ========================"
else
  echo "\n==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo nginx -t 


 
