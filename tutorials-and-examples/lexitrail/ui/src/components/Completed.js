import React from 'react';
import '../styles/Completed.css';

const Completed = ({ timeElapsed, firstTimeCorrect, incorrectAttempts, resetGame }) => {
  const totalWords = firstTimeCorrect.length + Object.keys(incorrectAttempts).length;
  const memorizedPercentage = totalWords > 0 ? (firstTimeCorrect.length / totalWords) * 100 : 0;

  return (
    <div className="container completed">
      <div className="completed-time">{Math.floor(timeElapsed / 60)}:{('0' + timeElapsed % 60).slice(-2)}</div>
      <div className="completed-stats">{Math.round(memorizedPercentage)}%</div>
      <ul className="completed-list">
        {Object.keys(incorrectAttempts).map((word, index) => (
          <li key={firstTimeCorrect.length + index}>{word} 
            <span className="completed-incorrect-indicator">({incorrectAttempts[word] + 1} attempts)</span>
          </li>
        ))}
        {firstTimeCorrect.map((item, index) => (
          <li key={index}>{item.word}</li>
        ))}
      </ul>
      <button className="completed-button" onClick={resetGame}>Play again</button>
    </div>
  );
};

export default Completed;
