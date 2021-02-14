sudo apt update
sudo apt -y upgrade

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg
ffmpeg -version

# Install nginx dependencies
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev git

sudo mkdir ~/build && cd ~/build

# Clone nginx-rtmp-module
git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git

# Download nginx
sudo wget http://nginx.org/download/nginx-1.19.6.tar.gz
sudo tar xzf nginx-1.19.6.tar.gz
cd nginx-1.19.6

# Build nginx with nginx-rtmp
sudo ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module
sudo make -j 1
sudo make install

# Start nginx server
sudo /usr/local/nginx/sbin/nginx

# Setup live streaming
cd /usr/local/nginx/conf/
sudo echo "" > nginx.conf
sudo cat <<EOF > nginx.conf

#############################################################################
#user  nobody;
worker_processes  auto;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;        # Listen on standard RTMP port
        chunk_size 4000;

        application stream {
            live on;
            # pull rtmp://origin-rtmp-server:1935/live name=m3tv static; 
            
            # Turn on HLS
            hls on;
            hls_path /usr/local/nginx/html/stream/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # MPEG-DASH is similar to HLS
            dash on;
            dash_path /usr/local/nginx/html/stream/dash;
            dash_fragment 5;
            dash_playlist_length 30;
                
            # disable consuming the stream from nginx as rtmp
            deny play all;
        }
    }
}
            
http {
    sendfile off;
    tcp_nopush on;
    # aio off;
    directio 512;
    
    include       mime.types;
    default_type application/octet-stream;

    server {
        listen 8080;
        server_name example.com;

        # This URL provides RTMP statistics in XML
        location /stat {
            rtmp_stat all;

            # Use this stylesheet to view XML as web page
            # in browser
            rtmp_stat_stylesheet /usr/local/nginx/html/stat.xsl;
        }

        location /stat.xsl {
            # XML stylesheet to view RTMP stats.
            # Copy stat.xsl wherever you want
            # and put the full directory path here
            root /usr/local/nginx/html;
        }

        location /hls {
            # Serve HLS fragments
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            
            # Disable cache
            root /usr/local/nginx/html/stream;
            add_header Cache-Control no-cache;

            # CORS setup
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length';

            # Allow CORS preflight requests
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }
        }

        location /dash {
            # Serve DASH fragments
            types {
                application/dash+xml mpd;
                video/mp4 mp4;
            }
            
            # Disable cache
            root /usr/local/nginx/html/stream;
            add_header Cache-Control no-cache;

            # CORS setup
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length';

            # Allow CORS preflight requests
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }
        }
    }
}

######################################################################
EOF

# Restart Nginx
sudo /usr/local/nginx/sbin/nginx -s stop
sudo /usr/local/nginx/sbin/nginx

# Publish
# ffmpeg -re -i /var/Videos/test.mp4 -c copy -f flv rtmp://localhost/myapp/mystream
