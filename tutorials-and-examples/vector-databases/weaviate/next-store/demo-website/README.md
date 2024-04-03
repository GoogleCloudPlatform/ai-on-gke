# Demo website for Generative Feedback Loops


Build the IAM account for cloud run

```sh
gcloud iam service-accounts add-iam-policy-binding "SERVICE_ACCOUNT_EMAIL" \
    --member "PRINCIPAL" \
    --role "roles/iam.serviceAccountUser"
```



Build  the container using cloud build

```sh
gcloud builds submit --tag us-central1-docker.pkg.dev/[Project ID]/Repo]/[Name]
```



Submit the container to cloud run



Sample product to upload

```
    {
        "id": "id_22",
        "product_id": "GGCPGAAJ133812",
        "title": "Project Sushi Tshirt",
        "category": "Clothing  accessories Tops  tees Tshirts",
        "link": "https://shop.googlemerchandisestore.com/store/20190522377/assets/items/images/GGCPGXXX1338.jpg",
        "description": "This is a set of two tshirts The first shirt is a heather gray shirt with a black N3Q logo on the chest The second shirt is a heather gray shirt with a black and red sushi graphic on the chest Both shirts are made of 100 cotton and are machine washable",
        "color": "['gray', 'black', 'red']",
        "gender": "unisex",
        "brand": "Google"
    },
```
