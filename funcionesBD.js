
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
const res = await obtenerListaEmpleados("",1, "ip prueba")
console.log(res)
*/


// retorna
// [0] Planilla semanal
//  [1] deglose de deducciones
// [2] desglose de asistencia
export async function consultarTodoSemanalEmpleado(idEmpleado, idPostByUser = 1, ip = '127.0.0.1') {
    try {
        const respuestaRaw = await fetch(`http://localhost:3002/api/planilla/semanal?idEmpleado=${idEmpleado}&idPostByUser=${idPostByUser}&ip=${ip}`, {
            method: "GET",
            headers: { "Content-Type": "application/json" }
        });
        return await respuestaRaw.json();
    } catch (err) {
        return { outCodigo: -1, outMensaje: err.message };
    }
}

/*
const res1 = await consultarTodoSemanalEmpleado(380)
console.log(res1)
*/


// [0] Planilla mensual
// [1] deglose de deducciones
export async function consultarTodoMensualEmpleado(idEmpleado, idPostByUser = 1, ip = '127.0.0.1') {
    try {
        const respuestaRaw = await fetch(`http://localhost:3002/api/planilla/mensual?idEmpleado=${idEmpleado}&idPostByUser=${idPostByUser}&ip=${ip}`, {
            method: "GET",
            headers: { "Content-Type": "application/json" }
        });
        return await respuestaRaw.json();
    } catch (err) {
        return { outCodigo: -1, outMensaje: err.message };
    }
}

/*
const res2 = await consultarTodoMensualEmpleado(186)
console.log(res2)
*/

export async function obtenerIdEmpleado(idEmpleado) {
    try {
        const respuestaRaw = await fetch(`http://localhost:3002/api/empleado/obtener-id?idEmpleado=${idEmpleado}`, {
            method: "GET",
            headers: { "Content-Type": "application/json" }
        });
        return await respuestaRaw.json();
    } catch (err) {
        return { outCodigo: -1, outMensaje: err.message };
    }
}
/*
const res3 = await obtenerIdEmpleado(10)
console.log(res3)
*/