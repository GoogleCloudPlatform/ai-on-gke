package historydb

type NoopDB struct{}

var _ DBInterface = &NoopDB{}

func (n *NoopDB) GetLastJobStatus(jobUID string) (*JobStatusRecord, error) {
	return nil, nil
}

func (n *NoopDB) SaveJobStatus(record *JobStatusRecord) error {
	return nil
}
