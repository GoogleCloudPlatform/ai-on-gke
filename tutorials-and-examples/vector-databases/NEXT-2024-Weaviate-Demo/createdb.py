import weaviate
import weaviate.classes.config as wvcc
from weaviate.classes.config import Property, DataType
import json
import os

# Define Variables
WEAVIATE_SERVER = os.environ.get('WEAVIATE_SERVER')
WEAVIATE_API_KEY = os.environ.get('WEAVIATE_API_KEY')
PROJECT_ID = os.environ.get('PROJECT_ID')
WEAVIATE_GRPC_URL= os.environ.get('WEAVIATE_SERVER_GRPC')
WEAVIATE_HTTP_URL =os.environ.get('WEAVIATE_SERVER')
WEAVIATE_AUTH = os.environ.get('WEAVIATE_API_KEY')

# Connect to the Weaviate Server



client = weaviate.connect_to_custom(
        http_host=WEAVIATE_HTTP_URL,
        http_port="80",
        http_secure=False,
        grpc_host=WEAVIATE_GRPC_URL,
        grpc_port="50051",
        grpc_secure=False,
        auth_credentials=weaviate.auth.AuthApiKey(WEAVIATE_AUTH)
)

# CAUTION: Running this will delete the collection along with the objects
#client.collections.delete_all()


# Define the schema
collection = client.collections.create(
    name="Products",
    vectorizer_config=wvcc.Configure.Vectorizer.text2vec_palm
    (
        project_id=PROJECT_ID,
        api_endpoint="generativelanguage.googleapis.com",
        model_id="embedding-gecko-001"
    ),
    properties=[
            Property(name="product_id", data_type=DataType.TEXT),
            Property(name="title", data_type=DataType.TEXT),
            Property(name="category", data_type=DataType.TEXT),
            Property(name="link", data_type=DataType.TEXT),
            Property(name="description", data_type=DataType.TEXT),
            Property(name="brand", data_type=DataType.TEXT),
            Property(name="generated_description", data_type=DataType.TEXT),
      ]
)


# Import your data into your Weaviate instance:

f = open('first_99_objects.json')
data = json.load(f)

products = client.collections.get("Products")

for item in data:
  upload = products.data.insert(
      properties={
          "product_id": item['product_id'],
          "title": item['title'],
          "category": item['category'],
          "link": item['link'],
          "description": item['description'],
          "brand": item['brand']
      }
  )
  
f.close()
# Count how many objects are in the database

products = client.collections.get("Products")
response = products.aggregate.over_all(total_count=True)

print("Items added to the database: "+str(response.total_count)) 