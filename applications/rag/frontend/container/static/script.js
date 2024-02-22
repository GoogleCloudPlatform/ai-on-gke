/* Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

function onReady() {
    autoResizeTextarea()
    populateDropdowns()
    fetchDLPEnabled()

    document.getElementById("prompt").addEventListener("keydown", e => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            e.target.form.requestSubmit();
        }
    });


    // Handle the chat form submission
    document.getElementById("form").addEventListener("submit", function(e) {
        e.preventDefault();

        var promptInput = document.getElementById("prompt");
        var prompt = promptInput.value;
        if (prompt === "") {
            return;
        }
        promptInput.value = "";

        var chatEl = document.getElementById("chat");
        var promptEl = Object.assign(document.createElement("p"), {classList: ["prompt"]});
        promptEl.textContent = prompt;
        chatEl.appendChild(promptEl);

        var responseEl = Object.assign(document.createElement("p"), {classList: ["response"]});
        chatEl.appendChild(responseEl);
        chatEl.scrollTop = chatEl.scrollHeight; // Scroll to bottom
        enableForm(false);

        // Collect filter data
        var filterEnabled = document.getElementById("toggle-filters").checked;
        var body = JSON.stringify({
            prompt: prompt,
        })
        if (filterEnabled) {
            var inspectTemplate = document.getElementById('inspect-template-dropdown').value;
            var deidentifyTemplate = document.getElementById('deidentify-template-dropdown').value;
            body = JSON.stringify({
                prompt: prompt,
                inspectTemplate: inspectTemplate,
                deidentifyTemplate: deidentifyTemplate,
            })
        }



        // Send data to the server
        fetch("/prompt", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: body
        }).then(response => {
            if (!response.ok) throw new Error(response.statusText);
            return response.json();
        }).then(data => {
            responseEl.textContent = data.response.text;
        }).catch(err => {
            responseEl.classList.replace("response", "error");
            responseEl.textContent = err.message;
        }).finally(() => enableForm(true));
    });

    // Handle templates
    document.getElementById("toggle-filters").addEventListener("change", function() {
        var filterOptions = document.getElementById("template-section");
        filterOptions.style.display = this.checked ? "block" : "none";
    });
}
if (document.readyState != "loading") onReady();
else document.addEventListener("DOMContentLoaded", onReady);


function enableForm(enabled) {
    var promptEl = document.getElementById("prompt");
    promptEl.toggleAttribute("disabled", !enabled);
    if (enabled) setTimeout(() => promptEl.focus(), 0);

    var submitEl = document.getElementById("submit");
    submitEl.toggleAttribute("disabled", !enabled);
    submitEl.textContent = enabled ? "Submit" : "...";
}

function autoResizeTextarea() {
    var textarea = document.getElementById('prompt');
    textarea.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = this.scrollHeight + 'px';
    });
}
// Function to handle the visibility of filter section
function toggleFilterSection(dlpEnabled) {
    var filterOptions = document.getElementById("filter-section");

    if (dlpEnabled) {
        filterOptions.style.display = "block";
    } else {
        filterOptions.style.display = "none";
    }
}


function fetchDLPEnabled() {
    fetch('/get_dlp_status')
        .then(response => response.json())
        .then(data => {
            var dlpEnabled = data.dlpEnabled;

            toggleFilterSection(dlpEnabled);
        })
        .catch(error => console.error('Error fetching DLP status:', error))
}

// Function to populate dropdowns
function populateDropdowns() {
    fetch('/get_inspect_templates')
        .then(response => response.json())
        .then(data => {
            const inspectDropdown = document.getElementById('inspect-template-dropdown');
            data.forEach(template => {
                let option = new Option(template, template);
                inspectDropdown.add(option);
            });
        })
        .catch(error => console.error('Error loading inspect templates:', error));

    fetch('/get_deidentify_templates')
        .then(response => response.json())
        .then(data => {
            const deidentifyDropdown = document.getElementById('deidentify-template-dropdown');
            data.forEach(template => {
                let option = new Option(template, template);
                deidentifyDropdown.add(option);
            });
        })
        .catch(error => console.error('Error loading deidentify templates:', error));
}