import { loginUsuario, cerrarSesion, obtenerListaEmpleados, consultarTodoSemanalEmpleado, obtenerIdEmpleado, consultarTodoMensualEmpleado } from './funcionesBD.js';

document.addEventListener("DOMContentLoaded", () => {

    const admin = JSON.parse(sessionStorage.getItem("admin"))
    console.log(admin)
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
        

        if (res.Codigo == 0){
            sessionStorage.setItem("usuario", JSON.stringify(res["UsuarioId"]));
            if (res.RolId == 1){
                
                sessionStorage.setItem("admin", JSON.stringify("1"));
                window.location.href = "lista.html";
            } else {
                const res3 = await obtenerIdEmpleado(res.UsuarioId)
                sessionStorage.setItem("empleado", JSON.stringify(res3[0].Id));
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

            sessionStorage.setItem("empleado", JSON.stringify(idEmpleado));
            window.location.href = `empleado.html`;

        });
    });

}


function mostrarInfo(tipo, datos) {

    const modal = document.getElementById("cuadro");
    const fondo = document.getElementById("fondo");

    console.log(datos)

    if (tipo === "deduccion") {

        modal.innerHTML = `
            <h2>Deducciones</h2>
            <div id="listaDeducciones"></div>
            <button id="btn-cerrar" class="form-btn">Cerrar</button>
        `;


        const lista = document.getElementById("listaDeducciones");


        datos.forEach(deduccion => {
            if (deduccion.Monto != 0){

                lista.innerHTML += `
                    <div class="deduccion-item">
                        <p><b>Tipo:</b> ${deduccion.NombreDeduccion}</p>
                        <p><b>Porcentaje:</b> ${deduccion.PorcentajeAplicado}</p>
                        <p><b>Monto:</b> ₡${deduccion.Monto}</p>
                        <hr>
                    </div>
                `;
            }
        });


    }


    modal.style.display = "block";
    fondo.style.display = "block";


    // volver a crear listener porque el botón se genera dinámicamente
    document.getElementById("btn-cerrar").onclick = () => {
        modal.style.display = "none";
        fondo.style.display = "none";
    };
}

function mostrarInfo1(tipo, datos) {

    const modal = document.getElementById("cuadro");
    const fondo = document.getElementById("fondo");

    console.log(datos)

    if (tipo === "deduccion") {

        modal.innerHTML = `
            <h2>Deducciones</h2>
            <div id="listaDeducciones"></div>
            <button id="btn-cerrar" class="form-btn">Cerrar</button>
        `;


        const lista = document.getElementById("listaDeducciones");


        datos.forEach(deduccion => {
            if (deduccion.MontoAcumulado != 0){

                lista.innerHTML += `
                    <div class="deduccion-item">
                        <p><b>Tipo:</b> ${deduccion.NombreDeduccion}</p>
                        <p><b>Porcentaje:</b> ${deduccion.PorcentajeAplicado}</p>
                        <p><b>Monto:</b> ₡${deduccion.MontoAcumulado}</p>
                        <hr>
                    </div>
                `;
            }
        });


    }


    modal.style.display = "block";
    fondo.style.display = "block";


    // volver a crear listener porque el botón se genera dinámicamente
    document.getElementById("btn-cerrar").onclick = () => {
        modal.style.display = "none";
        fondo.style.display = "none";
    };
}



//tabla de planilla semanal
const tablaPlanilla = document.getElementById("tabla-planilla-semanal");
if (tablaPlanilla) {

    const idEmpleado = JSON.parse(sessionStorage.getItem("empleado"))

    //llamamos a la base de datos
    const informacion = await consultarTodoSemanalEmpleado(idEmpleado)
    console.log(informacion)

    console.log(idEmpleado)
    //desplegamos la información
    informacion[0].forEach(emp => {  //pasar por las listas
        tablaPlanilla.innerHTML += `
            <tr data-id="${emp.IdSemanaPlanilla}">
                    <td class="salario">${emp.SalarioBruto}</td>
                    <td class="deducciones">${emp.TotalDeducciones}</td>
                    <td>${emp.SalarioNeto}</td>
                    <td>${emp.HorasOrdinarias}</td>
                    <td>${emp.HorasExtrasNormales}</td>
                    <td>${emp.HorasExtrasDobles}</td>
                </tr>`;
    });
    

    document.addEventListener("click", (e) => {

    if (e.target.classList.contains("deducciones")) {


        const fila = e.target.closest("tr");

        const idSemanaPlanilla = fila.dataset.id;


        // filtrar deducciones por id
        const deduccionesEmpleado = informacion[1].filter(
            d => d.IdSemanaPlanilla == idSemanaPlanilla
        );


        mostrarInfo("deduccion", deduccionesEmpleado);

    }

    if (e.target.classList.contains("salario")) {

    const fila = e.target.closest("tr");

    const idSemanaPlanilla = fila.dataset.id;


    sessionStorage.setItem(
        "idSemanaPlanilla",
        idSemanaPlanilla
    );


    window.location.href = "salarioBruto.html";

}
});
}


//tabla de salario bruto
const tablaSalario = document.getElementById("tabla-salario");
if (tablaSalario) {


    const idSemanaPlanilla = sessionStorage.getItem("idSemanaPlanilla");
    const idEmpleado = JSON.parse(sessionStorage.getItem("empleado"))

    //llamamos a la base de datos
    const informacion = await consultarTodoSemanalEmpleado(idEmpleado)


    //desplegamos la información

    const salariosFiltrados = informacion[2].filter(
        emp => emp.IdSemanaPlanilla == idSemanaPlanilla
    );
    
    salariosFiltrados.forEach(emp => {  //pasar por las listas
        tablaSalario.innerHTML += `
            <tr data-id="${emp.Id}">
                    <td>${emp.Fecha}</td>
                    <td>${emp.HoraEntrada}</td>
                    <td>${emp.HoraSalida}</td>
                    <td>${emp.HorasOrdinarias}</td>
                    <td>${emp.MontoOrdinario}</td>
                    <td>${emp.HorasExtrasNormales}</td>
                    <td>${emp.MontoExtraNormal}</td>
                    <td>${emp.HorasExtrasDobles}</td>
                    <td>${emp.MontoExtraDoble}</td>
                </tr>`;
    });
    
}

//tabla de planilla mensual
const tablaPlanilla1 = document.getElementById("tabla-planilla-mensual");
if (tablaPlanilla1) {

    //llamamos a la base de datos
    const idEmpleado = JSON.parse(sessionStorage.getItem("empleado"))
    const informacion = await consultarTodoMensualEmpleado(idEmpleado)


    //desplegamos la información

    informacion[0].forEach(emp => {  //pasar por las listas
        tablaPlanilla1.innerHTML += `
            <tr data-id="${emp.IdMesPlanilla}">
                    <td>${emp.SalarioBrutoMensual}</td>
                    <td class="deducciones">${emp.DeduccionesMensuales}</td>
                    <td>${emp.SalarioNetoMensual}</td>
                </tr>`;
    });



    document.addEventListener("click", (e) => {

    if (e.target.classList.contains("deducciones")) {


        const fila = e.target.closest("tr");

        const idMesPlanilla = fila.dataset.id;


        // filtrar deducciones por id
        const deduccionesEmpleado = informacion[1].filter(
            d => d.IdMesPlanilla == idMesPlanilla
        );


        mostrarInfo1("deduccion", deduccionesEmpleado);

    }


});
}

const btnAtras1 = document.getElementById("btnAtrasSalario");
if (btnAtras1){
        btnAtras1.addEventListener("click", () => {
            window.location.href = "planillaSemanal.html";
        });
    }

const btnAtras2 = document.getElementById("btnAtrasPlanilla");
if (btnAtras2){
        btnAtras2.addEventListener("click", () => {
            window.location.href = "empleado.html";
        });
    }