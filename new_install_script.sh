#!/bin/bash

################################################################################
# Script for installing Nginx RTMP module
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
#
# Place this content in it and then make the file executable:
# sudo chmod +x install.sh
################################################################################
#
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"
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
sudo apt update 
sudo apt upgrade -y
sudo apt autoremove -y

# Setup the timezone
sudo dpkg-reconfigure tzdata

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg x264 x265

# Install necessory packages
sudo apt install -y software-properties-common build-essential git tree

sudo mkdir ~/build && cd ~/build

# Clone nginx-rtmp-module
git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git

# Download the mandatory Nginx dependencies' source code and extract it
# PCRE version 8.44
wget https://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz && tar xzvf pcre-8.44.tar.gz

# zlib version 1.2.11
wget https://www.zlib.net/zlib-1.2.11.tar.gz && tar xzvf zlib-1.2.11.tar.gz

# OpenSSL version 1.1.1g
wget https://www.openssl.org/source/openssl-1.1.1g.tar.gz && tar xzvf openssl-1.1.1g.tar.gz

# Install optional Nginx dependencies
sudo apt install -y perl libperl-dev libgd3 libgd-dev libgeoip1 libgeoip-dev geoip-bin libxml2 libxml2-dev libxslt1.1 libxslt1-dev

# Remove the tarball files
rm -rf *.tar.gz

# Download nginx
sudo wget http://nginx.org/download/nginx-1.19.6.tar.gz && sudo tar zxvf nginx-1.19.6.tar.gz
cd nginx-1.19.6

tree -L 2 .

sudo cp ~/nginx-1.19.6/man/nginx.8 /usr/share/man/man8
sudo gzip /usr/share/man/man8/nginx.8
ls /usr/share/man/man8/ | grep nginx.8.gz

# Check that man page for Nginx is working
man nginx

# Build nginx with nginx-rtmp
sudo ./configure --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --user=nginx \
            --group=nginx \
            --build=Ubuntu \
            --builddir=nginx-1.19.6 \
            --with-select_module \
            --with-poll_module \
            --with-threads \
            --with-file-aio \
            --with-http_ssl_module \
            --with-http_v2_module \
            --with-http_realip_module \
            --with-http_addition_module \
            --with-http_xslt_module=dynamic \
            --with-http_image_filter_module=dynamic \
            --with-http_geoip_module=dynamic \
            --with-http_sub_module \
            --with-http_dav_module \
            --with-http_flv_module \
            --with-http_mp4_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_auth_request_module \
            --with-http_random_index_module \
            --with-http_secure_link_module \
            --with-http_degradation_module \
            --with-http_slice_module \
            --with-http_stub_status_module \
            --with-http_perl_module=dynamic \
            --with-perl_modules_path=/usr/share/perl/5.26.1 \
            --with-perl=/usr/bin/perl \
            --http-log-path=/var/log/nginx/access.log \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --with-mail=dynamic \
            --with-mail_ssl_module \
            --with-stream=dynamic \
            --with-stream_ssl_module \
            --with-stream_realip_module \
            --with-stream_geoip_module=dynamic \
            --with-stream_ssl_preread_module \
            --with-compat \
            --with-pcre=../pcre-8.44 \
            --with-pcre-jit \
            --with-zlib=../zlib-1.2.11 \
            --with-openssl=../openssl-1.1.1g \
            --with-openssl-opt=no-nextprotoneg \
            --with-debug \
            --add-module=../nginx-rtmp-module

make
sudo make install

sudo adduser --system --shell /bin/false --no-create-home --disabled-login --disabled-password --gecos "nginx user" --group nginx
sudo ln -s /usr/lib/nginx/modules /etc/nginx/modules

# Create NGINX cache directories and set proper permissions
sudo mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/proxy_temp /var/cache/nginx/scgi_temp /var/cache/nginx/uwsgi_temp
sudo chmod 700 /var/cache/nginx/*
sudo chown nginx:root /var/cache/nginx/*

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
        listen 1935;         # Listen on standard RTMP port
	server_name $WEBSITE_NAME;
	
        chunk_size 4000;
        application live {
            live on;                   # Allows live input
			
            hls on;                    # Enable HTTP Live Streaming
            hls_path /tmp/hls;         # hls fragments path
            hls_nested on;
            hls_fragment 2s;
            hls_playlist_length 16s;
	    hls_sync 100ms;
	    
            # Instruct clients to adjust resolution according to bandwidth
            hls_variant _low BANDWIDTH=128000;          # Low bitrate, sub-SD resolution
            hls_variant _mid BANDWIDTH=512000;          # Medium bitrate, SD resolution
            hls_variant _hd720 BANDWIDTH=1024000;       # High bitrate, HD 720p resolution
	    
            # This is the Dash application
            dash on;
            dash_path /tmp/dash;       # dash fragments path
            dash_nested on;
            dash_fragment 2s;
            dash_playlist_length 16s;
	    
	    # Disable consuming the stream from nginx as rtmp
            deny play all;
        }
    }
}
            
http  {
                sendfile on;
                tcp_nopush on;
                #aio on;
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
			        root /tmp;
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
		                 root /tmp;
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

mkdir /tmp/hls
mkdir /tmp/dash

# Create Nginx systemd daemon
sudo cat <<EOF > /lib/systemd/system/nginx.service

[Unit]
Description=nginx - high performance web server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecStartPost=/bin/sleep 0.1
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
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

sudo systemctl status nginx


 
