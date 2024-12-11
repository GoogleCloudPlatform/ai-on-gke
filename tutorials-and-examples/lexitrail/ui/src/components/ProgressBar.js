import React from 'react';

const ProgressBar = ({ totalWords, memorized, notMemorized }) => {
  const completed = memorized + notMemorized;
  const progressPercentage = (completed / totalWords) * 100;

  return (
    <div className="progress-bar">
      <div className="progress" style={{ width: `${progressPercentage}%` }}></div>
      <div className="progress-info">
        {completed}/{totalWords}
      </div>
    </div>
  );
};

export default ProgressBar;
