const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;

// Serwowanie plików statycznych (HTML, CSS, JS oraz foldery uploads)
app.use(express.static(__dirname));

// Endpoint do pobierania listy plików dla danego urządzenia
app.get('/api/files/:device', (req, res) => {
    const device = req.params.device;
    const dirPath = path.join(__dirname, 'uploads', device);

    if (!fs.existsSync(dirPath)) {
        return res.json([]);
    }

    fs.readdir(dirPath, (err, files) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ error: 'Failed to scan directory' });
        }

        // Filtrujemy tylko obrazki i sortujemy alfabetycznie
        const images = files
            .filter(file => /\.(png|jpg|jpeg|webp)$/i.test(file))
            .sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));

        res.json(images);
    });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    console.log(`Place iPhone screenshots in: /uploads/iphone/`);
    console.log(`Place iPad screenshots in:   /uploads/ipad/`);
});