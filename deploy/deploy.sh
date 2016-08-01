app_name=marcusshepdotcom

contains_subdirapp=true

subdirapp_name=blog_api
subdirapp_path=blog/$subdirapp_name

env_dir=/opt/envs/$subdirapp_name

nginx_conf_file=/etc/nginx/sites-enabled/default

app_location=/opt/apps

git_url=https://github.com/marcusshepp/marcusshepdotcom.git

echo "redeploying app: $app_name"

echo "removing current app: $app_name"
rm -rf $app_location/$app_name/

echo "changing dir to: $app_location"
cd $app_location

echo "cloning $git_url"
git clone $git_url

if [ $contains_subdirapp ]
then
    echo "contains a sub directoy application.."
    echo "changing directoy to sub dir application.."
    cd $app_name/$subdirapp_path
    source $env_dir/bin/activate
    ./manage.py migrate
    echo "copying gunicorn script"
    cp ../../as/deploy/gunicorn.sh .
else
    cp as/deploy/gunicorn.sh .
fi

echo "running gunicorn script"
bash gunicorn.sh

echo "checking for failures from gunicorn script"
output=$(cat /opt/proc/$subdirapp_name-gunicorn.log)
if [[ $output != *"Booting worker with pid"* ]]
then
    echo "ABORT: gunicorn.sh failure"
    exit 1
fi

nginx_script=" 
upstream app_server {
  server unix:/opt/proc/$subdirapp_name-gunicorn.sock fail_timeout=0;
}

server {

  listen 80;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  location / {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host \$server_name;
    proxy_redirect off;
    proxy_pass http://app_server;
    break;
  }

  location /media {
    alias /opt/media;
  }

  location /static {
    alias /opt/static;
  }
}
"
echo "replacing $nginx_conf_file"
echo "$nginx_script" > $nginx_conf_file

echo "restarting nginx"
sudo /etc/init.d/nginx restart

echo "you're welcome"