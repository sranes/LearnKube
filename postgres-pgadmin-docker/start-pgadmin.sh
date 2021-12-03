docker run -p 8090:80 \
    -e 'PGADMIN_DEFAULT_EMAIL=user@gmail.com' \
    -e 'PGADMIN_DEFAULT_PASSWORD=SomeStrongPassword' \
    -d dpage/pgadmin4