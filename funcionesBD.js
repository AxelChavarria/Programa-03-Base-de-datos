
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