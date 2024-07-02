import { sendRequestToApi } from "../utils/sendRequestToApi";

describe("sendRequestToApi", () => {
  beforeEach(() => {
    fetch.resetMocks();
  });

  test("successfully sends request and receives data", async () => {
    const mockData = { message: "Success" };
    fetch.mockResponseOnce(JSON.stringify(mockData), { status: 200 });

    const apiUrl = "/api/test";
    const payload = { key: "value" };

    const data = await sendRequestToApi(apiUrl, payload);

    expect(data).toEqual(mockData);
    expect(fetch).toHaveBeenCalledWith(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  });

  test("handles non-200 response and throws error", async () => {
    const mockErrorResponse = {
      error: "BadRequest",
      errorMessage: "Invalid input",
      warnings: "Some warnings",
    };
    fetch.mockResponseOnce(JSON.stringify(mockErrorResponse), { status: 400 });

    const apiUrl = "/api/test";
    const payload = { key: "value" };

    await expect(sendRequestToApi(apiUrl, payload)).rejects.toThrow(
      `Error: ${mockErrorResponse.error} \n        Message: ${mockErrorResponse.errorMessage}`
    );

    expect(fetch).toHaveBeenCalledWith(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  });

  test("handles fetch error and throws error", async () => {
    const mockErrorMessage = "Network error";
    fetch.mockReject(new Error(mockErrorMessage));

    const apiUrl = "/api/test";
    const payload = { key: "value" };

    await expect(sendRequestToApi(apiUrl, payload)).rejects.toThrow(
      mockErrorMessage
    );

    expect(fetch).toHaveBeenCalledWith(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  });

  test("sends request with custom content type", async () => {
    const mockData = { message: "Success" };
    fetch.mockResponseOnce(JSON.stringify(mockData), { status: 200 });

    const apiUrl = "/api/test";
    const payload = { key: "value" };
    const customContentType = "multipart/form-data";

    const data = await sendRequestToApi(apiUrl, payload, customContentType);

    expect(data).toEqual(mockData);
    expect(fetch).toHaveBeenCalledWith(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": customContentType,
      },
      body: JSON.stringify(payload),
    });
  });
});
