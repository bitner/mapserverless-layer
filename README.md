# MapServerless AWS Lambda Layer

MapServerless is a perhaps useless, perhaps awesome way to run Mapserver in AWS Lambda. An example of how to deploy this layer can be found at [https://github.com/bitner/mapserverless].

This build is based on [https://github.com/developmentseed/geolambda]

Pull requests always welcome!


### Create a new version

Use the Dockerfile here as a template for your own version of MapServerless. Simply edit it to remove or add additional libraries.

To create a new version of MapServerless follow these steps. 


1. Build the Docker

```
$ docker build -t mapserverless .
```

2. Create deployment package using the built-in [packaging script](bin/package.sh)

```
$ docker run --rm -v $PWD:/home/mapserverless \
	-it mapsesrverless package.sh
```

This will create a lambda/ directory containing the native libraries and related files, along with a `lambda-deploy.zip` file that can be deployed as a Lambda layer.

3. Push as Lambda layer (if layer already exists a new version will be created)

```
$ aws lambda publish-layer-version \
	--layer-name mapserverless \
	--license-info "MIT" \
	--description "MapServer AWS Lambda" \
	--zip-file fileb://lambda-deploy.zip
```

4. Make layer public (needs to be done each time a new version is published)

```
$ aws lambda add-layer-version-permission --layer-name mapserverless \
	--statement-id public --version-number 1 --principal '*' \
	--action lambda:GetLayerVersion
```
