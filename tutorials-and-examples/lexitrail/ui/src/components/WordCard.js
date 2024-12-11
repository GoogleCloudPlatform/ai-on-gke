import React, { useState, useEffect } from 'react';
import { getHint, regenerateHint } from '../services/hintService';
import { GameMode } from './Game';
import PinyinText from './PinyinText';
import '../styles/WordCard.css';

const WordCard = ({ mode, word, isFlipped, handleMemorized, handleNotMemorized, toggleExclusion, feedbackClass, provideFeedback, setFlippedState }) => {
  const [hintImage, setHintImage] = useState(null);
  const [loadingHint, setLoadingHint] = useState(true);
  const [loadingWord, setLoadingWord] = useState(true); // New state for controlling button loading state

  useEffect(() => {
    // Validate that user_id and word_id are set correctly
    if (word.user_id && word.word_id) {
      setLoadingWord(false);

      // Clear the current hint and show loading message
      setHintImage(null);

      // Fetch the hint image when the component mounts or the word changes
      const fetchHint = async () => {
        try {
          setLoadingHint(true);
          const response = await getHint(word.user_id, word.word_id);
          if (response && response.data) {
            setHintImage(response.data.hint_image);
          }
        } catch (error) {
          console.error('Failed to load hint image:', error);
        } finally {
          setLoadingHint(false);
        }
      };
      fetchHint();
    } else {
      console.error(`Word: ${word ? JSON.stringify(word) : ""} has invalid user_id: ${word ? word.user_id : ""} or word_id: ${word ? word.word_id : ""}.`);
      setLoadingHint(false);
      setLoadingWord(false); // Set loadingWord to false if user_id or word_id is invalid
    }
  }, [word.user_id, word.word_id]);

  const handleCardClick = () => {
    setFlippedState(!isFlipped);
  };


  const stopPropagation = (e) => {
    e.stopPropagation();
  };

  const handleButtonClick = (action) => {
    // Set loadingWord to true to disable all buttons
    setLoadingWord(true);
    setHintImage(null);

    // Save the current word ID to check if it changes after the action
    const currentWordId = word.word_id;

    // Execute the action
    action();

    // Check if the word has changed
    setTimeout(() => {
      if (word.word_id === currentWordId) {
        // If the word is still the same, reset the loading state and hint image
        setLoadingWord(false);
        setHintImage(hintImage); // Restore the previous hint image
      }
    }, 0); // Run this check right after the action to update states
  };

 

  const onMemorized = () => {
    provideFeedback(true, () => {
      if (isFlipped) {
        setFlippedState(false); // Ensure the card flips back
      }
      handleMemorized(); // Call the memorized handler
    });
  };

  const onNotMemorized = () => {
    provideFeedback(false, () => {
      if (isFlipped) {
        setFlippedState(false); // Ensure the card flips back
      }
      handleNotMemorized(); // Call the not-memorized handler
    });
  };

  const onQuizOptionClicked = (isCorrect) => {
    provideFeedback(isCorrect, () => {
      if (isCorrect) {
        handleMemorized();
      } else {
        handleNotMemorized();
      }
    });
  };

  const handleRegenerateHint = async () => {
    if (word.user_id && word.word_id) {
      setLoadingHint(true); // Set loadingHint to true while regenerating hint
      try {
        const response = await regenerateHint(word.user_id, word.word_id);
        if (response && response.data) {
          setHintImage(response.data.hint_image);
        }
      } catch (error) {
        console.error('Failed to regenerate hint image:', error);
      } finally {
        setLoadingHint(false); // Set loadingHint to false once hint regeneration is done
      }
    } else {
      console.error('Invalid user_id or word_id for regeneration:', word.user_id, word.word_id);
    }
  };

  // Helper function to determine the style for recall states
  const getRecallStateStyle = (state) => {
    return {
      backgroundColor: state === 0 ? 'green' : 'red',
      color: 'white',
    };
  };

  // Remove leading and trailing quotes and whitespace
  const removeQuotes = (text) => {
    if (!text) {
      return "";
    }

    return text.replace(/^['"]+|['"]+$/g, '').trim();
  }

  // Remove quotes and calculate the longest line for font size
  const calculateFontSize = (text, minSize = 1.5) => {
    // Remove leading and trailing quotes
    const trimmedText = text.trim();

    // Split text by '\n' and find the longest line
    const lines = trimmedText.split('\n');
    const longestLineLength = Math.max(...lines.map(line => removeQuotes(line).length));

    // Calculate font size based on the longest line length
    const fontSize = Math.max(5 / (Math.pow(longestLineLength,0.60)), minSize); // Ensure the font size doesn't go too small
    return `${fontSize}rem`;
  };

  return (
    <div className={`word-card ${feedbackClass}`}>
      {/* Metadata Section */}

      {mode !== GameMode.TEST ? (
        <div className="metadata">
          {/* THIS IS FOR DEBUGGING
        <span>{word.index}</span>
        */}
          <button
            className={`exclude-button ${word.is_included ? 'red' : 'green'}`}
            onClick={(e) => {
              stopPropagation(e);
              handleButtonClick(toggleExclusion);  // Disable all buttons and toggle exclusion
            }}
            disabled={loadingWord} // Disable button while loading a new word
          >
            {word.is_included ? 'Exclude' : 'Include'}
          </button>

          <div className="recall-state" style={getRecallStateStyle(word.recall_state)}>
            {loadingWord ? '⏳' : word.recall_state}
          </div>

          <div className="recall-history">
            {word.recall_history.map((recall, index) => (
              <div key={index} className="recall-item">
                <div className="recall-item-time">{recall.recall_time}</div>
                <div className="recall-item-guess">{recall.recall ? '✅' : '❌'}</div>
                <div
                  className="recall-item-old-state"
                  style={getRecallStateStyle(recall.old_recall_state ?? 0)}
                >
                  {recall.old_recall_state ?? 0}
                </div>
                <div className="recall-item-transition">→</div>
                <div
                  className="recall-item-new-state"
                  style={getRecallStateStyle(recall.new_recall_state)}
                >
                  {recall.new_recall_state}
                </div>
              </div>
            ))}
          </div>
        </div>) :
        (<></>)}

      {/* Hint Image Section */}
      <div className="hint-image-container">
        {loadingHint ? (
          <div className="loading-hint">Loading hint...</div>
        ) : (
          hintImage && (
            <div className="hint-image-wrapper">
              <img src={`data:image/jpeg;base64,${hintImage}`} alt="Hint" className="hint-image" />
              <button className="regenerate-hint-button" onClick={handleRegenerateHint} disabled={loadingWord}>🔄</button>
            </div>
          )
        )}
      </div>

      <div onClick={mode === GameMode.TEST ? undefined : handleCardClick} className={`word-card-inner ${isFlipped ? 'flipped' : ''}`}>
        <div
          className="word-card-front"
        >

          {loadingWord ?
            <p>⏳</p>
            :
            <p style={{ fontSize: calculateFontSize(word.word) }}>{word.word}</p>

          }

        </div>
        <div
          className="word-card-back"
          style={{ fontSize: "1rem" }} // Dynamically set the font size
        >

          {loadingWord ? '⏳ Loading...' :
            <div className="word-meaning">
              <p style={{ fontSize: calculateFontSize(word.def1, 1.0) }}>
                <PinyinText text={word.def1} />
              </p>
              <p className="word-translation" style={{ fontSize: calculateFontSize(word.def2, 1.0) }}>
                {removeQuotes(word.def2)}
              </p>
            </div>
          }

        </div>
      </div>


      {mode !== GameMode.TEST ? (
        <div className="practice-buttons" onClick={stopPropagation}>
          <button onClick={onNotMemorized} disabled={loadingWord}>
            {loadingWord ? '⏳' : '❌'}
          </button>
          <button onClick={onMemorized} disabled={loadingWord}>
            {loadingWord ? '⏳' : '✔️'}
          </button>
        </div>
      )
        :
        (
          <div className="test-buttons" onClick={stopPropagation}>
            {[word.quiz_option1, word.quiz_option2, word.quiz_option3, word.quiz_option4].map((option, index) => (
              <button
                key={index}
                onClick={() => onQuizOptionClicked(option.correct)}
                disabled={loadingWord}
              >
                {loadingWord ? '⏳' : <PinyinText text={option.pinyin} />}
              </button>
            ))}
          </div>
        )
      }



    </div>
  );
};

export default WordCard;
