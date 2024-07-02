import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom/extend-expect";
import ChatScreen from "../App";
import { sendRequestToApi } from "../utils/sendRequestToAPI";

jest.mock("./utils/sendRequestToAPI");

describe("ChatScreen Component", () => {
  test("renders initial messages", () => {
    render(<ChatScreen />);
    expect(screen.getByText("Hello there!")).toBeInTheDocument();
  });

  test("sends a message", async () => {
    sendRequestToApi.mockResolvedValueOnce({});

    render(<ChatScreen />);

    const input = screen.getByPlaceholderText("Type your message...");
    const sendButton = screen.getByText("Send");

    fireEvent.change(input, { target: { value: "Test message" } });
    fireEvent.click(sendButton);

    await waitFor(() =>
      expect(screen.getByText("Test message")).toBeInTheDocument()
    );
  });

  test("handles send message error", async () => {
    sendRequestToApi.mockRejectedValueOnce(new Error("API Error"));

    render(<ChatScreen />);

    const input = screen.getByPlaceholderText("Type your message...");
    const sendButton = screen.getByText("Send");

    fireEvent.change(input, { target: { value: "Test message" } });
    fireEvent.click(sendButton);

    await waitFor(() =>
      expect(screen.getByText("Error: API Error")).toBeInTheDocument()
    );
  });

  test("handles file upload", async () => {
    sendRequestToApi.mockResolvedValueOnce({});

    render(<ChatScreen />);

    const fileInput = screen
      .getByLabelText(/Upload your documents/i)
      .querySelector('input[type="file"]');
    const file = new File(["file content"], "test.txt", { type: "text/plain" });

    fireEvent.change(fileInput, { target: { files: [file] } });

    const uploadButton = screen.getByText("Upload");
    fireEvent.click(uploadButton);

    await waitFor(() =>
      expect(sendRequestToApi).toHaveBeenCalledWith(
        "/upload_documents",
        expect.any(FormData),
        "multipart/form-data"
      )
    );
  });

  test("toggles accordion sections", () => {
    render(<ChatScreen />);

    const uploadDocumentsHeader = screen.getByText(/Upload your documents/i);
    fireEvent.click(uploadDocumentsHeader);
    expect(
      screen.getByText(/Uploading files is necessary/i)
    ).toBeInTheDocument();

    const dlpHeader = screen.getByText(/Enable Data Loss Prevention \(DLP\)/i);
    fireEvent.click(dlpHeader);
    expect(screen.getByText(/Enable DLP/i)).toBeInTheDocument();
  });

  test("enables and sets text moderation value", () => {
    render(<ChatScreen />);

    const textModerationHeader = screen.getByText(/Enable Text Moderation/i);
    fireEvent.click(textModerationHeader);
    const enableCheckbox = screen.getByLabelText(/Enable/i);
    fireEvent.click(enableCheckbox);

    expect(screen.getByText(/Set value/i)).toBeInTheDocument();

    const rangeInput = screen.getByRole("slider");
    fireEvent.change(rangeInput, { target: { value: 60 } });
    expect(rangeInput.value).toBe("60");
  });
});
