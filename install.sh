sudo apt update
sudo apt -y upgrade

# Install FFMPEG
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt update

sudo apt install -y ffmpeg
ffmpeg -version

sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev

sudo mkdir ~/build && cd ~/build

# Download & unpack latest nginx-rtmp (you can also use http)
sudo git clone git://github.com/arut/nginx-rtmp-module.git

# Download & unpack nginx (you can also use svn)
sudo wget http://nginx.org/download/nginx-1.19.6.tar.gz
sudo tar xzf nginx-1.19.6.tar.gz
cd nginx-1.19.6

# Build nginx with nginx-rtmp
sudo ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module
sudo make
sudo make install

# Start nginx server
sudo /usr/local/nginx/sbin/nginx

# Setup live streaming
cd /usr/local/nginx/conf/
sudo echo "" > nginx.conf
sudo vim nginx.conf

paste the below code

#############################################################################

#user  nobody;
worker_processes  1;

error_log  logs/error.log debug;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8080;
        server_name  localhost;

        # sample handlers
        #location /on_play {
        #    if ($arg_pageUrl ~* localhost) {
        #        return 201;
        #    }
        #    return 202;
        #}
        #location /on_publish {
        #    return 201;
        #}

        #location /vod {
        #    alias /var/myvideos;
        #}

        # rtmp stat
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        location /stat.xsl {
            # you can move stat.xsl to a different location
            root /usr/build/nginx-rtmp-module;
        }

        # rtmp control
        location /control {
            rtmp_control all;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}

rtmp {
    server {
        listen 1935;
        ping 30s;
        notify_method get;

        application myapp {
            live on;

            # sample play/publish handlers
            #on_play http://localhost:8080/on_play;
            #on_publish http://localhost:8080/on_publish;

            # sample recorder
            #recorder rec1 {
            #    record all;
            #    record_interval 30s;
            #    record_path /tmp;
            #    record_unique on;
            #}

            # sample HLS
            #hls on;
            #hls_path /tmp/hls;
            #hls_sync 100ms;
        }

        # Video on demand
        #application vod {
        #    play /var/Videos;
        #}

        # Video on demand over HTTP
        #application vod_http {
        #    play http://localhost:8080/vod/;
        #}
    }
}


######################################################################

# Restart Nginx
sudo /usr/local/nginx/sbin/nginx -s stop
sudo /usr/local/nginx/sbin/nginx

# Statistics
Navigate your browser to http://localhost:8080/stat 
to see current streaming statistics, connected clients, bandwidth etc.

# Publish
ffmpeg -re -i /var/Videos/test.mp4 -c copy -f flv rtmp://localhost/myapp/mystream
