This directory contains the configuration for running performance profiling across various model, model server, accelerator, and request rate combinations. The configuration file outlines the specific constraints and setups for benchmarking the performance of different models under various conditions. Below is an explanation of each field:

 - models: Which models will be benchmarked?
 - accelerators: Which accelerators will be used for benchmarking?
 - request_rates: For each model, model server, and accelerator combination, which request rates do we want to benchmark?
 - model_servers: Enumerates the model servers to be benchmarked, along with their specific configurations:
   - models: Indicates which models each server is capable of running, returns all accelerators that contain one or more of these strings.
   - accelerators: Which accelerators does this model server support, returns all accelerators that contains one or more of these strings.