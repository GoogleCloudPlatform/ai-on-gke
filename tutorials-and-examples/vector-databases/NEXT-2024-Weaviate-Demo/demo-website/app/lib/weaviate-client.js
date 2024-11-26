
import weaviate from 'weaviate-ts-client';

const client = weaviate.client({
    scheme: "http",
    host: `${process.env.WEAVIATE_SERVER}`,
    //@ts-ignore
    apiKey: new weaviate.ApiKey(process.env.WEAVIATE_API_KEY), // Replace w/ your Weaviate instance API key
  });

  export default client