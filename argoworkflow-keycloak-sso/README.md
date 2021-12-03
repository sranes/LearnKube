# Setting up Argo Workflow Server with KeyCloak SSO and RBAC

Prerequisites:
1. You already have a KeyCloak server running with  self-signed certificate
2. You have a [argo server](https://argoproj.github.io/argo-workflows/quick-start/) running.

## Step 1: Mount the KeyCloak SSL certificate in the POD with Kubernetes Secret

Assuming you have a self-signed certificate that you used for setting up the KeyCloak server, now we need to get the base64 value of the certificate file.

Note: Follow the KeyCloak setup to understand how to generate the certificate

Execute the following command in a terminal

`base64 tls.crt`

The command above shall output the base64 encoded string of the certificate file.

Now create a secret file using the above output

ca-keycloak-sec.yaml
```yaml
apiVersion: v1
data:
  ca.crt: |
    this-line-to-be-updated-with-actual-output-of-base64-command
kind: Secret
metadata:
  name: ca-keycloak
  namespace: argo
type: Opaque
```

**Apply the certificate to the cluster**

`kubectl apply -f ca-keycloak-sec.yaml -n argo`


## Step 2: Setup KeyCloak
**Create the client**
1. Create a new realm called “argo” (you can name it anything you like)
1. Create a client called “argo” (again you can name it anything you like)
1. Set the “Client Protocol” to “opened-connect”
1. Set the “Access Type” to “confidential”
1. Set the “Root URL” to the base URL of Argo application (eg. https://localhost:2746)
1. Set the “Valid Redirect URIs” to “https://localhost:2746/oauth2/callback” (adjust as per the argo application URL)
1. Set the “Base URL” to “/workflows”
1. Set the “Admin URL” and “Web Origins” to same as “Root URL”

After saving the details, you should see a new tab appear called “Credentials”
Navigate to the Credentials tab and take note of the generated “Secret”


**Define the Client Scope**
1. Navigate to “Client Scopes” in left navigation
1. Create a new “Client Scope” called “groups” and select the Protocol as “opened-connect”
1. Save the client scope, and now navigate to the Mappers tab
1. Create a new mapper
1. Set the name as “groups”
1. Select the “Mapper Type” as “Group Membership”
1. Select the “Token Claim Name” as “groups”

**Define the Groups**
1. Navigate to the Groups tab under Manage section (left navigation)
1. Create a new group called as “argo” (you can name it anything). We are later going to use this name in the ServiceAccount definition
1. You can create more groups if you like, one group should match to one ServiceAccount

**Create the Users**
1. Create a user
1. Assign the user to the “argo” group
1. Set the credentials for the user (switch off the temporary flag while setting the credentials, so that user does not have to reset the password)

## Step 3:  Create the kubernetes secrets for KayCloak client and client-secret

`kubectl create secret -n argo generic client-id-secret --from-literal=client-id-key=argo`

Note: Assuming argo is the name of the client defined in KayCloak (within the realm) and client-id-key is the key specified in the ConfigMap under SSO for clientId

`kubectl create secret -n argo generic client-secret-secret --from-literal=client-secret-key=client-secret-goes-here`

Note: client-secret-key is the key specified in the ConfigMap under SSO for clientSecret
Client secret should match the generated client secret in KyCloak for the client.
Look under the Credentials tab (it is generated when access type is set to confidential for a client)

## Step 4: Update the configmap to include SSO configuration details

argo-cm.yaml
```yaml
apiVersion: v1
data:
  sso: |
    issuer: https://keycloak.192.168.1.123.nip.io/auth/realms/argo
    sessionExpiry: 24h
    clientId:
      name: client-id-secret
      key: client-id-key
    clientSecret:
      name: client-secret-secret
      key: client-secret-key
    redirectUrl: https://localhost:2746/oauth2/callback
    scopes:
     - groups
     - email
     - profile
     - openid
    rbac:
      enabled: true
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
```

Apply the change to cluster

`kubectl apply -f argo-cm.yaml -n argo`

## Step 5: Update the deployment to mount certificate and set the auth-mode to SSO and mount the certificate

argo-server-dm.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argo-server
spec:
  selector:
    matchLabels:
      app: argo-server
  template:
    metadata:
      labels:
        app: argo-server
    spec:
      containers:
      - args:
        - server
        - --namespaced
        - --auth-mode
        - sso
        image: quay.io/argoproj/argocli:latest
        name: argo-server
        ports:
        - containerPort: 2746
          name: web
        readinessProbe:
          httpGet:
            path: /
            port: 2746
            scheme: HTTPS
          initialDelaySeconds: 10
          periodSeconds: 20
        securityContext:
          capabilities:
            drop:
            - ALL
        volumeMounts:
          - mountPath: /tmp
            name: tmp
          - name: ca-pemstore
            mountPath: /etc/ssl/certs/ca.crt
            subPath: ca.crt
            readOnly: false
      nodeSelector:
        kubernetes.io/os: linux
      securityContext:
        runAsNonRoot: true
      serviceAccountName: argo-server
      volumes:
        - emptyDir: {}
          name: tmp
        - name: ca-pemstore
          secret:
            secretName: ca-keycloak

```

Apply the change to cluster

`kubectl apply -f argo-server-dm.yaml -n argo`

## Step 6: Update the ServiceAccount configuration to map the user group defined in KeyCloak

argo-sa.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo
  annotations:
    # The rule is an expression used to determine if this service account
    # should be used.
    # * `groups` - an array of the OIDC groups
    # * `iss` - the issuer ("argo-server")
    # * `sub` - the subject (typically the username)
    # Must evaluate to a boolean.
    # If you want an account to be the default to use, this rule can be "true".
    # Details of the expression language are available in
    # https://github.com/antonmedv/expr/blob/master/docs/Language-Definition.md.
    workflows.argoproj.io/rbac-rule: "'argo' in groups"
    # The precedence is used to determine which service account to use whe
    # Precedence is an integer. It may be negative. If omitted, it defaults to "0".
    # Numerically higher values have higher precedence (not lower, which maybe
    # counter-intuitive to you).
    # If two rules match and have the same precedence, then which one used will
    # be arbitrary.
    workflows.argoproj.io/rbac-rule-precedence: "1"
```


Apply the change to cluster

`kubectl apply -f argo-sa.yaml -n argo`


argo-server-sa.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-server
  annotations:
    # The rule is an expression used to determine if this service account
    # should be used.
    # * `groups` - an array of the OIDC groups
    # * `iss` - the issuer ("argo-server")
    # * `sub` - the subject (typically the username)
    # Must evaluate to a boolean.
    # If you want an account to be the default to use, this rule can be "true".
    # Details of the expression language are available in
    # https://github.com/antonmedv/expr/blob/master/docs/Language-Definition.md.
    workflows.argoproj.io/rbac-rule: "'admin' in groups"
    # The precedence is used to determine which service account to use whe
    # Precedence is an integer. It may be negative. If omitted, it defaults to "0".
    # Numerically higher values have higher precedence (not lower, which maybe
    # counter-intuitive to you).
    # If two rules match and have the same precedence, then which one used will
    # be arbitrary.
    workflows.argoproj.io/rbac-rule-precedence: "2"
```

Apply the change to cluster

`kubectl apply -f argo-server-sa.yaml -n argo`

Note: You can set the rule precedence to decide which service account to be used when user belong to multiple groups.
In the above case, if a user belongs to both argo and argo-server group, then the user shall be assigned argo-server ServiceAccount as it has higher precedence.

Now you should be able to login to Argo Server using keycloak user credentials.

Reference
1. https://faun.pub/mount-ssl-certificates-in-kubernetes-pod-with-secret-8aca220896e6
2. https://argoproj.github.io/argo-workflows/argo-server-sso/