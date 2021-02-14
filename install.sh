sudo apt update
sudo apt -y upgrade

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update
sudo apt install -y ffmpeg
ffmpeg -version

# Install nginx dependencies
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev git

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

worker_processes  auto;
events {
    worker_connections  1024;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;        # Listen on standard RTMP port
        chunk_size 4000;

        application myapp {
            live on;
            # Turn on HLS
            hls on;
            hls_path /mnt/hls/;
            hls_fragment 3;
            hls_playlist_length 60;
            # disable consuming the stream from nginx as rtmp
            deny play all;
        }
    }
}
            
http {
    sendfile off;
    tcp_nopush on;
    aio on;
    directio 512;
    default_type application/octet-stream;

    server {
        listen 8080;
        server_name example.com;

        location / {
            # Disable cache
            add_header 'Cache-Control' 'no-cache';

            # CORS setup
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';

            # allow CORS preflight requests
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }

            types {
                application/dash+xml mpd;
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }

            root /mnt/;
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
