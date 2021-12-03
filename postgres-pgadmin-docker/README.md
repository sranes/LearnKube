# Setting up Postgres and pgadmin in two containers

When postgres is running in a container and you need to conect to it from pgadmin or from your application, you would need to know the IP address of the container.

In order to know the IP address, you need to inspect the docker container
The command for the same wouldl be

`docker inspect <container_name>`

Look for the IPAddress in the configuration and use that IP to connect.