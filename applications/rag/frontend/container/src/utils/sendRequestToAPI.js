const sendRequestToApi = async (
  apiUrl,
  payload,
  contentType = "application/json"
) => {
  try {
    const response = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": contentType,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const { error, errorMessage, warnings } = await response.json();
      console.warn(warnings);

      throw new Error(`Error: ${error} 
        Message: ${errorMessage}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    throw new Error(error);
  }
};

export { sendRequestToApi };
