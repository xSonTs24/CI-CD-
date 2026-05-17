let productsList = []
let loggedUser=null

// Cargar productos desde microservicio
function loadProducts() {
    fetch("http://192.168.100.3:5003/products")  // ajusta si tu endpoint es diferente
        .then(res => res.json())
        .then(data => {
            productsList = data
            renderProducts()
        })
        .catch(error => console.error("Error cargando productos:", error))
}

// Renderizar tabla
function renderProducts() {
    const tbody = document.querySelector("#products-table tbody")
    tbody.innerHTML = ""

    productsList.forEach(product => {
        const row = `
            <tr>
                <td>${product.nombre}</td>
                <td>${product.precio}</td>
                <td>${product.unidades}</td>
                <td>
                    <input type="number" 
                           min="0" 
                           max="${product.unidades}" 
                           value="0" 
                           id="qty-${product.id}" 
                           class="form-control">
                </td>
            </tr>
        `
        tbody.innerHTML += row
    })
}

// Login
function login() {

    const username = document.getElementById("username").value
    const password = document.getElementById("password").value

    fetch("http://192.168.100.3:5002/api/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password })
    })
    .then(res => res.json())
    .then(data => {

        if (data.message === "Login exitoso") {

            loggedUser = username

            // Ocultar login
            document.getElementById("login-section").style.display = "none"

            // Mostrar productos
            document.getElementById("products-section").style.display = "block"

            loadProducts()

        } else {
            alert(data.message)
        }
    })
    .catch(error => console.error("Error login:", error))
}
// Crear orden
function createOrder() {

    if (!loggedUser) {
        alert("Debes iniciar sesión primero")
        return
    }

    const selectedProducts = []

    productsList.forEach(product => {

        const quantity = parseInt(
            document.getElementById(`qty-${product.id}`).value
        )

        if (quantity > 0) {
            selectedProducts.push({
                id: product.id,
                quantity: quantity
            })
        }
    })

    if (selectedProducts.length === 0) {
        alert("Selecciona al menos un producto")
        return
    }

    fetch("http://192.168.100.3:5004/api/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            username: loggedUser,
            products: selectedProducts
        })
    })
    .then(res => res.json())
    .then(data => {
        alert(data.message)
        loadProducts()
    })
    .catch(error => console.error("Error creando orden:", error))
}