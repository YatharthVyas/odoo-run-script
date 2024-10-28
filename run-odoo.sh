#! /bin/bash

# ==============================================================================
# ================================ Docker Setup ================================
# ==============================================================================
if ! [ -x "$(command -v docker)" ]; then
    if ! [ -x "$(command -v curl)" ]; then
        echo 'Installing curl (a dependency for docker)'
        sudo apt-get update
        sudo apt-get install curl
    fi
    echo 'Installing docker'
    curl -fsSL https://get.docker.com/ | sh
    read -p "Do you want to run docker as a non-root user? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]];
    then
        sudo usermod -aG docker $USER
    else
        read -p "Enter your docker username: " username
        sudo usermod -aG docker $username
    fi
    sudo service docker restart
    if ! [ -x "$(command -v docker)" ]; then
        echo 'Docker installation failed. Please try again.'
        exit 1
    fi
else
    echo -n 'Using '
    docker --version
fi


# ==============================================================================
# ============================== Odoo Installation =============================
# ==============================================================================
if [ -z "$(docker images -q myimage:mytag 2> /dev/null)" ]; then
  docker pull odoo
fi

read -p "Do you want to run the enterprise source code? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]];
then
    enterprise_fetched = false
    while [ $enterprise_fetched = false ]; do
        read -p "Please enter your Odoo Enterprise Username: " username
        if [ -d "enterprise" ]; then
            echo "Using Existing Odoo Enterprise Source Code"
            cd enterprise
            git pull 'https://' + $username + '@github.com/odoo/enterprise.git'
        else
            echo "Fetching Odoo Enterprise Source Code"
            git clone 'https://' + $username + '@github.com/odoo/enterprise.git'
        fi

        # Check the exit status to know if previous command was successful
        if [ $? -eq 0 ]; then
            enterprise_fetched = true
        else
            echo "Invalid Username. Please try again."
        fi
    done
fi

# check if the postgres image is already pulled
if [ -z "$(docker images -q postgres:15 2> /dev/null)" ]; then
  docker pull postgres:15
fi

# check if the postgres container is already running
if [ -z "$(docker ps -q -f name=db)" ]; then
  docker run -d -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres --name db postgres:15
fi

# check if the odoo container is already running
if [ -z "$(docker ps -q -f name=odoo)" ]; then
    docker stop odoo
    docker rm odoo
fi
docker run -p 8069:8069 --name odoo --link db:db -t odoo
