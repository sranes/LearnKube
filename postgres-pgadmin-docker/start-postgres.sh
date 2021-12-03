docker run -d \
    -p 5432:5432 \
    --name dev-postgres \
    -e POSTGRES_DB=keycloak \
    -e POSTGRES_USER=postgres_user \
    -e POSTGRES_PASSWORD=SomeStrongPassword \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v $(pwd)/pgdata:/var/lib/postgresql/data \
    postgres
