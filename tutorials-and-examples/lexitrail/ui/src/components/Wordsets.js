// src/components/Wordsets.js
import React, { useState, useEffect } from 'react';
import { getWordsets } from '../services/wordsService'; // Assuming getWordsets is implemented in wordsService.js
import { useNavigate } from 'react-router-dom';
import '../styles/Wordsets.css'; // Create a CSS file for styling the wordsets grid
import { GameMode } from './Game';

const Wordsets = () => {
  const [wordsets, setWordsets] = useState([]);  // Initialize as empty array
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);  // Track errors if fetching fails
  const navigate = useNavigate();

  useEffect(() => {
    // Fetch all wordsets when the component is mounted
    getWordsets()
      .then((response) => {
        if (response && Array.isArray(response.data)) {
          setWordsets(response.data);  // Access the data property
        } else {
          setWordsets([]);  // Fallback to empty array if data is not an array
          console.error("Expected array but got:", response);
        }
      })
      .catch(error => {
        console.error('Error fetching wordsets:', error);
        setWordsets([]);  // Handle the error case by setting it to an empty array
      })
      .finally(() => setLoading(false));
  }, []);

  const handleWordsetClick = (wordsetId, mode) => {
    // Navigate to the game route with the wordsetId and whether to show excluded words
    navigate(`/game/${wordsetId}/${mode}`);
  };

  return (
    <div className="wordsets-container">
      <div className="wordsets-grid">
        {wordsets.length > 0 ? (
          wordsets.map(wordset => (
            <div key={wordset.wordset_id} className="wordset-tile">
              <div className="wordset-button-group" >
                <div className="wordset-header">
                  <div className="wordset-header-text">{wordset.description}</div>
                </div>

                <button
                  className="wordset-button wordset-button-practice"
                  onClick={() => handleWordsetClick(wordset.wordset_id, GameMode.PRACTICE)}
                >
                  Practice
                </button>


                <button
                  className="wordset-button wordset-button-excluded"
                  onClick={() => handleWordsetClick(wordset.wordset_id, GameMode.SHOW_EXCLUDED)}
                >
                  Show Excluded
                </button>

                <button
                  className="wordset-button wordset-button-test"
                  onClick={() => handleWordsetClick(wordset.wordset_id, GameMode.TEST)}
                >
                  Test!
                </button>
              </div>
            </div>
          ))
        ) : (
          <p>No wordsets available.</p>
        )}
      </div>
    </div>
  );
};

export default Wordsets;
