apiVersion: batch/v1
kind: Job
metadata:
  name: dlio-job
  namespace: ${namespace}
spec:
  backoffLimit: ${job_backoffLimit}
  completions: ${job_completions}
  parallelism: ${job_parallelism}
  template:
    metadata:
      labels:
        app: dlio-job
      annotations:
        gke-gcsfuse/volumes: ${gcs_fuse_csi_driver_enabled}
        gke-gcsfuse/cpu-limit: ${gcs_fuse_sidecar_cpu_limit}
        gke-gcsfuse/memory-limit: ${gcs_fuse_sidecar_memory_limit}
        gke-gcsfuse/ephemeral-storage-limit: ${gcs_fuse_sidecar_ephemeral_storage_limit}
        gke-parallelstore/volumes: ${pscsi_driver_enabled}
        gke-parallelstore/cpu-limit: ${pscsi_sidecar_cpu_limit}
        gke-parallelstore/memory-limit: ${pscsi_sidecar_memory_limit}
    spec:
      containers:
      - name: dlio
        image: <change-me>
        resources:
          limits:
            cpu: ${dlio_container_cpu_limit}
            memory: ${dlio_container_memory_limit}
            ephemeral-storage: ${dlio_container_ephemeral_storage}
        command:
          - "/bin/bash"
          - "-c"
          - echo "freeing cache on node";
            apt-get install procps;
            free && sync && echo 3 > sudo /proc/sys/vm/drop_caches && free;
            echo "cd'ing to benchmark folder";
            cd /workspace/dlio/src;
            if [[ "${dlio_generate_data}" == "True" ]];then
              echo 'generating data';
              mpirun -np ${dlio_number_of_processors} python dlio_benchmark.py workload=${dlio_model} ++workload.workflow.generate_data=True ++workload.workflow.train=False  ++workload.dataset.data_folder=${dlio_data_mount_path}  ++workload.dataset.num_files_train=${dlio_number_of_files} ++workload.dataset.record_length=${dlio_record_length} ++workload.dataset.record_length_stdev=${dlio_record_length_stdev} ++workload.dataset.record_length_resize=${dlio_record_length_resize};
              echo 'done';
            else
              echo 'running benchmark';
              mpirun -np ${dlio_number_of_processors} python dlio_benchmark.py workload=${dlio_model} ++workload.workflow.profiling=True ++workload.profiling.profiler=${dlio_profiler} ++workload.profiling.iostat_devices=${dlio_iostat_devices} ++workload.dataset.data_folder=${dlio_data_mount_path} ++workload.dataset.num_files_train=${dlio_number_of_files} ++workload.dataset.record_length=${dlio_record_length} ++workload.reader.batch_size=${dlio_batch_size} ++workload.reader.read_threads=${dlio_read_threads} ++workload.train.epochs=${dlio_train_epochs};
              echo 'finding and unifying log folder';
              shopt -s dotglob;
              mkdir -p $OUTPUT_FOLDER;
              scp -r hydra_log/unet3d/*/* $OUTPUT_FOLDER;
              echo 'processing logs';
              python dlio_postprocessor.py --output-folder $OUTPUT_FOLDER;
              rm $OUTPUT_FOLDER/\.*\.pfw;
              echo 'copying results';
              mkdir -p ${dlio_data_mount_path}/${dlio_benchmark_result}/$MY_POD_NAME;
              cp -r $OUTPUT_FOLDER ${dlio_data_mount_path}/${dlio_benchmark_result}/$MY_POD_NAME;
              echo 'done';
            fi
        env:
        - name: OUTPUT_FOLDER
          value: hydra_log/unified_output
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: ml-perf-volume
          mountPath: ${dlio_data_mount_path}
        - name: dshm
          mountPath: /dev/shm
      serviceAccountName: ${service_account}
      volumes:
      - name: ml-perf-volume
        persistentVolumeClaim:
          claimName: ${pvc_name}
      - name: dshm
        emptyDir:
          medium: Memory
      restartPolicy: Never