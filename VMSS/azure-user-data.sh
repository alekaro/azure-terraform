#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2

TOKEN=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

curl "https://${storage_account_name}.blob.core.windows.net/${storage_container_name}/index.html" -H "x-ms-version: 2017-11-09" -H "Authorization: Bearer $${TOKEN}" > /var/www/html/index.html
