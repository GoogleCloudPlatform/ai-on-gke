package historydb

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

// JobStatus represents the status of a job
type JobStatus string

const (
	// JobStatusPending indicates the job is pending
	JobStatusPending JobStatus = "pending"
	// JobStatusScheduled indicates the job has been scheduled
	JobStatusScheduled JobStatus = "scheduled"
	// JobStatusUnschedulable indicates the job is unschedulable
	JobStatusUnschedulable JobStatus = "unschedulable"
)

// JobStatusRecord represents a record in the replicated_job_status table
type JobStatusRecord struct {
	JobUID     string
	Index      int
	JobName    string
	JobSetName string
	NodePool   string
	Status     JobStatus
}

type PostgresDB struct {
	db *sql.DB
}

var _ DBInterface = &PostgresDB{}

// NewDB creates a new database connection
func NewDB(host, port, user, password, dbname string) (*PostgresDB, error) {
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("error opening database: %w", err)
	}

	// Test the connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("error connecting to the database: %w", err)
	}

	return &PostgresDB{db: db}, nil
}

// Close closes the database connection
func (d *PostgresDB) Close() error {
	return d.db.Close()
}

// GetLastJobStatus retrieves the most recent status record for a given job_uid
func (d *PostgresDB) GetLastJobStatus(jobUID string) (*JobStatusRecord, error) {
	query := `
		SELECT job_uid, index, job_name, jobset_name, node_pool, status
		FROM replicated_job_status
		WHERE job_uid = $1
		ORDER BY index DESC
		LIMIT 1
	`

	var record JobStatusRecord
	err := d.db.QueryRow(query, jobUID).Scan(
		&record.JobUID,
		&record.Index,
		&record.JobName,
		&record.JobSetName,
		&record.NodePool,
		&record.Status,
	)

	if err == sql.ErrNoRows {
		return nil, nil // No records found
	}
	if err != nil {
		return nil, fmt.Errorf("error getting last job status: %w", err)
	}

	return &record, nil
}

// SaveJobStatus saves a job status record if the status has changed
func (d *PostgresDB) SaveJobStatus(record *JobStatusRecord) error {
	// First, check if we have a previous record for this job
	lastRecord, err := d.GetLastJobStatus(record.JobUID)
	if err != nil {
		return err
	}

	// If we have a previous record and the status hasn't changed, do nothing
	if lastRecord != nil && lastRecord.Status == record.Status {
		return nil // Status hasn't changed, no need to create a new record
	}

	// If we have a previous record, increment the index
	// Otherwise, start with index 0
	if lastRecord != nil {
		record.Index = lastRecord.Index + 1
	} else {
		record.Index = 0
	}

	// Insert the new record
	query := `
		INSERT INTO replicated_job_status (job_uid, index, job_name, jobset_name, node_pool, status)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err = d.db.Exec(
		query,
		record.JobUID,
		record.Index,
		record.JobName,
		record.JobSetName,
		record.NodePool,
		record.Status,
	)

	if err != nil {
		return fmt.Errorf("error saving job status: %w", err)
	}

	return nil
}

// DB returns the underlying sql.DB connection
func (d *PostgresDB) DB() *sql.DB {
	return d.db
}
