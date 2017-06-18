# mezzanine-docker
* mezzanine app on docker
* composed by mezzanine, mariadb & nginx
## Requirements
* docker & docker compose
* git

## Installation
### Run the Containers ###
1. Clone the project into a local directory
   * `git clone https://github.com/duck105/mezzanine-docker.git`

2. Go into your project directory
   * `cd mezzanine-docker`

3. Run Docker Compose 
   * `docker-compose up` 
   
4. If there's any error code about `Can't connect to MySQL server on 'db' ` <br>
Just stop the process and run `docker-compose up`  again
### Install the Database ###
1. Identify your container
   * `sudo docker ps`

2. Run bash interactively in the web_container
   * `$> sudo docker exec -it CONTAINER_NAME /bin/bash`

3. Create the database
   * `CONTAINER_NAME$> python manage.py createdb`

4. Exit the container
   * `CONTAINER_NAME$> exit`
