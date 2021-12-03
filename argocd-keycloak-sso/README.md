
# Setting up Argo CD with KeyCloak SSO RBAC

As part of this exercise, we are going to run KeyCloak in a docker container and Argo CD in a Kubernetes cluster (using Minikube), and then we are going to use Argo CD declarative configuration to configure SSO with KeyCloak

## Prerequisites :
1. You have a keycloak installation up and running. (You can refer to the keycloak folder for details)
2. [Docker](https://www.docker.com/products/docker-desktop) installed
3. [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed
4. [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

## Running [Argo CD](https://argo-cd.readthedocs.io/en/stable/getting_started/) on Minikube cluster 
1. Start minikube by running the command

    `minikube start`
2. Once Minikube is running, you can proceed to install Argo CD
```
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Now you should be able to access Argo CD using https://localhost:8080


## Configure [KeyCloak](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/)
**Configure Client**
1. Login to KeyCloak 
1. Create a new realm called 'argocd' 
1. Following steps to be performed under realm argocd 
1. Create a new client named ‘argocd'
    1. Set the Access Type as “Confidential”
    1. Set the Root URL as the base Argo CD URL “https://localhost:8080”
    1. Set the Valid Redirect URIs as “*”
    1. Set the Base URL as “/applications”
    1. Set the Admin URL as “https://localhost:8080”
    1. Set the Web Origins as “https://localhost:8080”
    1. Save
1. Navigate to the “Credentials” tab and copy the secret. Keep it handy as we need it later

**Configure the Groups Claim**
1. Create a new Client Scope called 'groups'
   1. Make sure 'Protocol' is set to 'openid-connect'
2. Navigate to Mapper after creating the Client Scope
3. Create a new mapper with
   1. Name as 'groups'
   2. Member Type as 'Group Membership'
   3. Token Claim Name as 'groups'
4. Navigate to the 'Client Scopes' for the 'argocd' client
   1. In the 'Default Client Scopes' Add 'groups' and click on 'Add Selected'

**Configure Groups**
1. Create a new group called "ArgoCDAdmins"

**Configure User**
1. Create a new user called test
2. Assign the user to "ArgoCDAdmins" group
3. Set the credentials

## Configure Argo CD OIDC
**Encode the Client Secret**

Use the echo command to encrypt the client secret (Copied from the Credentials tab) into base64 format

`echo -n 'client-secret-from-credentials' | base64` 

The command above should generate the base64 encoded string for the client secret. Now we will create the kubernetes secret for argo cd

argocd-sec.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
data:
  oidc.keycloak.clientSecret: GENERATED-BASE64-CLIENT-SECRET-GOES-HERE
```

Now apply the secret to the cluster using following command

`kubectl apply -f argocd-sec.yaml -n argocd`

**Update the Argo CD ConfigMap**

argocd-cm.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  url: https://localhost:8080/
  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.192.168.1.123.nip.io/auth/realms/argocd
    clientID: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
```
AApply the changes to kubernetes

`kubectl apply -f argocd-cm.yaml -n argocd`

**Configure the RBAC Policy**

argocd-rbac-cm.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
data:
  policy.csv: |
    g, ArgoCDAdmins, role:admin
    g, ArgoCDUsers, role:readonly
```

Apply the changes to kubernetes

`kubectl apply -f argocd-rbac-cm.yaml -n argocd`

Now you should be able to login to Argo CD using the credentials defined in KeyCloak.



