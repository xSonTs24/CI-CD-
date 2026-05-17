function getProducts() {
    fetch('http://192.168.100.3:5003/products')
        .then(response => response.json())
        .then(data => {
            console.log(data);

            var productListBody = document.querySelector('#product-list tbody');
            productListBody.innerHTML = '';

            data.forEach(product => {
                var row = document.createElement('tr');

                // Nombre
                var nameCell = document.createElement('td');
                nameCell.textContent = product.nombre;
                row.appendChild(nameCell);

                // Unidades
                var unitsCell = document.createElement('td');
                unitsCell.textContent = product.unidades;
                row.appendChild(unitsCell);

                // Precio
                var priceCell = document.createElement('td');
                priceCell.textContent = product.precio;
                row.appendChild(priceCell);

                // Acciones
                var actionsCell = document.createElement('td');

                // Editar
                var editLink = document.createElement('a');
                editLink.href = `/editProduct/${product.id}`;
                editLink.textContent = 'Edit';
                editLink.className = 'btn btn-primary mr-2';
                actionsCell.appendChild(editLink);

                // Eliminar
                var deleteLink = document.createElement('a');
                deleteLink.href = '#';
                deleteLink.textContent = 'Delete';
                deleteLink.className = 'btn btn-danger';
                deleteLink.addEventListener('click', function () {
                    deleteProduct(product.id);
                });
                actionsCell.appendChild(deleteLink);

                row.appendChild(actionsCell);
                productListBody.appendChild(row);
            });
        })
        .catch(error => console.error('Error:', error));
}

function createProduct() {
    var data = {
        nombre: document.getElementById('nombre').value,
        unidades: document.getElementById('unidades').value,
        precio: document.getElementById('precio').value
    };

    fetch('http://192.168.100.3:5003/products', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            console.log(data);
            getProducts();
        })
        .catch(error => console.error('Error:', error));
}

function updateProduct() {
    var productId = document.getElementById('product-id').value;

    var data = {
        nombre: document.getElementById('nombre').value,
        unidades: document.getElementById('unidades').value,
        precio: document.getElementById('precio').value
    };

    fetch(`http://192.168.100.3:5003/products/${productId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            console.log(data);
        })
        .catch(error => console.error('Error:', error));
}

function deleteProduct(productId) {
    if (confirm('Are you sure you want to delete this product?')) {
        fetch(`http://192.168.100.3:5003/products/${productId}`, {
            method: 'DELETE',
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('Network response was not ok');
                }
                return response.json();
            })
            .then(data => {
                console.log('Product deleted:', data);
                getProducts();
            })
            .catch(error => console.error('Error:', error));
    }
}

