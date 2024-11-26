import os
import sky

LR_CANDIDATES = [0.1, 1.0]
MAX_STEPS_CANDIDATES = [100]
task = sky.Task.from_yaml('train.yaml')

job_idx = 1
# Here we could integrate with MLFlow to track experiments.
for lr in LR_CANDIDATES:
  for max_steps in MAX_STEPS_CANDIDATES:
    task.update_envs({'LR': lr, 'MAX_STEPS': max_steps})
    sky.launch(
      task,
      cluster_name=f'train-cluster{job_idx}',
      detach_run=True,
      retry_until_up=True,
    )
    job_idx += 1
