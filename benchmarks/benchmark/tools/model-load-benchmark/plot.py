import matplotlib.pyplot as plt
import yaml
import glob
import os
import re

def load_yaml_files(directory="results"):
    """Loads all YAML files in the given directory."""
    results = []
    for filepath in glob.glob(os.path.join(directory, 'case_*.yaml')):
        with open(filepath, 'r') as f:
            try:
                data = yaml.safe_load(f)
                # Extract case number from filename using regex
                match = re.search(r"case_(\d+)\.yaml", filepath)
                if match:
                    data['case_no'] = int(match.group(1))
                results.append(data)
            except yaml.YAMLError as e:
                print(f"Error parsing YAML file {filepath}: {e}")
    return results

def extract_data(results):
    """Extracts relevant data for plotting."""
    data = {
        'cpu_request': [],
        'memory_request': [],
        'ephemeral_storage_request': [],
        'parallel_downloads_per_file': [],
        'max_parallel_downloads': [],
        'download_chunk_size_mb': [],
        'elapsed_time': [],
        'case_no': []  # Add case_no to the data dictionary
    }
    for result in results:
        data['cpu_request'].append(result['config']['sideCarResources']['cpu-request']['base'])
        data['memory_request'].append(result['config']['sideCarResources']['memory-request']['base'])
        data['ephemeral_storage_request'].append(result['config']['sideCarResources']['ephemeral-storage-request']['base'])
        data['parallel_downloads_per_file'].append(result['config']['volumeAttributes']['mountOptions']['file-cache']['parallel-downloads-per-file']['base'])
        data['max_parallel_downloads'].append(result['config']['volumeAttributes']['mountOptions']['file-cache']['max-parallel-downloads']['base'])
        data['download_chunk_size_mb'].append(result['config']['volumeAttributes']['mountOptions']['file-cache']['download-chunk-size-mb']['base'])
        minutes, seconds = map(float, result['elapsedTime'][:-1].split('m'))
        data['elapsed_time'].append(minutes * 60 + seconds)
        data['case_no'].append(result['case_no'])  # Add case_no to the list
    return data

def create_scatter_plots(data, directory="results"):
    """Creates scatter plots for each property and saves them to files."""

    properties = [
        'cpu_request', 'memory_request', 'ephemeral_storage_request',
        'parallel_downloads_per_file', 'max_parallel_downloads', 'download_chunk_size_mb'
    ]
    for prop in properties:
        plt.figure()
        plt.scatter(data[prop], data['elapsed_time'])
        plt.xlabel(prop)
        plt.ylabel('Elapsed Time (seconds)')
        plt.title(f'Elapsed Time vs. {prop}')

        # Label the points with case numbers
        for i, txt in enumerate(data['case_no']):
            plt.annotate(txt, (data[prop][i], data['elapsed_time'][i]))

        filepath = os.path.join(directory, f'elapsed_time_vs_{prop}.png')
        plt.savefig(filepath)  

if __name__ == '__main__':
    results_dir = 'results'
    results = load_yaml_files(results_dir)
    data = extract_data(results)
    create_scatter_plots(data, results_dir)