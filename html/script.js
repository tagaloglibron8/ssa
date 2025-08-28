let isNuiOpen = false;

// Listen for messages from the Lua script
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openNUI':
            openNUI();
            break;
        case 'closeNUI':
            closeNUI();
            break;
        case 'updateStatus':
            updateStatus(data.status);
            break;
        case 'setMenuState':
            setMenuState(data.menuState);
            break;
    }
});

// Open NUI function
function openNUI() {
    if (isNuiOpen) return;
    
    const nuiContainer = document.getElementById('trucker-nui');
    nuiContainer.classList.add('show');
    isNuiOpen = true;
    
    // Request status update
    fetch('https://qbx_truckerjob/requestStatus', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

// Close NUI function
function closeNUI() {
    if (!isNuiOpen) return;
    
    const nuiContainer = document.getElementById('trucker-nui');
    nuiContainer.classList.remove('show');
    isNuiOpen = false;
    
    // Notify Lua script that NUI is closed
    fetch('https://qbx_truckerjob/closeNUI', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

// Update status display
function updateStatus(status) {
    if (status.jobActive !== undefined) {
        document.getElementById('job-status').textContent = status.jobActive ? 'Active' : 'Inactive';
    }
    
    if (status.deliveries !== undefined) {
        document.getElementById('delivery-status').textContent = `${status.completedDeliveries || 0}/${status.totalDeliveries || 0}`;
    }
    
    if (status.vehicle !== undefined) {
        document.getElementById('vehicle-status').textContent = status.vehicle || 'None';
    }
}

// Set menu state (enable/disable buttons)
function setMenuState(menuState) {
    const menuItems = document.querySelectorAll('.menu-item');
    
    menuItems.forEach((item, index) => {
        if (menuState[index] === false) {
            item.classList.add('disabled');
        } else {
            item.classList.remove('disabled');
        }
    });
}

// Menu action functions
function spawnVehicle() {
    if (document.querySelector('.menu-item').classList.contains('disabled')) return;
    
    fetch('https://qbx_truckerjob/spawnVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
    
    closeNUI();
}

function returnVehicle() {
    if (document.querySelectorAll('.menu-item')[1].classList.contains('disabled')) return;
    
    fetch('https://qbx_truckerjob/returnVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
    
    closeNUI();
}

function getPaycheck() {
    if (document.querySelectorAll('.menu-item')[2].classList.contains('disabled')) return;
    
    fetch('https://qbx_truckerjob/getPaycheck', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
    
    closeNUI();
}

// Close NUI when clicking outside
document.addEventListener('click', function(event) {
    if (event.target === document.body) {
        closeNUI();
    }
});

// Close NUI with Escape key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && isNuiOpen) {
        closeNUI();
    }
});