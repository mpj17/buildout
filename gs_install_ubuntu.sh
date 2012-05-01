#!/bin/bash

. read_ini.sh
read_ini config.cfg config --prefix CFG

echo "Installing dependencies"
echo
sudo apt-get install -y python python-virtualenv python-dev build-essential postgresql libpq-dev libxslt1-dev libxml2-dev python-libxslt1 swaks

echo
echo "Testing mail setup..."
echo
for tmail in ${CFG__config__admin_email} ${CFG__config__user_email}
do
    if [ "${CFG__config__smtp_user}" != "" ]; then
        swaks -S -s ${CFG__config__smtp_host} -p ${CFG__config__smtp_port} --from ${CFG__config__support_email} --to ${tmail} --auth-user ${CFG__config__smtp_user}  --auth-pass ${CFG__config__smtp_pass}
    else
        swaks -S -s ${CFG__config__smtp_host} -p ${CFG__config__smtp_port} --from ${CFG__config__support_email} --to ${tmail}
    fi

    if [ $? -eq 0 ]; then
        echo "Mail setup works. Expect an email at ${tmail}"
        echo "from ${CFG__config__support_email}."
        echo
    else
        echo
        echo "There was a problem with the mail configuration. This "
        echo "must be fixed before proceeding with the installation."
        exit
    fi
done

# initialise PostgreSQL database
echo "Setting up the databases"
sudo su -l -c"createuser -D -S -R -l ${CFG__config__pgsql_user}" postgres
sudo su -l -c"createuser -D -S -R -l ${CFG__config__relstorage_user}" postgres

sudo su -l -c"createdb -Ttemplate0 -O ${CFG__config__pgsql_user} -EUTF-8 ${CFG__config__pgsql_dbname}" postgres
sudo su -l -c"createdb -Ttemplate0 -O ${CFG__config__relstorage_user} -EUTF-8 ${CFG__config__relstorage_dbname}" postgres

sudo su -l -c"echo \"alter user ${CFG__config__pgsql_user} with encrypted password '${CFG__config__pgsql_password}';\" | psql" postgres
sudo su -l -c"echo \"alter user ${CFG__config__relstorage_user} with encrypted password '${CFG__config__relstorage_password}';\" | psql" postgres

sudo su -l -c"echo \"grant all privileges on database ${CFG__config__pgsql_dbname} to ${CFG__config__pgsql_user};\" | psql" postgres
sudo su -l -c"echo \"grant all privileges on database ${CFG__config__relstorage_dbname} to ${CFG__config__relstorage_user};\" | psql" postgres

# This is not the work of angels, but...
echo "${CFG__config__pgsql_host}:${CFG__config__pgsql_port}:${CFG__config__pgsql_dbname}:${CFG__config__pgsql_user}:${CFG__config__pgsql_password}" > pgpass-tmp
chmod 600 pgpass-tmp
export PGPASSFILE=pgpass-tmp
# It works.
createlang -U${CFG__config__pgsql_user} -h${CFG__config__pgsql_host} -p${CFG__config__pgsql_port} plpgsql ${CFG__config__pgsql_dbname}
echo
echo "Databases created"
echo

echo "Setting up Python"
echo
# Create the Python environment
virtualenv --no-site-packages . 
. ./bin/activate
# Fetch the system that builds GroupServer
pip install zc.buildout==1.5.2
echo
echo "Python setup complete."

echo
echo "Installing GroupServer"
echo
buildout -vN
# Buildout has its own "completed" message.

rm pgpass-tmp
