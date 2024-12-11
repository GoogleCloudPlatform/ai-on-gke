apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: ${backend_namespace}
data:
  MYSQL_FILES_BUCKET: ${mysql_files_bucket}
  SQL_NAMESPACE: ${sql_namespace}
  DATABASE_NAME: ${database_name}
  GOOGLE_CLIENT_ID: ${google_client_id}
  PROJECT_ID: ${project_id}
  LOCATION: ${location}
   
