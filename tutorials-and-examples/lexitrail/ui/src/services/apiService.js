import axios from 'axios';
//import { useAuth } from '../hooks/useAuth';

const API_BASE_URL = window.config.API_BASE_URL;

// Log the API base URL for diagnostics
console.log(`API_BASE_URL is: ${API_BASE_URL}`);

// Get the access token from sessionStorage
const getAccessToken = () => sessionStorage.getItem('access_token');
// const getAccessToken = ()=>useAuth.accessToken;

// Function to handle any GET request
export const getData = async (endpoint) => {
  try {
    // console.log(`Requesting: ${API_BASE_URL}${endpoint}`);
    const accessToken = getAccessToken(); // Use the access token
    const response = await axios.get(`${API_BASE_URL}${endpoint}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`, // Use access token for backend authentication
      },
    });
    return response.data;
  } catch (error) {
    // Handle 404 by returning null, which indicates the resource does not exist
    if (error.response && error.response.status === 404) {
      console.error(`GET ${endpoint} failed: 404 Not Found`);
      return null;
    } else {
      console.error(`GET ${endpoint} failed:`, error);
      throw error; // Re-throw the error for other types of failures
    }
  }
};

// Function to handle any POST request
export const postData = async (endpoint, data) => {
  try {
    const accessToken = getAccessToken(); // Use the access token
    const response = await axios.post(`${API_BASE_URL}${endpoint}`, data, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return response.data;
  } catch (error) {
    console.error(`POST ${endpoint} failed:`, error);
    throw error;
  }
};

// Function to handle any PUT request
export const putData = async (endpoint, data) => {
  try {
    const accessToken = getAccessToken(); // Use the access token
    const response = await axios.put(`${API_BASE_URL}${endpoint}`, data, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    console.log(`Get response: ${response.data}`);
    return response.data;
  } catch (error) {
    console.error(`PUT ${endpoint} failed:`, error);
    throw error;
  }
};

// Function to handle request to middle layer
export const callMiddleLayer = async (middleLayerURL, endpoint, data) => {
  try {
    const accessToken = getAccessToken(); // Use the access token
    const middleLayerAPIPath = `http://${middleLayerURL}/update${endpoint}`; // Construct the middle layer API path
    console.log(`Calling middle layer: ${middleLayerAPIPath}`);
    const response = await axios.post(middleLayerAPIPath, data, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return response.data;
  } catch (error) {
    console.error(`PUT ${endpoint} failed:`, error);
    throw error;
  }
};

// Function to handle any DELETE request
export const deleteData = async (endpoint) => {
  try {
    const accessToken = getAccessToken(); // Use the access token
    const response = await axios.delete(`${API_BASE_URL}${endpoint}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return response.data;
  } catch (error) {
    console.error(`DELETE ${endpoint} failed:`, error);
    throw error;
  }
};
