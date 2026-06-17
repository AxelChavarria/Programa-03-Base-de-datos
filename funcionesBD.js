
export async function cargarTodoXML() {
    console.log("Enviando fetch para carga masiva XML...");
    try {
        const respuestaRaw = await fetch("http://localhost:3002/api/admin/cargar-todo", {
            method: "POST",
            headers: { "Content-Type": "application/json" }
        });

        const resultado = await respuestaRaw.json();
        return resultado; 
    } catch (err) {
        console.error("Error en el fetch de carga:", err.message);
        return { Codigo: -1, Mensaje: err.message };
    }
}

//console.log(await cargarTodoXML())

export async function loginUsuario(username, password) {
    try {
        const respuestaRaw = await fetch("http://localhost:3002/api/auth/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password })
        });

        const resultado = await respuestaRaw.json();
        return resultado;
        
    } catch (err) {
        console.error("Error de comunicación en la función loginUsuario:", err.message);
        return { Codigo: -1, Mensaje: err.message };
    }
}
/*
const res = await loginUsuario("admin","admin123")
console.log(res)
*/

export async function cerrarSesion(idUsuario) {
    try {
        const respuestaRaw = await fetch("http://localhost:3002/api/logout", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ idUsuario })
        });
        return await respuestaRaw.json();
    } catch (err) {
        return { outCodigo: -1, outMensaje: err.message };
    }
}

/*
const res = await cerrarSesion(1)
console.log(res)
*/

export async function obtenerListaEmpleados(filtro,idPostByUser, ip) {
    
    try {
        const url = `http://localhost:3002/api/empleados?filtro=${encodeURIComponent(filtro || '')}&idPostByUser=${idPostByUser}&ip=${ip}`;

        const respuestaRaw = await fetch(url);

        if (!respuestaRaw.ok) {
            const text = await respuestaRaw.text();
            throw new Error(`Error HTTP: ${text}`);
        }

        const empleados = await respuestaRaw.json();

        return empleados; // [{Id, Nombre, ...}]

    } catch (err) {
        console.error("Error en obtenerListaEmpleados:", err.message);
        return [];
    }
}

/*
const res = await obtenerListaEmpleados("Lu",1, "ip prueba")
console.log(res)
*/

export async function cargarPlanillaDesdeArchivo() {
    try {
        const response = await fetch('http://localhost:3002/api/admin/cargar-planilla', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const resultado = await response.json();

        if (response.ok && resultado.Codigo !== -1) {
            console.log("Éxito:", resultado.Mensaje);
            return true;
        } else {
            console.error("Error en la carga:", resultado.Mensaje);
            return false;
        }

    } catch (error) {
        console.error("Fallo de red al conectar con /api/admin/cargar-planilla:", error.message);
        return false;
    }
}

console.log(await cargarPlanillaDesdeArchivo())