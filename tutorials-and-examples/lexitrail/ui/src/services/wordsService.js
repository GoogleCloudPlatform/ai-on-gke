import { getData } from './apiService';

// Fetch all wordsets
export const getWordsets = async () => {
  // Connect to the match making server
  const ws = new WebSocket(window.config.MATCH_MAKER_ADDRESS);

  ws.onopen = () => {
    console.log('Connected to WebSocket server');
    ws.send(JSON.stringify({ action: 'hello server' })); 
  };

  ws.onmessage = (event) => {
    // The match making server sends back the address for the allocated middle layer server
    const data = JSON.parse(event.data);
    console.log('Received:', data);
    // Set the middle layer address so the ui client can send requests to it
    if (data.connection !== undefined && window.config.MIDDLE_LAYER_ADDRESS === undefined) {
      console.log('data.connection:', data.connection);
      window.config.MIDDLE_LAYER_ADDRESS = data.connection;
      console.log('MIDDLE_LAYER_ADDRESS:', window.config.MIDDLE_LAYER_ADDRESS);
    }
  };

  ws.onerror = (error) => {
    console.error('WebSocket error:', error);
  };

  return await getData('/wordsets');
};

// Fetch words for a given wordset
export const getWordsByWordset = async (wordsetId) => {
  return await getData(`/wordsets/${wordsetId}/words`);
};


