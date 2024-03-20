import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { Container, Button, FormGroup, Input, Label } from 'reactstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
const API_ENDPOINT = "http://35.223.136.252/run";
const App: React.FC = () => {
    const [response, setResponse] = useState<string[]>([]);
    const handleButtonClick = async (text: string) => {
        try {
            const result = await fetch(`${API_ENDPOINT}?text=${text}`, {
                method: 'POST',
            });
            const rawData = await result.text();
            const parsedData: string[] = JSON.parse(rawData);
            setResponse(parsedData);
        } catch (error) {
            console.error("Failed to fetch data:", error);
        }
    };
    return (
        <Container className="mt-5">
            <div className="mb-3">
                {["apples", "soccer", "planets", "dolphins", "memory"].map((text) => (
                    <Button className="mr-2 mb-2" key={text} onClick={() => handleButtonClick(text)}>
                        {text}
                    </Button>
                ))}
            </div>
            <FormGroup>
                <Label for="fact">Fact:</Label>
                <Input type="textarea" value={response[0] || ""} readOnly rows={5} id="fact" />
            </FormGroup>
            <FormGroup>
                <Label for="translation">Translation:</Label>
                <Input type="textarea" value={response[1] || ""} readOnly rows={5} id="translation" />
            </FormGroup>
        </Container>
    );
};
ReactDOM.render(<App />, document.getElementById('root'));
