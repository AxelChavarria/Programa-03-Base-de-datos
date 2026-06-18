import { loginUsuario, cerrarSesion, obtenerListaEmpleados } from './funcionesBD.js';

document.addEventListener("DOMContentLoaded", () => {

    const admin = JSON.parse(sessionStorage.getItem("admin"))
    const btnAtras = document.getElementById("btnAtras");

    if (admin == "1" && (location.pathname.includes("empleado.html") || location.pathname.includes("planillaSemanal.html") || location.pathname.includes("planillaMensual.html") || location.pathname.includes("salarioBruto.html"))) {
        btnAtras.style.display = "block";
    }

    if (btnAtras){
        btnAtras.addEventListener("click", () => {
            window.location.href = "lista.html";
        });
    }
});


//log in

const formLogin = document.getElementById("form-login");
if (formLogin) {

    formLogin.addEventListener("submit", async function(event) {
        event.preventDefault();
        
        var username = document.getElementById("user").value.trim()
        var password = document.getElementById("contra").value.trim()
        
        //llamada a la base de datos
        const res = await loginUsuario(username,password)
        console.log(res)

        if (res.Codigo == 0){
            sessionStorage.setItem("usuario", JSON.stringify(res["UsuarioId"]));
            if (res.RolId == 1){
                sessionStorage.setItem("admin", JSON.stringify("1"));
                window.location.href = "lista.html";
            } else {
                window.location.href = "empleado.html";
            } 
        } else {
            alert(res.Mensaje)
        }

        
    });
}

//cerrar sesión
function cerrarSesionMain(){

    const id = JSON.parse(sessionStorage.getItem("usuario"))
    cerrarSesion(id)
    sessionStorage.removeItem('usuario')
    sessionStorage.removeItem('admin')
    sessionStorage.removeItem('empleado')
    const btnAtras = document.getElementById("btnAtras")
    if (btnAtras){
        btnAtras.style.display = "none";
    }
    window.location.href='login.html'
}

const btnCerrarSesion = document.getElementById("btnCerrarSesion")
if (btnCerrarSesion) {
    btnCerrarSesion.addEventListener("click", cerrarSesionMain);
}

//lista de empleados 

const tablaEmpleados = document.getElementById("tabla-empleados");
if (tablaEmpleados) {

    
    
    //llamamos a la base de datos
    const admin = JSON.parse(sessionStorage.getItem("usuario"))

    

    
    const informacion = await obtenerListaEmpleados("", admin, "ip prueba")
    

    //desplegamos la información
    
    informacion.forEach(emp => {  //pasar por las listas
        tablaEmpleados.innerHTML += `
            <tr data-id="${emp.Id}">
                    <td>${emp.Nombre}</td>
                    <td>${emp.NombrePuesto}</td>
                    
                    <td class="acciones">
                        <button  class="form-btn impersonar" id="impersonar">Impersonar</button>
                    </td>

                </tr>`;
    });
    

    //boton para filtrar con validaciones 
    const boton = document.getElementById("buscar");

    boton.addEventListener("click", async function(event) {
        event.preventDefault();     

        const valor = document.getElementById("busqueda").value.trim()
        
        //llamada a la base de datos
        const informacion = await obtenerListaEmpleados(valor, admin, "ip prueba")

        tablaEmpleados.innerHTML = ""

        //desplegamos la información
        
        informacion.forEach(emp => {  //pasar por las listas
            tablaEmpleados.innerHTML += `
                <tr data-id="${emp.Id}">
                    <td>${emp.Nombre}</td>
                    <td>${emp.NombrePuesto}</td>
                    
                    <td class="acciones">
                        <button  class="form-btn impersonar" id="impersonar">Impersonar</button>
                    </td>

                </tr>`;
        });
        

        
    });

    // eventos de los botones
    document.querySelectorAll(".impersonar").forEach(btn => {

        btn.addEventListener("click", function() {

            const fila = this.closest("tr");
            const idEmpleado = fila.dataset.id;

            sessionStorage.setItem("empleado", JSON.stringify("idEmpleado"));
            window.location.href = `empleado.html`;

        });
    });

}


function mostrarInfo(titulo, descripcion){

    document.getElementById("texto").innerHTML =
        "<b>" + titulo + "</b><br>" +
        descripcion;

    document.getElementById("cuadro").style.display="block";
    document.getElementById("fondo").style.display="block";
}



//tabla de planilla semanal
const tablaPlanilla = document.getElementById("tabla-planilla-semanal");
if (tablaPlanilla) {

    //llamamos a la base de datos


    //desplegamos la información
    /*
    informacion.forEach(emp => {  //pasar por las listas
        tablaPlanilla.innerHTML += `
            <tr data-id="${emp.Id}">
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    

                </tr>`;
    });
    */

    tablaPlanilla.innerHTML = `
            <tr data-id="1">
                    <td class="salario">bruto</td>
                    <td class="deducciones">
                        deducciones
                    </td>
                    <td>neto</td>
                    <td>ordinarias</td>
                    <td>extra normales</td>
                    <td>extra dobles</td>
                    

                </tr>`;

    document.addEventListener("click", (e) => {

    if (e.target.classList.contains("deducciones")) {

        mostrarInfo("deduccion", "a");

    }

    if (e.target.classList.contains("salario")) {

        window.location.href = "salarioBruto.html";

    }
});
}

const modal = document.getElementById("cuadro");
const btnCerrar = document.getElementById("btn-cerrar");

if (btnCerrar) {
    btnCerrar.addEventListener("click", () => {
        modal.style.display = "none";
        document.getElementById("fondo").style.display="none";
    });
}

//tabla de salario bruto
const tablaSalario = document.getElementById("tabla-salario");
if (tablaSalario) {


    tablaSalario.innerHTML = `
            <tr data-id="1">
                    <td>1</td>
                    <td>1</td>
                    <td>1</td>
                    <td>2</td>
                    <td>2</td>
                    <td>2</td>
                    <td>3</td>
                    <td>3</td>
                    <td>3</td>
                </tr>`;
    //llamamos a la base de datos


    //desplegamos la información
    /*
    informacion.forEach(emp => {  //pasar por las listas
        tablaSalario.innerHTML += `
            <tr data-id="${emp.Id}">
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                </tr>`;
    });
    */
}

//tabla de planilla mensual
const tablaPlanilla1 = document.getElementById("tabla-planilla-mensual");
if (tablaPlanilla1) {

    //llamamos a la base de datos


    //desplegamos la información
    /*
    informacion.forEach(emp => {  //pasar por las listas
        tablaPlanilla1.innerHTML += `
            <tr data-id="${emp.Id}">
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                    <td>${emp.}</td>
                </tr>`;
    });
    */

    tablaPlanilla1.innerHTML = `
            <tr data-id="1">
                    <td>bruto</td>
                    <td class="deducciones">
                        deducciones
                    </td>
                    <td>neto</td>
                </tr>`;

    document.addEventListener("click", (e) => {

    if (e.target.classList.contains("deducciones")) {

        mostrarInfo("deduccion", "a");

    }


});
}