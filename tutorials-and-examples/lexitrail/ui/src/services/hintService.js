import { getData } from './apiService';

// Fetch hint for a given user and word
export const getHint = async (userId, wordId) => {
  return await getData(`/hint/generate_hint?user_id=${userId}&word_id=${wordId}`);
};

// Regenerate hint for a given user and word
export const regenerateHint = async (userId, wordId) => {
  return await getData(`/hint/generate_hint?user_id=${userId}&word_id=${wordId}&force_regenerate=true`);
};