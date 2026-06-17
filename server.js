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
        const xmlPath = path.join(__dirname, 'Datos.xml');
        
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

    console.error("Fallo crítico en /api/admin/cargar-todo:", err); 
    
    res.status(500).json({ 
        Codigo: -1, 
        Mensaje: err.message || JSON.stringify(err) || "Error desconocido en el servidor" 
    });
}
});

app.post('/api/auth/login', async (req, res) => {
    const { username, password } = req.body;
    

    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '127.0.0.1';

    try {
        let pool = await sql.connect(config);
        let result = await pool.request()
            // Parámetros de entrada (INPUT)

            .input('inUsername', sql.VarChar(50), username)
            .input('inPassword', sql.VarChar(50), password)
            .input('inIP', sql.VarChar(50), ip)

            // Parámetros de salida (OUTPUT)
            .output('outCodigo', sql.Int)
            .output('outMensaje', sql.VarChar(100))
            .output('outIdUsuario', sql.Int)
            .output('outRol', sql.Int)
            .execute('sp_ValidarLogin');

        // Extraemos los valores que el SP dejó en los OUTPUTs
        const { outCodigo, outMensaje, outIdUsuario, outRol } = result.output;

   
        if (outCodigo === 0) {
            return res.status(200).json({
                Codigo: outCodigo,
                Mensaje: outMensaje,
                UsuarioId: outIdUsuario,
                RolId: outRol
            });
        } else {
            return res.status(401).json({ Codigo: outCodigo, Mensaje: outMensaje });
        }

    } catch (err) {
        console.error("Error crítico en el endpoint de login:", err);
        res.status(500).json({ Codigo: -1, Mensaje: "Error de servidor en el intento de login" });
    }
});

app.post('/api/logout', async (req, res) => {
    const { idUsuario } = req.body;
    const ip = req.ip || '0.0.0.0';

    try {
        let pool = await sql.connect(config);
        let result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inIP', sql.VarChar, ip)
            .output('outCodigo', sql.Int)
            .output('outMensaje', sql.VarChar(100))
            .execute('sp_RegistrarLogout');

        res.json(result.output);
    } catch (err) {
        res.status(500).json({ outCodigo: -1, outMensaje: err.message });
    }
});

app.get('/api/empleados', async (req, res) => {
    const { filtro, idPostByUser,ip } = req.query;
     
    

    try {
        let pool = await sql.connect(config);
        let result = await pool.request()
            .input('inFiltro', sql.VarChar, filtro || '')
            .input('inIdPostByUser', sql.Int, parseInt(idPostByUser))
            .input('inIP', sql.VarChar, ip)
            .execute('sp_ListarEmpleados');

        res.json(result.recordset); 
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


app.listen(3002, () => console.log('Servidor corriendo en puerto 3002'));