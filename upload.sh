 #!/usr/bin/env bash

# the key file (/C/Users/adamk/.ssh/ak_rsa) looks something like:
#
# -----BEGIN RSA PRIVATE KEY-----
# A bunch of base64-looking stuff
# -----END RSA PRIVATE KEY-----
 
 rsync -avz -e "ssh -i /C/Users/adamk/.ssh/ak_rsa" public/* root@adamkewley.com:/var/www/opensimcreator