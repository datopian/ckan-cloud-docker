# Notes about Airflow on nginx

About the `location /airflow/` at nginx conf file.  
If the proxy_pass statement has no variables in it, then it will use the "gethostbyaddr" system call during start-up or reload and will cache that value permanently.  
if there are any variables, such as using either of the following: 
```
set $originaddr http://origin.example.com;
proxy_pass $originaddr;
```

or even

```
proxy_pass http://origin.example.com$request_uri;
```

Then nginx will use a built-in resolver, and the "resolver" directive must be present.  
When using nginx in a docker-compose service declaration, the services, unless specified will all reside on the same network, and each container will have access to a docker created dns server whose location is always at the ip 127.0.0.11
        