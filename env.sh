#!/bin/sh
cat << EOF > config/application.yml
HOMEPAGE: ${HOMEPAGE}
'Cenit::Admin:default_uri': ${ADMIN_UI}
EOF
