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



app.post('/api/admin/cargar-todo', async (req, res) => {
    try {
        const xmlPath = path.join(__dirname, 'datosCarga.xml');
        
        if (!fs.existsSync(xmlPath)) {
            return res.status(404).json({ Codigo: -1, Mensaje: "El archivo datosCarga.xml no existe en el servidor" });
        }

        let xmlContent = fs.readFileSync(xmlPath, 'utf8');
        xmlContent = xmlContent.replace(/<\?xml.*\?>/, '');

        let pool = await sql.connect(config);
        let result = await pool.request()
            .input('inXmlData', sql.Xml, xmlContent)
            .execute('sp_CargarTodoXML');

        res.status(200).json(result.recordset[0]);
    } catch (err) {
        res.status(500).json({ Codigo: -1, Mensaje: err.message });
    }
});