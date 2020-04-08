**under construction**

# docking-server
Basic server for autodock vina jobs

## install

    apt install postgresql postgresql-contrib
    # generate some random password
    openssl rand -base64 20 | sed 's/[=+\/]//g'
    
    su postgres
    psql
    ALTER USER postgres WITH PASSWORD 'pass';
    CTRL-D # exit from psql
    CTRL-D # exit from su
    cp config/config.sample.json config/config.json
    
    nano config/config.json
    
    # replace <PUT HERE> with generated password and save
    
    # install nvm + node 12 + iced-coffee-script
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    # relogin or source ~/.bashrc
    nvm i 12
    
    # if already installed
    nvm use 12
    npm i -g iced-coffee-script
    
    
    # clone install deps 
    git clone https://github.com/public-docking/docking-server
    cd docking-server
    npm ci
    
    # you can check that all is ok
    ./test_start.coffee
    # fill receptor folder
    # fill ligand folder
    # restart server
    ./test_start.coffee
