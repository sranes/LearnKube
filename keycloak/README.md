# Setup KeyCloak in a docker container using self signed certificate
---

## Prerequisites
1. Install [mkcert](https://github.com/FiloSottile/mkcert)
   - mkcert allows you to generate Self Signed  SSL certificates for local testing of applications
   - You can use home-brew to install mkcert

```
brew install mkcert
brew install nss
mkcert -install
```

1. Install [Docker](https://www.docker.com/products/docker-desktop)

## Certificate Creation
- Check the IP address of your system. Assuming the IP address is 192.168.1.123, we are going to create a certificate for URL keycloak.192.168.1.123.nip.io (Note: adjust the IP as per your own IP)
- Navigate to a folder of your choice (say keycloak) and issue following command to generate the self signed certificate
  
`mkcert  keycloak.192.168.1.123.nip.io`

- The above command shall generate two files  keycloak.192.168.1.123.nip.io-key.pem and keycloak.192.168.1.123.nip.io.pem
- Rename the files to tls.key and tls.crt respectively


## Running KeyCloak using Docker
- From the keycloak folder run the following command
  
`docker run -d --rm --name keycloak -p 443:8443 -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=admin -v $(pwd):/etc/x509/https jboss/keycloak`

- You can access the application at https://keycloak.192.168.1.123.nip.io
- KeyCloak server is now ready for integration with other applications
