-- Create an enum type for job status
CREATE TYPE job_status_enum AS ENUM ('pending', 'scheduled', 'unschedulable');

-- Table for tracking which job is scheduled on which node pool
CREATE TABLE IF NOT EXISTS replicated_job_status (
    job_uid VARCHAR(255) NOT NULL,
    index INTEGER NOT NULL,
    job_name VARCHAR(255) NOT NULL,
    jobset_name VARCHAR(255) NOT NULL,
    node_pool VARCHAR(255) NOT NULL,
    status job_status_enum NOT NULL DEFAULT 'pending',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (job_uid, index)
);

-- Create an index on job_name for faster lookups
CREATE INDEX IF NOT EXISTS idx_job_name ON replicated_job_status(job_name);

-- Create an index on jobset_name for faster lookups
CREATE INDEX IF NOT EXISTS idx_jobset_name ON replicated_job_status(jobset_name);

-- Create an index on node_pool for faster lookups
CREATE INDEX IF NOT EXISTS idx_node_pool ON replicated_job_status(node_pool);

-- Create an index on status for faster lookups
CREATE INDEX IF NOT EXISTS idx_status ON replicated_job_status(status);