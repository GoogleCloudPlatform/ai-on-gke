# Steps to convert the code from Notebook to run with Ray on GKE

1. Decorate the function which needs to be run as remote function in Ray workers

   ```
   import ray
   @ray.remote(num_cpus=1)
   ```

1. Create the run time environment with the libraries needed by remote function

   ```
   runtime_env = {"pip": ["google-cloud-storage==2.16.0", "spacy==3.7.4", "jsonpickle==3.0.3"]}
   ```

1. Initialize the Ray with the Ray cluster created & pass the runtime environment along

   ```
   ray.init("ray://"+RAY_CLUSTER_HOST, runtime_env=runtime_env)``
   ```

1. Get remote object using ray.get() method

   ```
   results = ray.get([get_clean_df.remote(res[i]) for i in range(len(res))])
   ```

1. After completing the execution, shutdown Ray clusters
   ```
   ray.shutdown()
   ```
