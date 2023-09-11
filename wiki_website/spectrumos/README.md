# Helgen Technologies [Website](https://helgen.tech)

## Develop

Clone this repo:

```bash
git clone git@github.com:Helgen-Tech/Website.git
```

Go into the Website folder and run:

```bash
cd Website
hugo -D server --disableFastRender
```

Now you can check on your browser on **localhost:1313** to view current changes.

## Deploy

## Testing Site

To deploy the changes to production:

 - You can use **rsync** to upload the files:

 ```bash
rsync -rtvzP  ~/Helgen/Website/public/  -e 'ssh -oHostKeyAlgorithms=+ssh-dss' gibranlp.dev:~/helgen.gibranlp.dev/
```


### Production

To deploy the changes to production:

 - You can use **rsync** to upload the files:

 ```bash
 rsync -rtvzP ~/Helgen/Website/public/ -e 'ssh -oHostKeyAlgorithms=+ssh-dss' helgen50@192.254.189.34:~/public_html/
 ```



