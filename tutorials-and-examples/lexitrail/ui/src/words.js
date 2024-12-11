import Papa from 'papaparse';

const wordsFilePath = '/words/hsk3.csv';

async function fetchCSV(filePath) {
  const response = await fetch(filePath);
  if (!response.ok) {
    throw new Error(`Failed to fetch CSV file: ${response.statusText}`);
  }
  const text = await response.text();
  return text;
}

async function loadWordsFromCSV(filePath) {
  const csvString = await fetchCSV(filePath);
  return new Promise((resolve, reject) => {
    Papa.parse(csvString, {
      header: true,
      complete: (results) => {
        if (results.errors.length > 0) {
          reject(results.errors);
        } else {
          const words = results.data.map(row => ({
            word: row.Chinese,
            meaning: `${row.Pinyin}\n\n${row.English}`,
          }));
          resolve(words);
        }
      },
      error: (error) => reject(error),
    });
  });
}

export function getWords() {
  return loadWordsFromCSV(wordsFilePath);
}
