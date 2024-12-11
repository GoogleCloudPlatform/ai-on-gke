apiVersion: batch/v1
kind: Job
metadata:
  name: mysql-schema-and-data-job
  namespace: ${sql_namespace}
  annotations:
    file-hash: ${files_hash}
spec:
  template:
    spec:
      serviceAccountName: default # Add this line! Replace 'default' if needed
      containers:
      - name: mysql-schema-and-data
        image: google/cloud-sdk:slim  # This image includes gsutil
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Installing MariaDB client (compatible with MySQL)...";
            apt-get update && apt-get install -y mariadb-client;
            
            echo "Downloading SQL and CSV files from GCS...";
            gsutil cp gs://${mysql_files_bucket}/schema-tables.sql /mnt/sql/schema-tables.sql;
            gsutil cp gs://${mysql_files_bucket}/schema-data.sql /mnt/sql/schema-data.sql;
            gsutil cp gs://${mysql_files_bucket}/csv/wordsets.csv /mnt/csv/wordsets.csv;
            gsutil cp gs://${mysql_files_bucket}/csv/words.csv /mnt/csv/words.csv;

            echo "Creating database if not exists...";
            mysql -h mysql -u root -p${db_root_password} -e "CREATE DATABASE IF NOT EXISTS ${db_name}; USE ${db_name};"

            echo "Running table creation script...";
            mysql -h mysql -u root -p${db_root_password} ${db_name} < /mnt/sql/schema-tables.sql;

            echo "Uploading initial data (if necessary)...";
            mysql --local-infile=1 -h mysql -u root -p${db_root_password} ${db_name} < /mnt/sql/schema-data.sql;
        volumeMounts:
        - name: sql-volume
          mountPath: /mnt/sql
        - name: csv-volume
          mountPath: /mnt/csv
      restartPolicy: OnFailure
      volumes:
      - name: sql-volume
        emptyDir: {}  # Temporary storage for SQL file
      - name: csv-volume
        emptyDir: {}  # Temporary storage for CSV files
