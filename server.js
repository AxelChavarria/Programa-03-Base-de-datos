import sql from 'mssql';
import express from 'express';
import cors from 'cors';
import fs from 'fs';          
import { fileURLToPath } from 'url';
import path from 'path';      


const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(express.json());
app.use(cors());

app.use(express.static(__dirname));

const config = {
    user: 'bdd_sql_2026', 
    password: 'Tec20IC26', 
    server: 'py-01-bdd-1s2026.database.windows.net', 
    database: 'Proyecto03BDD',
    options: {
        encrypt: true, 
        trustServerCertificate: true 
    }
};




// Ruta principal
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '/login.html'));
});