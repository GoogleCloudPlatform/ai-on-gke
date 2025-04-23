package main

/*
To run this script with a local PostgreSQL database:

1. First, start the PostgreSQL container:
   ./run-postgres.sh

2. Then run this script with the default parameters (which match the container settings):
   go run controller/hack/run_history_db.go

   Or explicitly specify the parameters:
   go run controller/hack/run_history_db.go --db-host=localhost --db-port=5432 --db-user=postgres --db-pass=pass --db-name=postgres

3. Press Ctrl+C to stop the script when done.
*/

import (
	"flag"
	"log"

	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/historydb"
)

func main() {
	// Define command-line flags
	dbHost := flag.String("db-host", "localhost", "Database host")
	dbPort := flag.String("db-port", "5432", "Database port")
	dbUser := flag.String("db-user", "postgres", "Database user")
	dbPass := flag.String("db-pass", "pass", "Database password")
	dbName := flag.String("db-name", "postgres", "Database name")
	jobUID := flag.String("job-uid", "demo-job", "Job UID")
	jobStatus := flag.String("job-status", "pending", "Job status")
	flag.Parse()

	// Connect to the database
	db, err := historydb.NewDB(*dbHost, *dbPort, *dbUser, *dbPass, *dbName)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	log.Println("Connected to database successfully")

	// Create a job status record

	// First, save a pending status
	record := historydb.JobStatusRecord{
		JobUID:   *jobUID,
		JobName:  "demo-job",
		NodePool: "pool-1",
		Status:   historydb.JobStatus(*jobStatus),
	}

	// Save the record to the database
	err = db.SaveJobStatus(&record)
	if err != nil {
		log.Fatalf("Error saving job status: %v", err)
	}
	log.Printf("Saved initial job status: %s (status: %s)", record.JobUID, record.Status)
}
