package integration

import (
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/historydb"
	_ "github.com/lib/pq"
)

// TestDB tests the DB struct and its methods
func TestDB(t *testing.T) {
	// Connect to the database
	db, err := historydb.NewDB("localhost", "5432", "postgres", "pass", "postgres")
	if err != nil {
		t.Fatalf("Failed to connect to database: %v", err)
	}

	// Register cleanup function to close the database connection
	t.Cleanup(func() {
		if err := db.Close(); err != nil {
			t.Errorf("Failed to close database connection: %v", err)
		}
	})

	// Create a unique job UID for this test
	jobUID := "test-job-" + time.Now().Format("20060102150405")

	// Register cleanup function to delete test data
	t.Cleanup(func() {
		cleanupQuery := "DELETE FROM replicated_job_status WHERE job_uid = $1"
		_, err := db.DB().Exec(cleanupQuery, jobUID)
		if err != nil {
			t.Errorf("Failed to clean up test data: %v", err)
		}
	})

	// Test GetLastJobStatus when no records exist
	lastRecord, err := db.GetLastJobStatus(jobUID)
	if err != nil {
		t.Errorf("GetLastJobStatus failed: %v", err)
	}
	if lastRecord != nil {
		t.Errorf("Expected nil for non-existent job, got %+v", lastRecord)
	}

	// Test SaveJobStatus for a new job
	record := historydb.JobStatusRecord{
		JobUID:   jobUID,
		JobName:  "test-job",
		NodePool: "test-pool",
		Status:   historydb.JobStatusPending,
	}

	err = db.SaveJobStatus(&record)
	if err != nil {
		t.Errorf("SaveJobStatus failed: %v", err)
	}

	// Verify the record was saved with index 0
	lastRecord, err = db.GetLastJobStatus(jobUID)
	if err != nil {
		t.Errorf("GetLastJobStatus failed: %v", err)
	}
	if lastRecord == nil {
		t.Fatal("Expected a record, got nil")
	}
	if lastRecord.JobUID != jobUID {
		t.Errorf("Expected JobUID %s, got %s", jobUID, lastRecord.JobUID)
	}
	if lastRecord.Index != 0 {
		t.Errorf("Expected Index 0, got %d", lastRecord.Index)
	}
	if lastRecord.Status != historydb.JobStatusPending {
		t.Errorf("Expected status %s, got %s", historydb.JobStatusPending, lastRecord.Status)
	}

	// Test SaveJobStatus with the same status (should not create a new record)
	err = db.SaveJobStatus(&record)
	if err != nil {
		t.Errorf("SaveJobStatus failed: %v", err)
	}

	// Verify no new record was created
	lastRecord, err = db.GetLastJobStatus(jobUID)
	if err != nil {
		t.Errorf("GetLastJobStatus failed: %v", err)
	}
	if lastRecord == nil {
		t.Fatal("Expected a record, got nil")
	}
	if lastRecord.Index != 0 {
		t.Errorf("Expected Index 0, got %d", lastRecord.Index)
	}
	if lastRecord.Status != historydb.JobStatusPending {
		t.Errorf("Expected status %s, got %s", historydb.JobStatusPending, lastRecord.Status)
	}

	// Test SaveJobStatus with a different status (should create a new record)
	record.Status = historydb.JobStatusScheduled
	err = db.SaveJobStatus(&record)
	if err != nil {
		t.Errorf("SaveJobStatus failed: %v", err)
	}

	// Verify a new record was created
	lastRecord, err = db.GetLastJobStatus(jobUID)
	if err != nil {
		t.Errorf("GetLastJobStatus failed: %v", err)
	}
	if lastRecord == nil {
		t.Fatal("Expected a record, got nil")
	}
	if lastRecord.Index != 1 {
		t.Errorf("Expected Index 1, got %d", lastRecord.Index)
	}
	if lastRecord.Status != historydb.JobStatusScheduled {
		t.Errorf("Expected status %s, got %s", historydb.JobStatusScheduled, lastRecord.Status)
	}

	// Test SaveJobStatus with another different status (should create a new record)
	record.Status = historydb.JobStatusUnschedulable
	err = db.SaveJobStatus(&record)
	if err != nil {
		t.Errorf("SaveJobStatus failed: %v", err)
	}

	// Verify a new record was created
	lastRecord, err = db.GetLastJobStatus(jobUID)
	if err != nil {
		t.Errorf("GetLastJobStatus failed: %v", err)
	}
	if lastRecord == nil {
		t.Fatal("Expected a record, got nil")
	}
	if lastRecord.Index != 2 {
		t.Errorf("Expected Index 2, got %d", lastRecord.Index)
	}
	if lastRecord.Status != historydb.JobStatusUnschedulable {
		t.Errorf("Expected status %s, got %s", historydb.JobStatusUnschedulable, lastRecord.Status)
	}
}
