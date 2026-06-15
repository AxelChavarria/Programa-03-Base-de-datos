

//log in

const formLogin = document.getElementById("form-login");
if (formLogin) {

    formLogin.addEventListener("submit", async function(event) {
        event.preventDefault();
        let datos = {
            username: document.getElementById("user").value.trim(),
            password: document.getElementById("contra").value.trim()
        }

        //llamada a la base de datos
    });
}

//lista de empleados 

const tablaEmpleados = document.getElementById("tabla-empleados");
if (tablaEmpleados) {

    
    
    //llamamos a la base de datos


    //desplegamos la información
    /*
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
    */

    //boton para filtrar con validaciones 
    const boton = document.getElementById("buscar");

    boton.addEventListener("click", async function(event) {
        event.preventDefault();     

        const valor = document.getElementById("busqueda").value.trim()
        
        //llamada a la base de datos
        

        tablaEmpleados.innerHTML = ""

        //desplegamos la información
        /*
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
        */
    });

    
    
   
}

function mostrarInfo(titulo, descripcion){

    document.getElementById("texto").innerHTML =
        "<b>" + titulo + "</b><br>" +
        descripcion;

    document.getElementById("cuadro").style.display="block";
    document.getElementById("fondo").style.display="block";
}




//tabla de planilla
const tablaPlanilla = document.getElementById("tabla-planilla");

console.log(tablaPlanilla)
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

    console.log("Sí entré")
    tablaPlanilla.innerHTML = `
            <tr data-id="1">
                    <td>bruto</td>
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

});
}

const modal = document.getElementById("cuadro");
const btnCerrar = document.getElementById("btn-cerrar");

btnCerrar.addEventListener("click", () => {
    modal.style.display = "none";
    document.getElementById("fondo").style.display="none";
});

