#!/bin/bash
set -e

yum update -y
yum install -y nginx
cat > /usr/share/nginx/html/index.html <<'EOF'
<html>
  <head><title>3-Tier App</title></head>
  <body>
    <h1>Hello from the app tier</h1>
  </body>
</html>
EOF
systemctl enable nginx
systemctl start nginx