// Configuration for Apple App Store Dimensions
const DEVICES = {
    iphone: {
        width: 1290,
        height: 2796,
        name: "iPhone 6.7 inch",
        safeAreaTop: 200, // Space for text
        screenshotScale: 0.85,
        borderRadius: 60
    },
    ipad: {
        width: 2048,
        height: 2732,
        name: "iPad Pro 12.9 inch",
        safeAreaTop: 150,
        screenshotScale: 0.85,
        borderRadius: 40
    }
};

const STATE = {
    device: 'iphone',
    slots: Array(8).fill(null).map((_, i) => ({
        id: i + 1,
        title: `Feature ${i + 1}`,
        image: null,
        key: `screen_${i + 1}`
    })),
    bgColor: '#ffffff',
    textColor: '#000000',
    availableLocales: ['en', 'pl'], // Defined explicitly or fetched
    currentLocaleData: {}
};

document.addEventListener('DOMContentLoaded', () => {
    initUI();
    renderGrid();
    fetchAndLoadImages();
    loadLocales();
});

// Load locale files dynamically
async function loadLocales() {
    const selector = document.getElementById('languageSelect');
    selector.innerHTML = '';
    
    // We assume these files exist in /locales/ folder
    // In a more advanced server, we could scan the folder, but for now we list them in STATE
    
    for (const code of STATE.availableLocales) {
        const option = document.createElement('option');
        option.value = code;
        option.textContent = code.toUpperCase();
        selector.appendChild(option);
    }

    // Load first locale by default
    if (STATE.availableLocales.length > 0) {
        await switchLanguage(STATE.availableLocales[0]);
    }
}

async function switchLanguage(langCode) {
    try {
        const res = await fetch(`locales/${langCode}.json`);
        const data = await res.json();
        STATE.currentLocaleData = data;
        applyLocalization(data);
        document.getElementById('languageSelect').value = langCode;
    } catch (e) {
        console.error(`Failed to load language: ${langCode}`, e);
    }
}

async function fetchAndLoadImages() {
    try {
        const response = await fetch(`/api/files/${STATE.device}`);
        const files = await response.json();
        
        // Reset images first
        STATE.slots.forEach(slot => slot.image = null);

        // Load new images
        files.forEach((file, index) => {
            if (index < STATE.slots.length) {
                const img = new Image();
                img.src = `/uploads/${STATE.device}/${file}`;
                img.onload = () => {
                    STATE.slots[index].image = img;
                    drawSlot(index);
                };
            }
        });
        // Redraw to clear slots that didn't get new images
        setTimeout(redrawAll, 100); 
    } catch (error) {
        console.error('Failed to load images automatically:', error);
    }
}

function initUI() {
    // Device Switcher
    document.getElementById('deviceType').addEventListener('change', (e) => {
        STATE.device = e.target.value;
        updatePreviewRatios();
        renderGrid(); // Re-render grid to clear old inputs/canvases
        fetchAndLoadImages(); // Fetch new images for the selected device
    });

    // Colors
    document.getElementById('bgColor').addEventListener('input', (e) => {
        STATE.bgColor = e.target.value;
        redrawAll();
    });

    document.getElementById('textColor').addEventListener('input', (e) => {
        STATE.textColor = e.target.value;
        redrawAll();
    });

    // Language Switcher
    document.getElementById('languageSelect').addEventListener('change', (e) => {
        if(e.target.value) switchLanguage(e.target.value);
    });

    // Download All (ZIP)
    document.getElementById('downloadAllBtn').addEventListener('click', downloadZipArchive);
}

function updatePreviewRatios() {
    const config = DEVICES[STATE.device];
    const containers = document.querySelectorAll('.preview-container');
    containers.forEach(div => {
        div.style.aspectRatio = `${config.width}/${config.height}`;
    });
}

function renderGrid() {
    const grid = document.getElementById('gridContainer');
    grid.innerHTML = '';

    STATE.slots.forEach((slot, index) => {
        const el = document.createElement('div');
        el.className = 'screenshot-slot';
        el.innerHTML = `
            <div class="slot-header">
                <span>#${slot.id}</span>
                <span style="font-size: 10px; color: #666;">Key: ${slot.key}</span>
            </div>
            
            <input type="text" id="title-${index}" value="${slot.title}" placeholder="Top Text">
            
            <div class="file-input-wrapper">
                <button class="file-btn">Upload Screenshot</button>
                <input type="file" id="file-${index}" accept="image/*">
            </div>

            <div class="preview-container">
                <canvas id="canvas-${index}"></canvas>
            </div>
        `;
        grid.appendChild(el);

        // Events for this slot
        const titleInput = el.querySelector(`#title-${index}`);
        titleInput.addEventListener('input', (e) => {
            slot.title = e.target.value;
            // Also update current locale data in memory so it persists if we swap back/forth manually
            // (Note: this doesn't save to file, purely UI state)
            drawSlot(index);
        });

        const fileInput = el.querySelector(`#file-${index}`);
        fileInput.addEventListener('change', (e) => {
            handleImageUpload(e, index);
        });
    });

    // Initial Draw
    setTimeout(() => redrawAll(), 100);
}

function handleImageUpload(e, index) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
        const img = new Image();
        img.onload = () => {
            STATE.slots[index].image = img;
            drawSlot(index);
        };
        img.src = event.target.result;
    };
    reader.readAsDataURL(file);
}

function applyLocalization(data) {
    STATE.slots.forEach((slot, index) => {
        if (data[slot.key]) {
            slot.title = data[slot.key];
            const input = document.getElementById(`title-${index}`);
            if (input) input.value = slot.title;
        }
    });
    redrawAll();
}

function redrawAll() {
    STATE.slots.forEach((_, i) => drawSlot(i));
}

function drawSlot(index) {
    const canvas = document.getElementById(`canvas-${index}`);
    if (!canvas) return;

    const config = DEVICES[STATE.device];
    const slot = STATE.slots[index];

    // Set actual resolution
    canvas.width = config.width;
    canvas.height = config.height;
    
    const ctx = canvas.getContext('2d');

    // 1. Background
    ctx.fillStyle = STATE.bgColor;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // 2. Text (Title)
    if (slot.title) {
        ctx.fillStyle = STATE.textColor;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        
        // Font sizing logic
        const fontSize = STATE.device === 'ipad' ? 120 : 90;
        ctx.font = `bold ${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial`;
        
        wrapText(ctx, slot.title, canvas.width / 2, 100, canvas.width - 100, fontSize * 1.2);
    }

    // 3. Image (Screenshot)
    if (slot.image) {
        // Calculate scaling to fit "inside" the frame area
        // We want the screenshot to take up X% of width and anchor to bottom
        const targetWidth = canvas.width * config.screenshotScale;
        
        // Maintain aspect ratio of the uploaded image
        const scale = targetWidth / slot.image.width;
        const targetHeight = slot.image.height * scale;

        const x = (canvas.width - targetWidth) / 2;
        const y = canvas.height - targetHeight + 50; // Push slightly off bottom for "infinity" look

        // Draw shadow
        ctx.save();
        ctx.shadowColor = "rgba(0,0,0,0.3)";
        ctx.shadowBlur = 50;
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 20;

        // Draw rounded rectangle clip
        roundRect(ctx, x, y, targetWidth, targetHeight, config.borderRadius);
        ctx.fillStyle = "#fff";
        ctx.fill();
        ctx.shadowColor = "transparent"; // Reset shadow for image
        
        // Clip and draw image
        ctx.clip(); 
        ctx.drawImage(slot.image, x, y, targetWidth, targetHeight);
        ctx.restore();
    }
}

// Helper: Wrap Text
function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
    const words = text.split(' ');
    let line = '';

    for(let n = 0; n < words.length; n++) {
        const testLine = line + words[n] + ' ';
        const metrics = ctx.measureText(testLine);
        const testWidth = metrics.width;
        if (testWidth > maxWidth && n > 0) {
            ctx.fillText(line, x, y);
            line = words[n] + ' ';
            y += lineHeight;
        } else {
            line = testLine;
        }
    }
    ctx.fillText(line, x, y);
}

// Helper: Round Rect
function roundRect(ctx, x, y, w, h, r) {
    if (w < 2 * r) r = w / 2;
    if (h < 2 * r) r = h / 2;
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
}

async function downloadZipArchive() {
    const zip = new JSZip();
    const btn = document.getElementById('downloadAllBtn');
    const originalText = btn.textContent;
    btn.textContent = "Generating ZIP...";
    btn.disabled = true;

    try {
        // Iterate through all available languages
        for (const langCode of STATE.availableLocales) {
            // 1. Fetch text data for this language
            const res = await fetch(`locales/${langCode}.json`);
            const langData = await res.json();
            
            // 2. Create a folder in zip
            const folder = zip.folder(langCode);

            // 3. Render each slot with this language data
            for (let i = 0; i < STATE.slots.length; i++) {
                const slot = STATE.slots[i];
                // Only generate if we have an image
                if (slot.image) {
                    // Temporarily apply title for rendering (without changing UI state permanently)
                    const originalTitle = slot.title;
                    slot.title = langData[slot.key] || ""; // Use empty string if missing
                    
                    // Force redraw on the specific canvas
                    drawSlot(i);
                    
                    // Get data
                    const canvas = document.getElementById(`canvas-${i}`);
                    const dataUrl = canvas.toDataURL('image/png');
                    const base64Data = dataUrl.split(',')[1];
                    
                    // Add to zip
                    folder.file(`${STATE.device}_${i+1}.png`, base64Data, {base64: true});

                    // Restore title
                    slot.title = originalTitle;
                }
            }
        }
        
        // Restore UI to current selected language
        const currentLang = document.getElementById('languageSelect').value;
        if (currentLang) switchLanguage(currentLang);

        // Generate and save
        const content = await zip.generateAsync({type:"blob"});
        saveAs(content, `screenshots_${STATE.device}.zip`);

    } catch (e) {
        console.error("Error generating ZIP:", e);
        alert("Error generating ZIP. Check console.");
    } finally {
        btn.textContent = originalText;
        btn.disabled = false;
    }
}