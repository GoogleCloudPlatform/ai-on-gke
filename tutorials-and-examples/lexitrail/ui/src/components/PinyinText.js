import React from 'react';

// Define tone colors
const toneColors = {
    1: '#FF4500', // Red for first tone
    2: '#FFA500', // Orange for second tone
    3: '#32CD32', // Green for third tone
    4: '#800080', // Purple for fourth tone
    0: '#000000', // Black for neutral tone
};

// Function to determine the tone based on accented characters
const getTone = (char) => {
    if ('āēīōūǖĀĒĪŌŪǕ'.includes(char)) return 1;
    if ('áéíóúǘÁÉÍÓÚǗ'.includes(char)) return 2;
    if ('ǎěǐǒǔǚǍĚǏǑǓǙ'.includes(char)) return 3;
    if ('àèìòùǜÀÈÌÒÙǛ'.includes(char)) return 4;
    return 0; // Neutral tone if no tone mark is found
};

// Function to detect syllables based on vowels in pinyin
const splitSyllables = (text) => {
    // Regex to match pinyin syllables
    const syllableRegex = /([bpmfdtnlgkhjqxrzcsyw]?u?[aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]*|[a-z]+)(?=\b|[^a-z])/gi;
    return text.match(syllableRegex) || []; // Returns an array of syllables
};

// Function to render pinyin with colored tones and syllable separation
const renderPinyinWithSyllables = (text) => {
    const syllables = splitSyllables(text); // Split text into syllables

    return syllables.map((syllable, index) => {
        const characters = Array.from(syllable); // Convert syllable to array of characters

        // Render each syllable with colored tones
        const syllableContent = characters.map((char, charIndex) => {
            const tone = getTone(char);
            const color = toneColors[tone];

            return (
                <span key={`${index}-${charIndex}`} style={{ backgroundColor: tone > 0 ? '#fff' : 'inherit', color: tone > 0 ? color : 'inherit' }}>
                    {char}
                </span>
            );
        });

        // Add a hyphen `-` between syllables, except after the last one
        return (
            <React.Fragment key={index}>
                {syllableContent}
                {index < syllables.length - 1 && <span>-</span>}
            </React.Fragment>
        );
    });
};


const renderPinyin = (text) => {
    const characters = Array.from(text); // Convert text to an array of characters

    return characters.map((char, index) => {
        const tone = getTone(char);
        const color = toneColors[tone];

        // Return each character with a span, only applying color to vowels with tones
        return (
            <span key={index} style={{ fontWeight: tone > 0 ? 'bold' : 'inherit', color: tone > 0 ? color : 'inherit' }}>
                {char}
            </span>
        );
    });
};

// Usage example in a React component
const PinyinText = ({ text }) => {
    return <div>{renderPinyin(text)}</div>;
};

export default PinyinText;
