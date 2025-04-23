package historydb

type DBInterface interface {
	GetLastJobStatus(jobUID string) (*JobStatusRecord, error)
	SaveJobStatus(record *JobStatusRecord) error
}
